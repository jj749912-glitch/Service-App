-- Additive upgrade. Existing appointments keep their originally booked service.
alter table public.bookings add column service_items jsonb not null default '[]'::jsonb;
alter table public.bookings add column booking_group_id uuid;
create unique index bookings_group_worker on public.bookings(booking_group_id,professional_id) where booking_group_id is not null;

create or replace function public.prepare_booking() returns trigger
language plpgsql set search_path='' as $$
declare p public.professionals; item jsonb; offering jsonb; seen text[]:='{}';
  items jsonb:='[]'; minutes integer; line_total integer;
begin
 select * into strict p from public.professionals where id=new.professional_id;
 if not p.verified or p.user_id is null or p.user_id=auth.uid() then raise exception 'Choose a verified professional other than yourself'; end if;
 if new.starts_at<=now() or new.starts_at>now()+interval '90 days' then raise exception 'Choose a future slot within 90 days'; end if;
 if new.service_items='[]' then
   new.service:=coalesce(new.service,p.service);
   new.service_items:=jsonb_build_array(jsonb_build_object('service',new.service,'duration_minutes',coalesce(new.duration_minutes,round(new.hours*60)::integer)));
 end if;
 if jsonb_typeof(new.service_items)<>'array' or jsonb_array_length(new.service_items) not between 1 and 6 then raise exception 'Select 1–6 services'; end if;
 new.duration_minutes:=0; new.total:=0;
 for item in select value from jsonb_array_elements(new.service_items) loop
   if jsonb_typeof(item)<>'object' or item->>'service' is null or item->>'service'=any(seen) then raise exception 'Invalid or duplicate service'; end if;
   offering:=null;
   select value into offering from jsonb_array_elements(p.services) where value->>'service'=item->>'service';
   if offering is null then raise exception 'This worker does not offer the selected service'; end if;
   if item->>'duration_minutes' is null or (item->>'duration_minutes')::numeric<>trunc((item->>'duration_minutes')::numeric) then raise exception 'Enter whole minutes for each service'; end if;
   minutes:=(item->>'duration_minutes')::integer;
   if minutes not between 15 and 720 then raise exception 'Enter 15–720 minutes per service'; end if;
   line_total:=ceil((offering->>'hourly_rate')::numeric*minutes/60)::integer;
   items:=items||jsonb_build_array(jsonb_build_object('service',item->>'service','duration_minutes',minutes,'hourly_rate',(offering->>'hourly_rate')::integer,'total',line_total));
   seen:=array_append(seen,item->>'service');
   new.duration_minutes:=new.duration_minutes+minutes; new.total:=new.total+line_total;
 end loop;
 if new.duration_minutes>720 then raise exception 'A worker visit must be at most 720 minutes'; end if;
 new.service_items:=items; new.service:=items->0->>'service';
 new.professional_name:=p.name; new.hours:=new.duration_minutes::numeric/60;
 new.ends_at:=new.starts_at+new.duration_minutes*interval '1 minute';
 return new;
end $$;

-- One appointment per assigned worker. All requested appointments save together.
-- The invoker uses normal booking RLS; no elevated client access is introduced.
create function public.request_service_bookings(p_group uuid,p_start timestamptz,p_address text,p_notes text,p_latitude double precision,p_longitude double precision,p_requests jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare request jsonb; item jsonb; seen text[]:='{}'; workers uuid[]:='{}'; worker uuid; records jsonb;
begin
 if auth.uid() is null or p_group is null then raise exception 'Sign in first'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_group::text,0));
 select jsonb_agg(to_jsonb(b) order by b.professional_id) into records from public.bookings b where b.booking_group_id=p_group and b.customer_id=auth.uid();
 if records is not null then return records; end if;
 if p_requests is null or jsonb_typeof(p_requests)<>'array' or jsonb_array_length(p_requests) not between 1 and 6 then raise exception 'Choose workers for your services'; end if;
 for request in select value from jsonb_array_elements(p_requests) loop
   worker:=(request->>'professional_id')::uuid;
   if worker is null or worker=any(workers) then raise exception 'Duplicate or missing worker'; end if;
   workers:=array_append(workers,worker);
   if request->'services' is null or jsonb_typeof(request->'services')<>'array' or jsonb_array_length(request->'services') not between 1 and 6 then raise exception 'Choose services for every worker'; end if;
   for item in select value from jsonb_array_elements(request->'services') loop
     if item->>'service' is null or item->>'service'=any(seen) then raise exception 'A service can only be assigned once'; end if;
     seen:=array_append(seen,item->>'service');
   end loop;
   insert into public.bookings(customer_id,professional_id,professional_name,service,starts_at,ends_at,hours,duration_minutes,address,notes,total,customer_latitude,customer_longitude,booking_group_id,service_items)
   values(auth.uid(),worker,'','',p_start,p_start+interval '1 hour',1,60,p_address,p_notes,0,p_latitude,p_longitude,p_group,request->'services');
 end loop;
 select jsonb_agg(to_jsonb(b) order by b.professional_id) into records from public.bookings b where b.booking_group_id=p_group and b.customer_id=auth.uid();
 return records;
end $$;
revoke all on function public.request_service_bookings(uuid,timestamptz,text,text,double precision,double precision,jsonb) from public,anon,authenticated;
grant execute on function public.request_service_bookings(uuid,timestamptz,text,text,double precision,double precision,jsonb) to authenticated;

create or replace function private.notify_booking_status() returns trigger
language plpgsql security definer set search_path='' as $$
declare services text;
begin
 if tg_op='UPDATE' and old.status=new.status then return new; end if;
 select string_agg(value->>'service',' + ') into services from jsonb_array_elements(new.service_items);
 services:=coalesce(services,new.service);
 insert into public.booking_notifications(user_id,booking_id,status,title,body)
 values(new.customer_id,new.id,new.status,
  case new.status when 'accepted' then 'Booking confirmed' when 'cancelled' then 'Booking cancelled' when 'completed' then 'Service completed' else 'Request sent' end,
  case new.status when 'accepted' then new.professional_name||' accepted your '||services||' appointment. Your visit is confirmed.'
   when 'cancelled' then 'Your '||services||' appointment with '||new.professional_name||' was cancelled.'
   when 'completed' then new.professional_name||' marked your '||services||' visit completed.'
   else 'Your '||services||' request to '||new.professional_name||' is waiting for acceptance.' end)
 on conflict(booking_id,status) do nothing;
 return new;
end $$;
revoke all on function private.notify_booking_status() from public,anon,authenticated;
