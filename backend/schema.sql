create extension if not exists btree_gist;
create table public.professionals (
 id uuid primary key default gen_random_uuid(), user_id uuid unique references auth.users(id),
 name text not null, service text not null, city text not null default 'Bengaluru',
 hourly_rate integer not null check(hourly_rate > 0), rating numeric(2,1) not null default 0 check(rating between 0 and 5),
 years integer not null default 0, bio text not null, verified boolean not null default false, is_demo boolean not null default false
);
create table public.bookings (
 id uuid primary key default gen_random_uuid(), customer_id uuid not null references auth.users(id),
 professional_id uuid not null references public.professionals(id), professional_name text not null, service text not null,
 starts_at timestamptz not null, hours integer not null check(hours between 1 and 4),
 ends_at timestamptz not null, address text not null check(length(address) between 10 and 1000),
 notes text not null default '', total integer not null, status text not null default 'requested' check(status in ('requested','accepted','completed','cancelled')),
 created_at timestamptz not null default now(),
 exclude using gist (professional_id with =, tstzrange(starts_at, ends_at, '[)') with &&) where (status in ('requested','accepted'))
);
create table public.reviews (
 id uuid primary key default gen_random_uuid(), booking_id uuid unique references public.bookings(id),
 professional_id uuid not null references public.professionals(id), customer_id uuid references auth.users(id),
 author_name text not null, rating integer not null check(rating between 1 and 5), body text not null check(length(body) between 5 and 2000),
 is_demo boolean not null default false, created_at timestamptz not null default now()
);
alter table public.professionals enable row level security;
alter table public.bookings enable row level security;
alter table public.reviews enable row level security;
grant select on public.professionals,public.reviews to anon,authenticated;
grant select,insert on public.bookings to authenticated;
grant insert on public.reviews to authenticated;
create policy browse_professionals on public.professionals for select to anon,authenticated using(true);
create policy browse_reviews on public.reviews for select to anon,authenticated using(true);
create policy own_bookings on public.bookings for select to authenticated using(customer_id=(select auth.uid()) or professional_id in (select id from public.professionals where user_id=(select auth.uid())));
create policy request_booking on public.bookings for insert to authenticated with check(customer_id=(select auth.uid()) and status='requested');
create policy completed_review on public.reviews for insert to authenticated with check(
 customer_id=(select auth.uid()) and not is_demo and exists(select 1 from public.bookings b where b.id=booking_id and b.customer_id=(select auth.uid()) and b.professional_id=reviews.professional_id and b.status='completed'));
create index bookings_customer_idx on public.bookings(customer_id);
create index reviews_professional_idx on public.reviews(professional_id);
create index reviews_customer_idx on public.reviews(customer_id);
create index professionals_user_idx on public.professionals(user_id);
create function public.prepare_booking() returns trigger language plpgsql security invoker set search_path='' as $$
declare p public.professionals;
begin
 select * into strict p from public.professionals where id=new.professional_id;
 if new.starts_at <= now() or new.starts_at > now()+interval '90 days' then raise exception 'Choose a future slot within 90 days'; end if;
 new.professional_name=p.name; new.service=p.service; new.total=p.hourly_rate*new.hours;
 new.ends_at=new.starts_at + new.hours * interval '1 hour';
 return new;
end; $$;
create trigger prepare_booking before insert on public.bookings for each row execute function public.prepare_booking();
create function public.cancel_booking(booking_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 update public.bookings set status='cancelled' where id=booking_id and customer_id=auth.uid() and status='requested';
 if not found then raise exception 'Request cannot be cancelled'; end if;
end; $$;
revoke all on function public.cancel_booking(uuid) from public,anon;
grant execute on function public.cancel_booking(uuid) to authenticated;
revoke all on function public.prepare_booking() from public,anon,authenticated;

alter extension btree_gist set schema extensions;
grant update(status) on public.bookings to authenticated;
create policy cancel_own_request on public.bookings for update to authenticated using(customer_id=(select auth.uid()) and status='requested') with check(customer_id=(select auth.uid()) and status='cancelled');
alter function public.cancel_booking(uuid) security invoker;
