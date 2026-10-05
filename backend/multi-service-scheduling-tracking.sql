-- Additive upgrade: no sample accounts, workers, bookings or locations.
alter table public.professionals add column if not exists qualification text not null default '';
alter table public.professionals add column if not exists services jsonb not null default '[]'::jsonb;

create or replace function public.validate_worker_services() returns trigger
language plpgsql set search_path='' as $$
declare item jsonb; seen text[] := '{}'; primary_item jsonb;
begin
  if tg_op='INSERT' and length(trim(new.qualification)) not between 2 and 2000 then
    raise exception 'Enter your qualification';
  end if;
  if length(new.qualification)>2000 then raise exception 'Qualification is too long'; end if;
  if new.services='[]'::jsonb then
    new.services:=jsonb_build_array(jsonb_build_object('service',new.service,'hourly_rate',new.hourly_rate,'years',new.years,'details',new.bio));
  end if;
  if jsonb_typeof(new.services)<>'array' or jsonb_array_length(new.services) not between 1 and 6 then raise exception 'Select 1–6 services'; end if;
  for item in select value from jsonb_array_elements(new.services) loop
    if jsonb_typeof(item)<>'object' or not (item ?& array['service','hourly_rate','years','details'])
      or item->>'service' is null or item->>'service' not in ('Solar cleaning','Solar inspection','Solar repair','Electrical','Plumbing','Home cleaning')
      or item->>'service'=any(seen) then raise exception 'Invalid or duplicate service'; end if;
    if (item->>'hourly_rate')::numeric not between 1 and 100000 or (item->>'hourly_rate')::numeric<>trunc((item->>'hourly_rate')::numeric)
      or (item->>'years')::numeric not between 0 and 60 or (item->>'years')::numeric<>trunc((item->>'years')::numeric)
      or length(trim(item->>'details')) not between 20 and 2000
      or item->>'hourly_rate' is null or item->>'years' is null or item->>'details' is null then raise exception 'Enter a valid rate, experience and details for each service'; end if;
    seen:=array_append(seen,item->>'service');
  end loop;
  -- Keep the primary fields for compatibility with existing app versions.
  select value into primary_item from jsonb_array_elements(new.services) where value->>'service'=new.service;
  if primary_item is null then primary_item:=new.services->0; end if;
  if tg_op='UPDATE' and (new.service,new.hourly_rate,new.years,new.bio) is distinct from (old.service,old.hourly_rate,old.years,old.bio)
    and new.services=old.services then
    primary_item:=jsonb_build_object('service',new.service,'hourly_rate',new.hourly_rate,'years',new.years,'details',new.bio);
    new.services:=(select coalesce(jsonb_agg(value),'[]') from jsonb_array_elements(new.services) where value->>'service'<>old.service and value->>'service'<>new.service)||jsonb_build_array(primary_item);
  else
    new.service:=primary_item->>'service';new.hourly_rate:=(primary_item->>'hourly_rate')::integer;
    new.years:=(primary_item->>'years')::integer;new.bio:=primary_item->>'details';
  end if;
  return new;
end; $$;
create trigger validate_worker_services before insert or update on public.professionals for each row execute function public.validate_worker_services();
-- Backfill only the existing, originally submitted service data.
update public.professionals set services=jsonb_build_array(jsonb_build_object('service',service,'hourly_rate',hourly_rate,'years',years,'details',bio)) where services='[]'::jsonb;
create or replace view public.professional_directory with (security_invoker=true) as
select p.id,p.user_id,p.name,p.service,p.city,p.hourly_rate,p.years,p.bio,p.verified,
coalesce(round(avg(r.rating),1),0) as rating,count(r.id)::integer as review_count,p.services,p.qualification
from public.professionals p left join public.reviews r on r.professional_id=p.id group by p.id;

alter table public.bookings drop constraint bookings_hours_check;
alter table public.bookings alter column hours type numeric using hours::numeric;
alter table public.bookings add column duration_minutes integer;
alter table public.bookings add column customer_latitude double precision check(customer_latitude between -90 and 90);
alter table public.bookings add column customer_longitude double precision check(customer_longitude between -180 and 180);
update public.bookings set duration_minutes=round(hours*60)::integer;
alter table public.bookings add constraint bookings_hours_check check(hours between 0.25 and 12);
alter table public.bookings add constraint bookings_duration_check check(duration_minutes between 15 and 720);
create or replace function public.prepare_booking() returns trigger language plpgsql set search_path='' as $$
declare p public.professionals; offering jsonb;
begin
  select * into strict p from public.professionals where id=new.professional_id;
  if not p.verified or p.user_id is null or p.user_id=auth.uid() then raise exception 'Choose a verified professional other than yourself'; end if;
  if new.starts_at<=now() or new.starts_at>now()+interval '90 days' then raise exception 'Choose a future slot within 90 days'; end if;
  if new.service is null then new.service:=p.service; end if;
  select value into offering from jsonb_array_elements(p.services) where value->>'service'=new.service;
  if offering is null then raise exception 'This worker does not offer the selected service'; end if;
  new.professional_name:=p.name;
  new.duration_minutes:=coalesce(new.duration_minutes,round(new.hours*60)::integer);
  if new.duration_minutes not between 15 and 720 then raise exception 'Enter a duration of 15–720 minutes'; end if;
  new.hours:=new.duration_minutes::numeric/60;
  new.total:=ceil((offering->>'hourly_rate')::numeric*new.duration_minutes/60)::integer;
  new.ends_at:=new.starts_at+new.duration_minutes*interval '1 minute';
  return new;
