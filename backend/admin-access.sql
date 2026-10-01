-- Apply after the existing backend scripts. This creates no accounts or sample data.
-- Administrative membership is provisioned separately by the project owner.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create table private.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table private.worker_reviews (
  professional_id uuid primary key references public.professionals(id),
  status text not null check (status in ('approved','rejected','suspended')),
  note text not null check (length(note) between 5 and 2000),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz not null default now()
);
create table private.admin_audit (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_id uuid not null,
  details jsonb not null,
  created_at timestamptz not null default now()
);
create index admin_audit_created_idx on private.admin_audit(created_at desc, id);
alter table private.app_admins enable row level security;
alter table private.worker_reviews enable row level security;
alter table private.admin_audit enable row level security;
revoke all on private.app_admins, private.worker_reviews, private.admin_audit from public, anon, authenticated;

-- The membership lookup is immediate: user-editable metadata and cached JWT roles
-- are never used for authorization. A revoked auth session also loses admin access.
create function private.is_app_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from private.app_admins a
    join auth.users u on u.id=a.user_id
    join auth.sessions s on s.user_id=u.id
    where a.user_id=auth.uid() and u.email_confirmed_at is not null
      and u.deleted_at is null and (u.banned_until is null or u.banned_until<now())
      and s.id::text=auth.jwt()->>'session_id'
      and (s.not_after is null or s.not_after>now())
  );
$$;
create function public.is_app_admin() returns boolean
language sql stable security invoker set search_path = '' as $$
  select private.is_app_admin();
$$;

create function private.admin_summary() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_app_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
  return jsonb_build_object(
    'pending', (select count(*) from public.professionals p left join private.worker_reviews r on r.professional_id=p.id where not p.verified and (r.status is null or r.status='approved')),
    'approved', (select count(*) from public.professionals where verified),
    'active_bookings', (select count(*) from public.bookings where status in ('requested','accepted')),
    'users', (select count(*) from auth.users where deleted_at is null)
  );
end; $$;
create function public.admin_summary() returns jsonb
language sql stable security invoker set search_path = '' as $$ select private.admin_summary(); $$;

create function private.admin_list(p_section text, p_status text, p_offset integer) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not private.is_app_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
  if p_offset is null or p_offset<0 or p_offset>1000000 then raise exception 'Invalid page'; end if;
  if p_section='workers' then
    if p_status is null or p_status not in ('all','pending','approved','rejected','suspended') then raise exception 'Invalid status'; end if;
    with workers as (
      select p.id,p.user_id,p.name,p.service,p.city,p.hourly_rate,p.years,p.bio,p.verified,
        u.email,u.email_confirmed_at is not null as email_confirmed,
        case when p.verified then 'approved' when r.status in ('rejected','suspended') then r.status else 'pending' end as approval_status,
        coalesce(r.note,'') as review_note,r.reviewed_at
      from public.professionals p join auth.users u on u.id=p.user_id
      left join private.worker_reviews r on r.professional_id=p.id
    ), filtered as (select * from workers where p_status='all' or approval_status=p_status)
    select jsonb_build_object('total',(select count(*) from filtered),'items',coalesce((select jsonb_agg(to_jsonb(page)) from (select * from filtered order by (approval_status='pending') desc,name,id limit 25 offset p_offset) page),'[]'::jsonb)) into result;
  elsif p_section='bookings' then
    if p_status is null or p_status not in ('all','requested','accepted','completed','cancelled') then raise exception 'Invalid status'; end if;
    with filtered as (
      select b.*,u.email as customer_email,p.city,p.verified as worker_approved
      from public.bookings b join auth.users u on u.id=b.customer_id
      join public.professionals p on p.id=b.professional_id
      where p_status='all' or b.status=p_status
    )
    select jsonb_build_object('total',(select count(*) from filtered),'items',coalesce((select jsonb_agg(to_jsonb(page)) from (select * from filtered order by created_at desc,id limit 25 offset p_offset) page),'[]'::jsonb)) into result;
  elsif p_section='users' then
    select jsonb_build_object('total',(select count(*) from auth.users where deleted_at is null),'items',coalesce((select jsonb_agg(to_jsonb(page)) from (
      select u.id,u.email,u.created_at,u.email_confirmed_at is not null as email_confirmed,
        case when a.user_id is not null then 'Administrator' when p.id is not null then 'Worker' else 'Customer' end as account_type
      from auth.users u left join private.app_admins a on a.user_id=u.id
      left join public.professionals p on p.user_id=u.id where u.deleted_at is null
      order by u.created_at desc,u.id limit 25 offset p_offset
    ) page),'[]'::jsonb)) into result;
  elsif p_section='activity' then
    select jsonb_build_object('total',(select count(*) from private.admin_audit),'items',coalesce((select jsonb_agg(to_jsonb(page)) from (
      select a.id,a.action,a.target_id,a.details,a.created_at,u.email as actor_email
      from private.admin_audit a left join auth.users u on u.id=a.actor_id
      order by a.created_at desc,a.id limit 25 offset p_offset
    ) page),'[]'::jsonb)) into result;
  else raise exception 'Invalid section';
  end if;
  return result;
