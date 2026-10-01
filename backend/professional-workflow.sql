grant insert on public.professionals to authenticated;
create policy apply_as_professional on public.professionals for insert to authenticated with check(user_id=(select auth.uid()) and not verified and not is_demo and rating=0);
drop policy browse_professionals on public.professionals;
create policy browse_professionals on public.professionals for select to anon,authenticated using(verified or user_id=(select auth.uid()));
create policy manage_assigned_job on public.bookings for update to authenticated using(professional_id in(select id from public.professionals where user_id=(select auth.uid()) and verified)) with check(professional_id in(select id from public.professionals where user_id=(select auth.uid()) and verified));
create function public.guard_booking_status() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if current_user in ('postgres','supabase_admin') then return new; end if;
 if old.status='requested' and new.status='cancelled' and old.customer_id=auth.uid() then return new; end if;
 if exists(select 1 from public.professionals where id=old.professional_id and user_id=auth.uid() and verified) then
   if (old.status='requested' and new.status in ('accepted','cancelled')) or (old.status='accepted' and new.status='completed' and old.ends_at<=now()) then return new; end if;
 end if;
 raise exception 'This status transition is not allowed';
end; $$;
revoke all on function public.guard_booking_status() from public,anon,authenticated;
create trigger guard_booking_status before update on public.bookings for each row execute function public.guard_booking_status();
