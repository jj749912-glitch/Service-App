-- Run as a database owner in full. No test accounts or grants persist.
begin;
select set_config('test.admin_claims', (select jsonb_build_object('sub',a.user_id,'role','authenticated','session_id',s.id)::text from private.app_admins a join auth.sessions s on s.user_id=a.user_id order by s.created_at desc limit 1),true);
select set_config('test.new_admin',gen_random_uuid()::text,true);
select set_config('test.next_admin',gen_random_uuid()::text,true);
select set_config('test.unconfirmed',gen_random_uuid()::text,true);
select set_config('test.session',gen_random_uuid()::text,true);
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
 (current_setting('test.new_admin')::uuid, current_setting('test.new_admin')||'@example.invalid',now(),'{"role":"admin"}'),
 (current_setting('test.next_admin')::uuid, current_setting('test.next_admin')||'@example.invalid',now(),'{}'),
 (current_setting('test.unconfirmed')::uuid, current_setting('test.unconfirmed')||'@example.invalid',null,'{}');
insert into auth.sessions(id,user_id,created_at,updated_at) values(current_setting('test.session')::uuid,current_setting('test.new_admin')::uuid,now(),now());
select set_config('test.new_claims',jsonb_build_object('sub',current_setting('test.new_admin'),'role','authenticated','session_id',current_setting('test.session'),'user_metadata',jsonb_build_object('role','admin'))::text,true);
select set_config('request.jwt.claims',current_setting('test.new_claims'),true);
set local role authenticated;
do $$ begin
 if public.is_app_admin() then raise exception 'FAIL: metadata granted administrator'; end if;
 begin perform public.admin_grant_access(auth.uid(),'Unauthorized self promotion',true); raise exception 'FAIL: self promotion allowed'; exception when insufficient_privilege then null; end;
 begin perform public.admin_grant_access(current_setting('test.next_admin')::uuid,'Unauthorized delegation',true); raise exception 'FAIL: ordinary account delegated access'; exception when insufficient_privilege then null; end;
 begin insert into private.app_admins(user_id) values(auth.uid()); raise exception 'FAIL: direct membership write allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims','{}',true);
set local role anon;
do $$ begin
 begin perform public.admin_grant_access(current_setting('test.new_admin')::uuid,'Anonymous promotion',true); raise exception 'FAIL: anonymous promotion'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims',current_setting('test.admin_claims'),true);
set local role authenticated;
do $$ begin
 if not public.is_app_admin() then raise exception 'FAIL: initial administrator needs an active session'; end if;
 begin perform public.admin_grant_access(current_setting('test.new_admin')::uuid,'Unchecked grant',false); raise exception 'FAIL: unchecked grant'; exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
 begin perform public.admin_grant_access(current_setting('test.new_admin')::uuid,'bad',true); raise exception 'FAIL: short reason'; exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
 begin perform public.admin_grant_access(current_setting('test.unconfirmed')::uuid,'Email is not confirmed',true); raise exception 'FAIL: unconfirmed promotion'; exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
 perform public.admin_grant_access(current_setting('test.new_admin')::uuid,'Verified administrator for rollback check',true);
 begin perform public.admin_grant_access(current_setting('test.new_admin')::uuid,'Duplicate promotion',true); raise exception 'FAIL: duplicate grant accepted'; exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
end $$;
reset role;
select set_config('request.jwt.claims',current_setting('test.new_claims'),true);
set local role authenticated;
do $$ begin
 if not public.is_app_admin() then raise exception 'FAIL: new administrator denied with valid session'; end if;
 perform public.admin_list('users');
 perform public.admin_grant_access(current_setting('test.next_admin')::uuid,'New administrator delegates in rollback check',true);
end $$;
reset role;
do $$ begin
 if (select count(*) from private.admin_audit where action='grant_admin' and target_id in (current_setting('test.new_admin')::uuid,current_setting('test.next_admin')::uuid))<>2 then raise exception 'FAIL: grant audit missing'; end if;
end $$;
update auth.users set banned_until=now()+interval '1 day' where id=current_setting('test.unconfirmed')::uuid;
update auth.users set email_confirmed_at=now() where id=current_setting('test.unconfirmed')::uuid;
set local role authenticated;
do $$ begin
 begin perform public.admin_grant_access(current_setting('test.unconfirmed')::uuid,'Banned account promotion',true); raise exception 'FAIL: banned promotion'; exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
end $$;
reset role;
update auth.users set banned_until=null,deleted_at=now() where id=current_setting('test.unconfirmed')::uuid;
set local role authenticated;
do $$ begin
 begin perform public.admin_grant_access(current_setting('test.unconfirmed')::uuid,'Deleted account promotion',true); raise exception 'FAIL: deleted promotion'; exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
end $$;
reset role;
delete from auth.sessions where id=current_setting('test.session')::uuid;
set local role authenticated;
do $$ begin
 if public.is_app_admin() then raise exception 'FAIL: terminated session still allowed'; end if;
 begin perform public.admin_grant_access(current_setting('test.unconfirmed')::uuid,'Terminated session promotion',true); raise exception 'FAIL: invalid session promoted'; exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
select 'PASS: admin delegation, confirmation, audit, identity and session checks; all fixtures rolled back' as result;
