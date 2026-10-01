alter table public.professionals add constraint professional_years check(years between 0 and 60),
 add constraint professional_price_limit check(hourly_rate<=100000),
 add constraint professional_name_length check(length(name) between 3 and 100),
 add constraint professional_bio_length check(length(bio) between 20 and 2000),
 add constraint professional_service check(service in ('Solar cleaning','Solar inspection','Solar repair','Electrical','Plumbing','Home cleaning')),
 add constraint professional_city check(city in ('Bengaluru','Chennai','Hyderabad'));
alter table public.bookings add constraint booking_notes_length check(length(notes)<=4000);
