-- All verification data is temporary; the entire transaction rolls back.
begin;
select set_config('test.worker',gen_random_uuid()::text,true);
select set_config('test.customer',gen_random_uuid()::text,true);
select set_config('test.other',gen_random_uuid()::text,true);
select set_config('test.applicant',gen_random_uuid()::text,true);
select set_config('test.professional',gen_random_uuid()::text,true);
select set_config('test.near',gen_random_uuid()::text,true);
select set_config('test.future',gen_random_uuid()::text,true);
select set_config('test.decline',gen_random_uuid()::text,true);
insert into auth.users(id,email,email_confirmed_at)
select current_setting('test.'||actor)::uuid,actor||'-'||current_setting('test.'||actor)||'@example.invalid',now() from unnest(array['worker','customer','other','applicant']) actor;
insert into public.professionals(id,user_id,name,service,city,hourly_rate,years,bio,qualification,services,verified)
values(current_setting('test.professional')::uuid,current_setting('test.worker')::uuid,'Rollback-only worker','Solar cleaning','Ernakulam',325,3,'Rollback-only service details.','Electrical diploma',
'[{"service":"Solar cleaning","hourly_rate":325,"years":3,"details":"Rollback-only cleaning service details."},{"service":"Plumbing","hourly_rate":450,"years":2,"details":"Rollback-only plumbing service details."}]',true);
insert into public.worker_contacts values(current_setting('test.professional')::uuid,'+919876543210');
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.applicant'),'role','authenticated')::text,true);
set local role authenticated;
do $$ begin
 begin
  perform public.submit_worker_application('{"name":"Rollback applicant","service":"Solar cleaning","city":"Ernakulam","hourly_rate":325,"years":3,"bio":"Rollback-only service details.","qualification":"Diploma","services":[{"service":"Solar cleaning","hourly_rate":325,"years":3,"details":"Rollback-only service details."}]}');
  raise exception 'FAIL: application without phone succeeded';
 exception when not_null_violation then null; end;
 if exists(select 1 from public.professionals where user_id=auth.uid()) then raise exception 'FAIL: partial application persisted'; end if;
end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.customer'),'role','authenticated')::text,true);
set local role authenticated;
insert into public.bookings(id,customer_id,professional_id,professional_name,service,starts_at,hours,duration_minutes,ends_at,address,total)
select current_setting('test.'||which)::uuid,auth.uid(),current_setting('test.professional')::uuid,'server replaces this','Plumbing',now()+delay,1,75,now()+interval '10 days','Rollback-only service address, Ernakulam',1
from (values ('near',interval '10 minutes'),('future',interval '2 days'),('decline',interval '4 days')) v(which,delay);
do $$ begin
 if (select count(*) from public.bookings where professional_id=current_setting('test.professional')::uuid and total=563 and duration_minutes=75 and hours=1.25 and ends_at=starts_at+interval '75 minutes')<>3 then raise exception 'FAIL: custom duration or service-specific price'; end if;
 if exists(select 1 from public.worker_contacts) then raise exception 'FAIL: contact before confirmation'; end if;
 begin
  insert into public.bookings(customer_id,professional_id,professional_name,service,starts_at,hours,address,total) values(auth.uid(),current_setting('test.professional')::uuid,'x','Electrical',now()+interval '6 days',1,'Rollback-only address, Ernakulam',1);
  raise exception 'FAIL: unoffered service booked';
 exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
 begin
  insert into public.bookings(customer_id,professional_id,professional_name,service,starts_at,hours,address,total) values(auth.uid(),current_setting('test.professional')::uuid,'x','Plumbing',now()+interval '10 minutes',1,'Rollback-only address, Ernakulam',1);
  raise exception 'FAIL: overlapping booking';
 exception when exclusion_violation then null; end;
end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.worker'),'role','authenticated')::text,true);
set local role authenticated;
update public.bookings set status='accepted' where id in (current_setting('test.near')::uuid,current_setting('test.future')::uuid);
update public.bookings set status='cancelled' where id=current_setting('test.decline')::uuid;
do $$ begin
 begin
  insert into public.worker_locations(booking_id,latitude,longitude,accuracy) values(current_setting('test.future')::uuid,10,76,10);
  raise exception 'FAIL: early tracking';
 exception when insufficient_privilege then null; end;
 begin
  update public.bookings set journey_status='on_way' where id=current_setting('test.future')::uuid;
  raise exception 'FAIL: early journey';
 exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
