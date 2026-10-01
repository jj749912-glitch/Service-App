-- Regression checks only. All synthetic records are rolled back.
begin;
select set_config('test.admin_claims', (select jsonb_build_object('sub',a.user_id,'role','authenticated','session_id',s.id)::text from private.app_admins a join auth.sessions s on s.user_id=a.user_id order by s.created_at desc limit 1),true);
select set_config('test.worker_id',gen_random_uuid()::text,true);
select set_config('test.customer_id',gen_random_uuid()::text,true);
select set_config('test.professional_id',gen_random_uuid()::text,true);
select set_config('test.booking_id',gen_random_uuid()::text,true);
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
  (current_setting('test.worker_id')::uuid,'worker-'||current_setting('test.worker_id')||'@example.invalid',now(),'{"role":"admin"}'),
  (current_setting('test.customer_id')::uuid,'customer-'||current_setting('test.customer_id')||'@example.invalid',now(),'{}');
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.worker_id'),'role','authenticated','user_metadata',jsonb_build_object('role','admin'))::text,true);
set local role authenticated;
do $$ begin
  if public.is_app_admin() then raise exception 'FAIL: user metadata escalated access'; end if;
  begin perform public.admin_summary(); raise exception 'FAIL: non-admin read summary'; exception when insufficient_privilege then null; end;
  begin perform public.admin_list('users'); raise exception 'FAIL: non-admin read users'; exception when insufficient_privilege then null; end;
  begin perform public.admin_review_worker(current_setting('test.professional_id')::uuid,'approved','Invalid attempt','pending',true); raise exception 'FAIL: non-admin reviewed worker'; exception when insufficient_privilege then null; end;
  begin perform public.admin_update_worker(current_setting('test.professional_id')::uuid,'{}','Invalid attempt'); raise exception 'FAIL: non-admin edited worker'; exception when insufficient_privilege then null; end;
  begin perform public.admin_cancel_booking(current_setting('test.booking_id')::uuid,'Invalid attempt'); raise exception 'FAIL: non-admin cancelled booking'; exception when insufficient_privilege then null; end;
  begin insert into private.app_admins(user_id) values(auth.uid()); raise exception 'FAIL: self-admin grant'; exception when insufficient_privilege then null; end;
  begin insert into public.professionals(id,user_id,name,service,city,hourly_rate,years,bio,verified)
    values(current_setting('test.professional_id')::uuid,auth.uid(),'Transaction worker','Solar cleaning','Ernakulam',500,3,'Only used inside a rolled back verification transaction.',true);
    raise exception 'FAIL: worker self-approved'; exception when insufficient_privilege then null; end;
end $$;
insert into public.professionals(id,user_id,name,service,city,hourly_rate,years,bio)
  values(current_setting('test.professional_id')::uuid,auth.uid(),'Transaction worker','Solar cleaning','Ernakulam',500,3,'Only used inside a rolled back verification transaction.');
do $$ begin
  if public.my_worker_review()->>'status'<>'pending' then raise exception 'FAIL: new worker not pending'; end if;
  begin update public.professionals set verified=true where user_id=auth.uid(); raise exception 'FAIL: worker updated verification'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims',current_setting('test.admin_claims'),true);
set local role authenticated;
do $$ begin
  if not public.is_app_admin() then raise exception 'FAIL: authorized admin denied'; end if;
  perform public.admin_summary(); perform public.admin_list('users'); perform public.admin_list('workers','pending');
  begin perform public.admin_review_worker(current_setting('test.professional_id')::uuid,'approved','Checks incomplete','pending',false); raise exception 'FAIL: unchecked approval succeeded'; exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
