-- Existing administrators can grant access to confirmed, active accounts.
-- Never derive administrator permission from client-editable user metadata.
create or replace function private.admin_grant_access(
  p_user_id uuid, p_note text, p_checks_confirmed boolean
) returns void language plpgsql security definer set search_path = '' as $$
declare
  target auth.users%rowtype;
begin
  if not private.is_app_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;
  if p_checks_confirmed is distinct from true then
    raise exception 'Confirm administrator permissions before granting access';
  end if;
  if p_note is null or length(trim(p_note)) not between 5 and 2000 then
    raise exception 'Enter a reason between 5 and 2000 characters';
  end if;
  select * into target from auth.users where id = p_user_id for update;
  if not found or target.email_confirmed_at is null
    or nullif(trim(target.email), '') is null or target.deleted_at is not null
    or (target.banned_until is not null and target.banned_until > now()) then
    raise exception 'Select a confirmed, active registered account';
  end if;
  insert into private.app_admins(user_id) values(p_user_id)
    on conflict(user_id) do nothing;
  if not found then raise exception 'This account is already an administrator'; end if;
  insert into private.admin_audit(actor_id, action, target_id, details)
    values(auth.uid(), 'grant_admin', p_user_id,
      jsonb_build_object('name', target.email, 'note', trim(p_note)));
end $$;

create or replace function public.admin_grant_access(
  p_user_id uuid, p_note text, p_checks_confirmed boolean
) returns void language sql security invoker set search_path = '' as $$
  select private.admin_grant_access(p_user_id, p_note, p_checks_confirmed);
$$;

revoke all on function private.admin_grant_access(uuid,text,boolean) from public, anon;
revoke all on function public.admin_grant_access(uuid,text,boolean) from public, anon;
grant execute on function private.admin_grant_access(uuid,text,boolean) to authenticated;
grant execute on function public.admin_grant_access(uuid,text,boolean) to authenticated;