end; $$;

create table public.booking_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  booking_id uuid not null references public.bookings(id),
  status text not null,
  title text not null,
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  unique(booking_id,status)
);
create index booking_notifications_user_created on public.booking_notifications(user_id,created_at desc);
alter table public.booking_notifications enable row level security;
revoke all on public.booking_notifications from anon,authenticated;
grant select,update(read_at) on public.booking_notifications to authenticated;
create policy own_notifications on public.booking_notifications for select to authenticated using(user_id=(select auth.uid()));
create policy read_own_notifications on public.booking_notifications for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
-- Internal trigger must write a customer-owned notification during worker updates.
create function private.notify_booking_status() returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='UPDATE' and old.status=new.status then return new; end if;
  insert into public.booking_notifications(user_id,booking_id,status,title,body)
  values(new.customer_id,new.id,new.status,
    case new.status when 'accepted' then 'Booking confirmed' when 'cancelled' then 'Booking cancelled' when 'completed' then 'Service completed' else 'Request sent' end,
    case new.status when 'accepted' then new.professional_name||' accepted your '||new.service||' appointment. Your visit is confirmed.'
      when 'cancelled' then 'Your '||new.service||' appointment with '||new.professional_name||' was cancelled.'
      when 'completed' then new.professional_name||' marked your '||new.service||' visit completed.'
      else 'Your request to '||new.professional_name||' is waiting for acceptance.' end)
  on conflict(booking_id,status) do nothing;
  return new;
end; $$;
revoke all on function private.notify_booking_status() from public,anon,authenticated;
create trigger notify_booking_status after insert or update of status on public.bookings for each row execute function private.notify_booking_status();

create table public.worker_locations (
  booking_id uuid primary key references public.bookings(id) on delete cascade,
  latitude double precision not null check(latitude between -90 and 90),
  longitude double precision not null check(longitude between -180 and 180),
  accuracy double precision not null check(accuracy>=0 and accuracy<=10000),
  updated_at timestamptz not null default now()
);
alter table public.worker_locations enable row level security;
revoke all on public.worker_locations from anon,authenticated;
grant select,insert,update,delete on public.worker_locations to authenticated;
create policy view_worker_location on public.worker_locations for select to authenticated using (
  exists(select 1 from public.bookings b join public.professionals p on p.id=b.professional_id where b.id=booking_id and p.verified and
    (p.user_id=(select auth.uid()) or (b.customer_id=(select auth.uid()) and b.status='accepted' and now()>=b.starts_at-interval '20 minutes' and now()<b.ends_at and updated_at>now()-interval '2 minutes')))
);
create policy share_worker_location on public.worker_locations for insert to authenticated with check (
  exists(select 1 from public.bookings b join public.professionals p on p.id=b.professional_id where b.id=booking_id and p.verified and p.user_id=(select auth.uid()) and b.status='accepted' and now()>=b.starts_at-interval '20 minutes' and now()<b.ends_at)
);
create policy update_worker_location on public.worker_locations for update to authenticated using (
  exists(select 1 from public.bookings b join public.professionals p on p.id=b.professional_id where b.id=booking_id and p.verified and p.user_id=(select auth.uid()))
) with check (
  exists(select 1 from public.bookings b join public.professionals p on p.id=b.professional_id where b.id=booking_id and p.verified and p.user_id=(select auth.uid()) and b.status='accepted' and now()>=b.starts_at-interval '20 minutes' and now()<b.ends_at)
);
create policy stop_worker_location on public.worker_locations for delete to authenticated using (
  exists(select 1 from public.bookings b join public.professionals p on p.id=b.professional_id where b.id=booking_id and p.user_id=(select auth.uid()))
);
create function public.stamp_worker_location() returns trigger language plpgsql set search_path='' as $$
begin
  if tg_op='UPDATE' and new.booking_id<>old.booking_id then raise exception 'Cannot change booking'; end if;
  new.updated_at:=clock_timestamp();return new;
