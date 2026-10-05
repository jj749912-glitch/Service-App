-- These isolated fixtures roll back; no accounts or appointments are persisted.
begin;
select set_config('test.c',gen_random_uuid()::text,true),set_config('test.w1',gen_random_uuid()::text,true),set_config('test.w2',gen_random_uuid()::text,true),set_config('test.other',gen_random_uuid()::text,true),set_config('test.p1',gen_random_uuid()::text,true),set_config('test.p2',gen_random_uuid()::text,true),set_config('test.g1',gen_random_uuid()::text,true),set_config('test.g2',gen_random_uuid()::text,true),set_config('test.bad',gen_random_uuid()::text,true);
insert into auth.users(id,email,email_confirmed_at) select current_setting('test.'||actor)::uuid,actor||current_setting('test.'||actor)||'@example.invalid',now() from unnest(array['c','w1','w2','other']) actor;
insert into public.professionals(id,user_id,name,service,city,hourly_rate,years,bio,qualification,services,verified) values
 (current_setting('test.p1')::uuid,current_setting('test.w1')::uuid,'Rollback worker one','Solar cleaning','Ernakulam',325,3,'Rollback-only service details.','Diploma','[{"service":"Solar cleaning","hourly_rate":325,"years":3,"details":"Rollback-only cleaning service details."},{"service":"Plumbing","hourly_rate":450,"years":2,"details":"Rollback-only plumbing service details."}]',true),
 (current_setting('test.p2')::uuid,current_setting('test.w2')::uuid,'Rollback worker two','Electrical','Ernakulam',300,3,'Rollback-only service details.','Diploma','[{"service":"Electrical","hourly_rate":300,"years":3,"details":"Rollback-only electrical service details."}]',true);
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.c'),'role','authenticated')::text,true);
set local role authenticated;
do $$ declare records jsonb; requests jsonb; count_before integer; begin
 requests:=jsonb_build_array(jsonb_build_object('professional_id',current_setting('test.p1'),'services','[{"service":"Solar cleaning","duration_minutes":75,"hourly_rate":1,"total":1},{"service":"Plumbing","duration_minutes":30}]'::jsonb));
 records:=public.request_service_bookings(current_setting('test.g1')::uuid,now()+interval '8 days','Rollback-only address in Ernakulam','',9.98,76.29,requests);
 if jsonb_array_length(records)<>1 or (records->0->>'total')::integer<>632 or (records->0->>'duration_minutes')::integer<>105 or jsonb_array_length(records->0->'service_items')<>2 then raise exception 'FAIL: combined services and server price'; end if;
 records:=public.request_service_bookings(current_setting('test.g1')::uuid,now()+interval '8 days','Rollback-only address in Ernakulam','',9.98,76.29,requests);
 if (select count(*) from public.bookings where booking_group_id=current_setting('test.g1')::uuid)<>1 then raise exception 'FAIL: retry duplicated appointment'; end if;
 requests:=jsonb_build_array(jsonb_build_object('professional_id',current_setting('test.p1'),'services','[{"service":"Solar cleaning","duration_minutes":75}]'::jsonb),jsonb_build_object('professional_id',current_setting('test.p2'),'services','[{"service":"Electrical","duration_minutes":45}]'::jsonb));
 records:=public.request_service_bookings(current_setting('test.g2')::uuid,now()+interval '10 days','Rollback-only address in Ernakulam','',9.98,76.29,requests);
 if jsonb_array_length(records)<>2 or (select sum(total) from public.bookings where booking_group_id=current_setting('test.g2')::uuid)<>632 then raise exception 'FAIL: separate worker appointments'; end if;
 select count(*) into count_before from public.bookings;
 begin
   requests:=jsonb_build_array(jsonb_build_object('professional_id',current_setting('test.p1'),'services','[{"service":"Solar cleaning","duration_minutes":60}]'::jsonb),jsonb_build_object('professional_id',current_setting('test.p2'),'services','[{"service":"Plumbing","duration_minutes":45}]'::jsonb));
   perform public.request_service_bookings(current_setting('test.bad')::uuid,now()+interval '12 days','Rollback-only address in Ernakulam','',9.98,76.29,requests); raise exception 'FAIL: unoffered service booked';
 exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
 if (select count(*) from public.bookings)<>count_before then raise exception 'FAIL: partial batch persisted'; end if;
 begin
   perform public.request_service_bookings(gen_random_uuid(),now()+interval '14 days','Rollback-only address in Ernakulam','',9.98,76.29,jsonb_build_array(jsonb_build_object('professional_id',current_setting('test.p1'),'services','[{"service":"Solar cleaning","duration_minutes":400},{"service":"Plumbing","duration_minutes":400}]'::jsonb))); raise exception 'FAIL: excessive combined duration';
 exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
 begin
   update public.bookings set service_items='[]' where booking_group_id=current_setting('test.g1')::uuid; raise exception 'FAIL: changed saved service lines';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.w1'),'role','authenticated')::text,true);
set local role authenticated;
update public.bookings set status='accepted' where booking_group_id=current_setting('test.g2')::uuid and professional_id=current_setting('test.p1')::uuid;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.w2'),'role','authenticated')::text,true);
set local role authenticated;
update public.bookings set status='cancelled' where booking_group_id=current_setting('test.g2')::uuid and professional_id=current_setting('test.p2')::uuid;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.c'),'role','authenticated')::text,true);
set local role authenticated;
do $$ begin
 if (select count(*) from public.bookings where booking_group_id=current_setting('test.g2')::uuid and status='accepted')<>1 or (select count(*) from public.bookings where booking_group_id=current_setting('test.g2')::uuid and status='cancelled')<>1 then raise exception 'FAIL: independent worker decisions'; end if;
 if (select count(*) from public.booking_notifications where status='accepted')<>1 then raise exception 'FAIL: confirmation missing'; end if;
end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.other'),'role','authenticated')::text,true);
set local role authenticated;
do $$ begin if exists(select 1 from public.bookings where booking_group_id in (current_setting('test.g1')::uuid,current_setting('test.g2')::uuid)) then raise exception 'FAIL: unrelated customer access'; end if; end $$;
reset role;
rollback;
select 'PASS: combined and separate worker bookings, per-service price/duration, atomic failure, safe retry, worker decisions, notifications and access isolation. No records persisted.' as result;
