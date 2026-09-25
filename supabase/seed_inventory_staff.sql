-- Run this in Supabase SQL Editor after creating both email/password users
-- under Authentication > Users.
-- This does not create or change passwords.

do $$
declare
  missing_emails text[];
begin
  select array_agg(required.email order by required.email)
    into missing_emails
  from (values
    ('ngowelak@gmail.com'),
    ('marytamvekenji@gmail.com')
  ) as required(email)
  where not exists (
    select 1
    from auth.users
    where lower(email) = required.email
  );

  if missing_emails is not null then
    raise exception 'Create these Supabase Auth users first: %', array_to_string(missing_emails, ', ');
  end if;
end $$;

insert into public.staff_profiles (user_id, display_name)
select
  id,
  case lower(email)
    when 'ngowelak@gmail.com' then 'Ngowelak'
    when 'marytamvekenji@gmail.com' then 'Mary Tamvekenji'
  end
from auth.users
where lower(email) in ('ngowelak@gmail.com', 'marytamvekenji@gmail.com')
on conflict (user_id) do update
set display_name = excluded.display_name;

-- Confirm both accounts are now authorized for inventory.
select
  u.email,
  s.display_name,
  s.created_at
from public.staff_profiles s
join auth.users u on u.id = s.user_id
where lower(u.email) in ('ngowelak@gmail.com', 'marytamvekenji@gmail.com')
order by u.email;
