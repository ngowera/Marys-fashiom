-- Allow authenticated staff to read PayChangu transactions.
-- RLS still limits rows to users present in public.staff_profiles.

grant select on table public.payment_transactions to authenticated;
revoke all on table public.payment_transactions from anon;