end $$;
insert into public.worker_locations(booking_id,latitude,longitude,accuracy) values(current_setting('test.near')::uuid,10,76,10);
insert into public.worker_availability(professional_id,latitude,longitude) values(current_setting('test.professional')::uuid,10.123456,76.123456);
do $$ begin
 if (select latitude from public.worker_availability where professional_id=current_setting('test.professional')::uuid)<>10.123 then raise exception 'FAIL: discovery position not coarse'; end if;
end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.other'),'role','authenticated')::text,true);
set local role authenticated;
do $$ begin
 if exists(select 1 from public.bookings where professional_id=current_setting('test.professional')::uuid) or exists(select 1 from public.worker_contacts) or exists(select 1 from public.worker_locations) or exists(select 1 from public.booking_notifications) then raise exception 'FAIL: unrelated access'; end if;
 begin
  insert into public.booking_messages(booking_id,sender_id,body) values(current_setting('test.near')::uuid,auth.uid(),'Rollback-only message');raise exception 'FAIL: unrelated chat';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.customer'),'role','authenticated')::text,true);
set local role authenticated;
do $$ begin
 if (select count(*) from public.booking_notifications where status='accepted')<>2 then raise exception 'FAIL: confirmation notifications'; end if;
 if (select count(*) from public.bookings where status='cancelled')<>1 then raise exception 'FAIL: declined status'; end if;
 if not exists(select 1 from public.worker_contacts where phone='+919876543210') then raise exception 'FAIL: appointment day contact'; end if;
 if (select count(*) from public.worker_locations)<>1 then raise exception 'FAIL: confirmed tracking visibility'; end if;
 begin
  insert into public.reviews(booking_id,professional_id,customer_id,author_name,rating,body) values(current_setting('test.near')::uuid,current_setting('test.professional')::uuid,auth.uid(),'Rollback Customer',5,'Rollback-only review');raise exception 'FAIL: review before completion';
 exception when insufficient_privilege then null; end;
end $$;
insert into public.booking_messages(booking_id,sender_id,body) values(current_setting('test.near')::uuid,auth.uid(),'Rollback-only booking message');
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.worker'),'role','authenticated')::text,true);
set local role authenticated;
do $$ begin
 if not exists(select 1 from public.booking_messages where booking_id=current_setting('test.near')::uuid) then raise exception 'FAIL: worker chat visibility'; end if;
end $$;
update public.bookings set journey_status='on_way' where id=current_setting('test.near')::uuid;
update public.bookings set journey_status='arrived' where id=current_setting('test.near')::uuid;
update public.bookings set journey_status='in_progress' where id=current_setting('test.near')::uuid;
update public.bookings set status='completed',work_notes='Rollback-only actual completion notes' where id=current_setting('test.near')::uuid;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.customer'),'role','authenticated')::text,true);
set local role authenticated;
do $$ begin
 if exists(select 1 from public.worker_locations) then raise exception 'FAIL: tracking after completion'; end if;
 if not exists(select 1 from public.bookings where id=current_setting('test.near')::uuid and journey_status='finished' and work_completed_at is not null) then raise exception 'FAIL: milestones not saved'; end if;
end $$;
insert into public.reviews(booking_id,professional_id,customer_id,author_name,rating,body) values(current_setting('test.near')::uuid,current_setting('test.professional')::uuid,auth.uid(),'Rollback Customer',5,'Rollback-only completed review');
do $$ begin
 if not exists(select 1 from public.professional_directory where id=current_setting('test.professional')::uuid and rating=5 and review_count=1) then raise exception 'FAIL: genuine review aggregate'; end if;
 begin
  insert into public.reviews(booking_id,professional_id,customer_id,author_name,rating,body) values(current_setting('test.near')::uuid,current_setting('test.professional')::uuid,auth.uid(),'Rollback Customer',5,'Duplicate rollback review');raise exception 'FAIL: duplicate review';
 exception when unique_violation then null; end;
end $$;
reset role;
rollback;
select 'PASS: atomic phone application, service pricing, custom duration, overlap, decisions, notifications, private tracking, day contact, milestones, chat and completed-only reviews. No records persisted.' as result;