end $$;
select public.admin_review_worker(current_setting('test.professional_id')::uuid,'approved','Identity qualifications area and rate verified','pending',true);
select public.admin_update_worker(current_setting('test.professional_id')::uuid,'{"name":"Transaction worker edited","service":"Solar cleaning","city":"Thrissur","hourly_rate":650,"years":4,"bio":"Only used inside a rolled back verification transaction."}','Rate and service area confirmed');
do $$ begin
  begin perform public.admin_review_worker(current_setting('test.professional_id')::uuid,'rejected','Stale review attempt','pending',false); raise exception 'FAIL: stale review succeeded'; exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
  begin perform public.admin_update_worker(current_setting('test.professional_id')::uuid,'{"user_id":"00000000-0000-0000-0000-000000000000"}','Attempt account reassignment'); raise exception 'FAIL: account reassignment accepted'; exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.customer_id'),'role','authenticated')::text,true);
set local role authenticated;
insert into public.bookings(id,customer_id,professional_id,professional_name,service,starts_at,hours,ends_at,address,total)
  values(current_setting('test.booking_id')::uuid,auth.uid(),current_setting('test.professional_id')::uuid,'server replaces this','server replaces this',now()+interval '2 days',2,now()+interval '2 days 2 hours','Transaction-only address, Ernakulam',1);
do $$ begin
  if (select total from public.bookings where id=current_setting('test.booking_id')::uuid)<>1300 then raise exception 'FAIL: edited hourly rate not enforced'; end if;
end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.worker_id'),'role','authenticated')::text,true);
set local role authenticated;
update public.bookings set status='accepted' where id=current_setting('test.booking_id')::uuid;
do $$ begin
  if (select status from public.bookings where id=current_setting('test.booking_id')::uuid)<>'accepted' then raise exception 'FAIL: approved worker cannot accept job'; end if;
end $$;
reset role;
select set_config('request.jwt.claims',current_setting('test.admin_claims'),true);
set local role authenticated;
select public.admin_review_worker(current_setting('test.professional_id')::uuid,'suspended','Access suspended for verification review','approved',false);
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.worker_id'),'role','authenticated')::text,true);
set local role authenticated;
do $$ declare n integer; begin
  if public.my_worker_review()->>'status'<>'suspended' then raise exception 'FAIL: suspension status unavailable'; end if;
  if exists(select 1 from public.bookings where id=current_setting('test.booking_id')::uuid) then raise exception 'FAIL: suspended worker read customer booking'; end if;
  update public.bookings set status='completed' where id=current_setting('test.booking_id')::uuid;
  get diagnostics n=row_count;
  if n<>0 then raise exception 'FAIL: suspended worker updated booking'; end if;
end $$;
reset role;
select set_config('request.jwt.claims','{}',true);
set local role anon;
do $$ begin
  if exists(select 1 from public.professional_directory where id=current_setting('test.professional_id')::uuid) then raise exception 'FAIL: suspended worker is public'; end if;
  begin perform public.admin_list('workers'); raise exception 'FAIL: anonymous admin access'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims',current_setting('test.admin_claims'),true);
set local role authenticated;
select public.admin_review_worker(current_setting('test.professional_id')::uuid,'approved','All verification checks completed again','suspended',true);
select public.admin_cancel_booking(current_setting('test.booking_id')::uuid,'Customer requested cancellation after suspension');
select public.admin_list('activity');
reset role;
do $$ begin
  if (select count(*) from private.admin_audit where target_id in (current_setting('test.professional_id')::uuid,current_setting('test.booking_id')::uuid))<>5 then raise exception 'FAIL: audit events missing'; end if;
  if (select status from public.bookings where id=current_setting('test.booking_id')::uuid)<>'cancelled' then raise exception 'FAIL: admin cancellation failed'; end if;
end $$;
-- Removing membership must take effect with the same claims, without token refresh.
delete from private.app_admins where user_id=(current_setting('test.admin_claims')::jsonb->>'sub')::uuid;
set local role authenticated;
do $$ begin
  if public.is_app_admin() then raise exception 'FAIL: revoked membership cached'; end if;
  begin perform public.admin_summary(); raise exception 'FAIL: revoked admin read summary'; exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
select 'PASS: role isolation, approval checks, profile editing, worker access, suspension, restoration, audit, cancellation and immediate admin revocation; all fixtures rolled back' as result;