end; $$;
create function public.admin_list(p_section text, p_status text default 'all', p_offset integer default 0) returns jsonb
language sql stable security invoker set search_path = '' as $$ select private.admin_list(p_section,p_status,p_offset); $$;

create function private.admin_review_worker(p_id uuid, p_status text, p_note text, p_expected_status text, p_checks_confirmed boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare worker public.professionals; previous_status text;
begin
  if not private.is_app_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
  if p_status is null or p_status not in ('approved','rejected','suspended') then raise exception 'Invalid decision'; end if;
  if p_note is null or length(trim(p_note)) not between 5 and 2000 then raise exception 'Enter a review note of 5 to 2000 characters'; end if;
  select * into worker from public.professionals where id=p_id for update;
  if not found then raise exception 'Worker profile no longer exists'; end if;
  select case when worker.verified then 'approved' when r.status in ('rejected','suspended') then r.status else 'pending' end
    into previous_status from (select 1) x left join private.worker_reviews r on r.professional_id=p_id;
  if p_expected_status is distinct from previous_status then raise exception 'This profile changed. Refresh before reviewing it'; end if;
  if p_status='approved' and (p_checks_confirmed is distinct from true or not exists(select 1 from auth.users where id=worker.user_id and email_confirmed_at is not null and deleted_at is null and (banned_until is null or banned_until<now()))) then
    raise exception 'Confirm identity, qualifications, service area and rate, and ensure the worker has confirmed their email';
  end if;
  if p_status='rejected' and previous_status not in ('pending','rejected') then raise exception 'Use suspension for a previously approved worker'; end if;
  if p_status='suspended' and previous_status<>'approved' then raise exception 'Only an approved worker can be suspended'; end if;
  update public.professionals set verified=(p_status='approved') where id=p_id;
  insert into private.worker_reviews(professional_id,status,note,reviewed_by)
    values(p_id,p_status,trim(p_note),auth.uid())
    on conflict(professional_id) do update set status=excluded.status,note=excluded.note,reviewed_by=excluded.reviewed_by,reviewed_at=now();
  insert into private.admin_audit(actor_id,action,target_id,details)
    values(auth.uid(),'worker_'||p_status,p_id,jsonb_build_object('name',worker.name,'previous_status',previous_status,'note',trim(p_note),'checks_confirmed',coalesce(p_checks_confirmed,false)));
end; $$;
create function public.admin_review_worker(p_id uuid, p_status text, p_note text, p_expected_status text, p_checks_confirmed boolean default false) returns void
language sql security invoker set search_path = '' as $$ select private.admin_review_worker(p_id,p_status,p_note,p_expected_status,p_checks_confirmed); $$;

create function private.admin_update_worker(p_id uuid,p_profile jsonb,p_note text) returns void
language plpgsql security definer set search_path = '' as $$
declare old_profile public.professionals; new_profile public.professionals;
begin
  if not private.is_app_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
  if p_note is null or length(trim(p_note)) not between 5 and 2000 then raise exception 'Enter a change reason of 5 to 2000 characters'; end if;
  if p_profile is null or jsonb_typeof(p_profile)<>'object' or not (p_profile ?& array['name','service','city','hourly_rate','years','bio'])
    or exists(select 1 from jsonb_object_keys(p_profile) k where k not in ('name','service','city','hourly_rate','years','bio')) then raise exception 'Invalid profile fields'; end if;
  select * into old_profile from public.professionals where id=p_id for update;
  if not found then raise exception 'Worker profile no longer exists'; end if;
  update public.professionals set name=trim(p_profile->>'name'),service=p_profile->>'service',city=p_profile->>'city',
    hourly_rate=(p_profile->>'hourly_rate')::integer,years=(p_profile->>'years')::integer,bio=trim(p_profile->>'bio')
    where id=p_id returning * into new_profile;
  insert into private.admin_audit(actor_id,action,target_id,details)
    values(auth.uid(),'worker_profile_edited',p_id,jsonb_build_object('name',new_profile.name,'note',trim(p_note),'before',to_jsonb(old_profile),'after',to_jsonb(new_profile)));
end; $$;
create function public.admin_update_worker(p_id uuid,p_profile jsonb,p_note text) returns void
language sql security invoker set search_path = '' as $$ select private.admin_update_worker(p_id,p_profile,p_note); $$;

create function private.admin_cancel_booking(p_id uuid,p_note text) returns void
language plpgsql security definer set search_path = '' as $$
declare old_booking public.bookings;
begin
  if not private.is_app_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
  if p_note is null or length(trim(p_note)) not between 5 and 2000 then raise exception 'Enter a cancellation reason of 5 to 2000 characters'; end if;
  select * into old_booking from public.bookings where id=p_id for update;
  if not found or old_booking.status not in ('requested','accepted') then raise exception 'Only active bookings can be cancelled'; end if;
  update public.bookings set status='cancelled' where id=p_id;
  insert into private.admin_audit(actor_id,action,target_id,details)
    values(auth.uid(),'booking_cancelled',p_id,jsonb_build_object('name',old_booking.professional_name,'previous_status',old_booking.status,'note',trim(p_note)));
end; $$;
create function public.admin_cancel_booking(p_id uuid,p_note text) returns void
language sql security invoker set search_path = '' as $$ select private.admin_cancel_booking(p_id,p_note); $$;

create function private.my_worker_review() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Sign in required' using errcode='42501'; end if;
  return (select jsonb_build_object('status',case when p.verified then 'approved' when r.status in ('rejected','suspended') then r.status else 'pending' end,'note',coalesce(r.note,''))
    from public.professionals p left join private.worker_reviews r on r.professional_id=p.id where p.user_id=auth.uid());
end; $$;
create function public.my_worker_review() returns jsonb
language sql stable security invoker set search_path = '' as $$ select private.my_worker_review(); $$;

-- Suspended workers cannot read customer addresses or act on jobs, even with an
-- existing access token or an older version of the app. Customers keep their history.
drop policy own_bookings on public.bookings;
create policy own_bookings on public.bookings for select to authenticated using (
  customer_id=(select auth.uid()) or professional_id in (
    select id from public.professionals where user_id=(select auth.uid()) and verified
  )
);

-- All exposed entry points are invoker wrappers. Only these checked operations
-- can cross into the private schema; there is no client API to grant admin roles.
revoke all on function private.is_app_admin(),private.admin_summary(),private.admin_list(text,text,integer),private.admin_review_worker(uuid,text,text,text,boolean),private.admin_update_worker(uuid,jsonb,text),private.admin_cancel_booking(uuid,text),private.my_worker_review() from public,anon,authenticated;
revoke all on function public.is_app_admin(),public.admin_summary(),public.admin_list(text,text,integer),public.admin_review_worker(uuid,text,text,text,boolean),public.admin_update_worker(uuid,jsonb,text),public.admin_cancel_booking(uuid,text),public.my_worker_review() from public,anon,authenticated;
grant execute on function private.is_app_admin(),private.admin_summary(),private.admin_list(text,text,integer),private.admin_review_worker(uuid,text,text,text,boolean),private.admin_update_worker(uuid,jsonb,text),private.admin_cancel_booking(uuid,text),private.my_worker_review() to authenticated;
grant execute on function public.is_app_admin(),public.admin_summary(),public.admin_list(text,text,integer),public.admin_review_worker(uuid,text,text,text,boolean),public.admin_update_worker(uuid,jsonb,text),public.admin_cancel_booking(uuid,text),public.my_worker_review() to authenticated;
