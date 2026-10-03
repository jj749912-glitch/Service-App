-- Transaction-only verification. All accounts, profiles and bookings roll back.
begin;
select set_config('test.worker_id',gen_random_uuid()::text,true);
select set_config('test.customer_id',gen_random_uuid()::text,true);
select set_config('test.other_id',gen_random_uuid()::text,true);
select set_config('test.professional_id',gen_random_uuid()::text,true);
select set_config('test.accept_id',gen_random_uuid()::text,true);
select set_config('test.decline_id',gen_random_uuid()::text,true);
insert into auth.users(id,email,email_confirmed_at) select current_setting('test.'||actor||'_id')::uuid,actor||'-'||current_setting('test.'||actor||'_id')||'@example.invalid',now() from unnest(array['worker','customer','other']) actor;
-- Server provisioning here isolates booking policies from the separate admin checks.
insert into public.professionals(id,user_id,name,service,city,hourly_rate,years,bio,verified) values(current_setting('test.professional_id')::uuid,current_setting('test.worker_id')::uuid,'Rollback-only professional','Solar cleaning','Ernakulam',325,3,'Transaction-only verification; never persisted.',true);
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.customer_id'),'role','authenticated')::text,true);
set local role authenticated;
insert into public.bookings(id,customer_id,professional_id,professional_name,service,starts_at,hours,ends_at,address,total) select current_setting('test.'||decision||'_id')::uuid,auth.uid(),current_setting('test.professional_id')::uuid,'replaced by server','replaced by server',now()+offset_days*interval '1 day',2,now()+interval '10 days','Rollback-only address, Ernakulam',1 from (values ('accept',2),('decline',3)) d(decision,offset_days);
do $$ begin
 if (select count(*) from public.bookings where id in (current_setting('test.accept_id')::uuid,current_setting('test.decline_id')::uuid) and total=650 and service='Solar cleaning' and status='requested')<>2 then raise exception 'FAIL: customer request or server price'; end if;
 begin
  insert into public.bookings(customer_id,professional_id,professional_name,service,starts_at,hours,ends_at,address,total) values(auth.uid(),current_setting('test.professional_id')::uuid,'x','x',now()+interval '2 days',1,now()+interval '2 days 1 hour','Rollback-only address, Ernakulam',1);
  raise exception 'FAIL: overlapping booking permitted';
 exception when exclusion_violation then null; end;
end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.other_id'),'role','authenticated')::text,true);
set local role authenticated;
do $$ declare changed integer; begin
 if exists(select 1 from public.bookings where professional_id=current_setting('test.professional_id')::uuid) then raise exception 'FAIL: unrelated account read bookings'; end if;
 update public.bookings set status='accepted' where id=current_setting('test.accept_id')::uuid;
 get diagnostics changed=row_count;
 if changed<>0 then raise exception 'FAIL: unrelated account accepted booking'; end if;
end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.worker_id'),'role','authenticated')::text,true);
set local role authenticated;
do $$ begin
 if (select count(*) from public.bookings where professional_id=current_setting('test.professional_id')::uuid and status='requested')<>2 then raise exception 'FAIL: worker cannot see customer requests'; end if;
end $$;
update public.bookings set status='accepted' where id=current_setting('test.accept_id')::uuid;
update public.bookings set status='cancelled' where id=current_setting('test.decline_id')::uuid;
do $$ begin
 if (select status from public.bookings where id=current_setting('test.accept_id')::uuid)<>'accepted' then raise exception 'FAIL: worker acceptance'; end if;
 if (select status from public.bookings where id=current_setting('test.decline_id')::uuid)<>'cancelled' then raise exception 'FAIL: worker decline'; end if;
 begin update public.bookings set status='completed' where id=current_setting('test.accept_id')::uuid; raise exception 'FAIL: premature completion'; exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.customer_id'),'role','authenticated')::text,true);
set local role authenticated;
do $$ begin
 if (select status from public.bookings where id=current_setting('test.accept_id')::uuid)<>'accepted' then raise exception 'FAIL: customer cannot see acceptance'; end if;
 if (select status from public.bookings where id=current_setting('test.decline_id')::uuid)<>'cancelled' then raise exception 'FAIL: customer cannot see decline'; end if;
 begin perform public.cancel_booking(current_setting('test.accept_id')::uuid); raise exception 'FAIL: customer cancelled accepted job'; exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
end $$;
reset role;
rollback;
select 'PASS: request, assigned worker visibility, acceptance, decline, customer visibility, server price, overlap and role isolation; no records persisted' as result;