end; $$;
create trigger stamp_worker_location before insert or update on public.worker_locations for each row execute function public.stamp_worker_location();
-- Status is the only client-editable booking field. Customers use cancel_booking.
revoke update on public.bookings from authenticated;
grant update(status) on public.bookings to authenticated;
-- Coarse, opt-in availability is distinct from a booking's private live tracking.
create table public.worker_availability (
  professional_id uuid primary key references public.professionals(id) on delete cascade,
  latitude double precision not null check(latitude between -90 and 90),
  longitude double precision not null check(longitude between -180 and 180),
  updated_at timestamptz not null default now()
);
alter table public.worker_availability enable row level security;
revoke all on public.worker_availability from anon,authenticated;
grant select,insert,update,delete on public.worker_availability to authenticated;
create policy nearby_available_workers on public.worker_availability for select to authenticated using (
  exists(select 1 from public.professionals p where p.id=professional_id and
  (p.user_id=(select auth.uid()) or (p.verified and updated_at>now()-interval '2 minutes')))
);
create policy publish_own_availability on public.worker_availability for insert to authenticated with check (
  exists(select 1 from public.professionals p where p.id=professional_id and p.verified and p.user_id=(select auth.uid()))
);
create policy refresh_own_availability on public.worker_availability for update to authenticated using (
  exists(select 1 from public.professionals p where p.id=professional_id and p.verified and p.user_id=(select auth.uid()))
) with check (
  exists(select 1 from public.professionals p where p.id=professional_id and p.verified and p.user_id=(select auth.uid()))
);
create policy remove_own_availability on public.worker_availability for delete to authenticated using (
  exists(select 1 from public.professionals p where p.id=professional_id and p.user_id=(select auth.uid()))
);
create function public.stamp_worker_availability() returns trigger language plpgsql set search_path='' as $$
begin
  if tg_op='UPDATE' and new.professional_id<>old.professional_id then raise exception 'Cannot change professional'; end if;
  new.latitude:=round(new.latitude::numeric,3);new.longitude:=round(new.longitude::numeric,3);
  new.updated_at:=clock_timestamp();return new;
end; $$;
create trigger stamp_worker_availability before insert or update on public.worker_availability for each row execute function public.stamp_worker_availability();
-- Phone numbers are separate from the publicly browsable directory.
create table public.worker_contacts (
  professional_id uuid primary key references public.professionals(id) on delete cascade,
  phone text not null check(phone ~ '^\+91[6-9][0-9]{9}$')
);
alter table public.worker_contacts enable row level security;
revoke all on public.worker_contacts from anon,authenticated;
grant select,insert,update(phone) on public.worker_contacts to authenticated;
create policy worker_own_contact on public.worker_contacts for select to authenticated using (
 exists(select 1 from public.professionals p where p.id=professional_id and p.user_id=(select auth.uid()))
);
create policy appointment_day_contact on public.worker_contacts for select to authenticated using (
 exists(select 1 from public.bookings b join public.professionals p on p.id=b.professional_id
 where b.professional_id=worker_contacts.professional_id and b.customer_id=(select auth.uid())
 and p.verified and b.status in ('accepted','completed')
 and (b.starts_at at time zone 'Asia/Kolkata')::date=(now() at time zone 'Asia/Kolkata')::date)
);
create policy insert_own_contact on public.worker_contacts for insert to authenticated with check (
 exists(select 1 from public.professionals p where p.id=professional_id and p.user_id=(select auth.uid()))
);
create policy update_own_contact on public.worker_contacts for update to authenticated using (
 exists(select 1 from public.professionals p where p.id=professional_id and p.user_id=(select auth.uid()))
) with check (
 exists(select 1 from public.professionals p where p.id=professional_id and p.user_id=(select auth.uid()))
);
-- Both rows succeed together or roll back together; caller RLS still applies.
create function public.submit_worker_application(application jsonb) returns uuid
language plpgsql security invoker set search_path='' as $$
declare worker_id uuid;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 insert into public.professionals(user_id,name,service,city,hourly_rate,years,bio,qualification,services)
 values(auth.uid(),application->>'name',application->>'service',application->>'city',
 (application->>'hourly_rate')::integer,(application->>'years')::integer,application->>'bio',
 application->>'qualification',application->'services') returning id into worker_id;
 insert into public.worker_contacts(professional_id,phone) values(worker_id,application->>'phone');
 return worker_id;
