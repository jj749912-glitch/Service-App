alter table public.professionals drop constraint professional_city;
alter table public.professionals add constraint professional_city check(city in ('Ernakulam','Thrissur'));
