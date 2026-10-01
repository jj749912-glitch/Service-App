create or replace function public.prepare_booking() returns trigger language plpgsql security invoker set search_path='' as $$
declare p public.professionals;
begin
 select * into strict p from public.professionals where id=new.professional_id;
 if not p.verified or p.user_id is null or p.user_id=auth.uid() then raise exception 'Choose a verified professional other than yourself'; end if;
 if new.starts_at<=now() or new.starts_at>now()+interval '90 days' then raise exception 'Choose a future slot within 90 days'; end if;
 new.professional_name=p.name;new.service=p.service;new.total=p.hourly_rate*new.hours;
 new.ends_at=new.starts_at+new.hours*interval '1 hour';
 return new;
end; $$;