end $$;
revoke all on function public.submit_worker_application(jsonb) from public,anon,authenticated;
grant execute on function public.submit_worker_application(jsonb) to authenticated;
create function public.save_worker_phone(p_phone text) returns void
language plpgsql security invoker set search_path='' as $$
declare worker_id uuid;
begin
 select id into strict worker_id from public.professionals where user_id=auth.uid();
 update public.worker_contacts set phone=p_phone where professional_id=worker_id;
 if not found then insert into public.worker_contacts(professional_id,phone) values(worker_id,p_phone); end if;
end $$;
revoke all on function public.save_worker_phone(text) from public,anon,authenticated;
grant execute on function public.save_worker_phone(text) to authenticated;
-- Real job milestones, maintained only by the assigned approved worker.
alter table public.bookings add column journey_status text not null default 'not_started'
 check(journey_status in ('not_started','on_way','arrived','in_progress','finished'));
alter table public.bookings add column journey_started_at timestamptz;
alter table public.bookings add column arrived_at timestamptz;
alter table public.bookings add column work_started_at timestamptz;
alter table public.bookings add column work_completed_at timestamptz;
alter table public.bookings add column work_notes text not null default '' check(length(work_notes)<=4000);
create or replace function public.guard_booking_status() returns trigger
language plpgsql set search_path='' as $$
begin
 if current_user in ('postgres','supabase_admin') then return new; end if;
 if old.status='requested' and new.status='cancelled' and old.customer_id=auth.uid()
 and new.journey_status=old.journey_status and new.work_notes=old.work_notes then return new; end if;
 if not exists(select 1 from public.professionals where id=old.professional_id and user_id=auth.uid() and verified)
 then raise exception 'Only the assigned approved worker can update this job'; end if;
 if old.status='requested' and new.status in ('accepted','cancelled') and new.journey_status=old.journey_status then return new; end if;
 if old.status='accepted' and new.status='accepted' then
   if new.journey_status=old.journey_status then return new; end if;
   if old.journey_status='not_started' and new.journey_status='on_way' and now()>=old.starts_at-interval '20 minutes' and now()<old.ends_at then new.journey_started_at:=now();return new; end if;
   if old.journey_status='on_way' and new.journey_status='arrived' then new.arrived_at:=now();return new; end if;
   if old.journey_status='arrived' and new.journey_status='in_progress' then new.work_started_at:=now();return new; end if;
 end if;
 if old.status='accepted' and new.status='completed' and (old.journey_status='in_progress' or old.ends_at<=now()) then
   new.journey_status:='finished';new.work_completed_at:=now();return new;
 end if;
 raise exception 'This job transition is not allowed';
end $$;
grant update(journey_status,work_notes) on public.bookings to authenticated;
create table public.booking_messages (
 id uuid primary key default gen_random_uuid(),
 booking_id uuid not null references public.bookings(id) on delete cascade,
 sender_id uuid not null references auth.users(id),
 body text not null check(length(trim(body)) between 1 and 2000),
 created_at timestamptz not null default now()
);
create index booking_messages_booking_created on public.booking_messages(booking_id,created_at);
create index booking_messages_sender on public.booking_messages(sender_id);
alter table public.booking_messages enable row level security;
revoke all on public.booking_messages from anon,authenticated;
grant select,insert(booking_id,sender_id,body) on public.booking_messages to authenticated;
create policy booking_participants_read on public.booking_messages for select to authenticated using (
 exists(select 1 from public.bookings b join public.professionals p on p.id=b.professional_id where b.id=booking_id
 and b.status in ('accepted','completed') and (b.customer_id=(select auth.uid()) or (p.user_id=(select auth.uid()) and p.verified)))
);
create policy booking_participants_send on public.booking_messages for insert to authenticated with check (
 sender_id=(select auth.uid()) and exists(select 1 from public.bookings b join public.professionals p on p.id=b.professional_id
 where b.id=booking_id and b.status in ('accepted','completed') and (b.customer_id=(select auth.uid()) or (p.user_id=(select auth.uid()) and p.verified)))
);
-- Keep the existing administrator-only listing, adding submitted service details.
do $$ declare definition text; begin
  definition:=pg_get_functiondef('private.admin_list(text,text,integer)'::regprocedure);
  definition:=replace(definition,'p.hourly_rate,p.years,p.bio,p.verified,','p.hourly_rate,p.years,p.bio,p.verified,p.services,p.qualification,(select c.phone from public.worker_contacts c where c.professional_id=p.id) as phone,');
  execute definition;
end $$;
revoke all on function public.validate_worker_services(),public.stamp_worker_location(),public.stamp_worker_availability() from public,anon,authenticated;
-- Realtime booking/notification events contain no GPS coordinates; GPS uses RLS-checked polling.
do $$ begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='bookings' and schemaname='public') then alter publication supabase_realtime add table public.bookings; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='booking_notifications' and schemaname='public') then alter publication supabase_realtime add table public.booking_notifications; end if;
end $$;
