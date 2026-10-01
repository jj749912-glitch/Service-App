delete from public.reviews where is_demo;
delete from public.professionals where is_demo;
drop policy apply_as_professional on public.professionals;
drop policy completed_review on public.reviews;
alter table public.professionals drop column is_demo;
alter table public.reviews drop column is_demo;
create policy apply_as_professional on public.professionals for insert to authenticated with check(user_id=(select auth.uid()) and not verified and rating=0);
create policy completed_review on public.reviews for insert to authenticated with check(customer_id=(select auth.uid()) and booking_id is not null and exists(select 1 from public.bookings b where b.id=booking_id and b.customer_id=(select auth.uid()) and b.professional_id=reviews.professional_id and b.status='completed'));
alter table public.reviews alter column booking_id set not null;
alter table public.reviews alter column customer_id set not null;
alter table public.professionals alter column user_id set not null;
alter table public.professionals alter column city set default 'Ernakulam';
alter table public.professionals drop constraint professional_city;
alter table public.professionals add constraint professional_city check(city in ('Ernakulam','Bengaluru','Chennai','Hyderabad'));
create view public.professional_directory with (security_invoker=true) as
select p.id,p.user_id,p.name,p.service,p.city,p.hourly_rate,p.years,p.bio,p.verified,
 coalesce(round(avg(r.rating),1),0) as rating,count(r.id)::integer as review_count
from public.professionals p left join public.reviews r on r.professional_id=p.id
group by p.id;
grant select on public.professional_directory to anon,authenticated;
