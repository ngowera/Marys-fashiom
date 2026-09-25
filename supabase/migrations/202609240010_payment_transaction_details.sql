alter table public.payment_transactions
  add column if not exists payment_method text,
  add column if not exists channel text,
  add column if not exists provider_type text,
  add column if not exists provider_mode text,
  add column if not exists provider_charges integer not null default 0,
  add column if not exists completed_at timestamptz;

create or replace function public.settle_paychangu_payment_details(
  p_tx_ref text,
  p_provider_reference text,
  p_amount integer,
  p_status text,
  p_payment_method text,
  p_channel text,
  p_provider_type text,
  p_provider_mode text,
  p_provider_charges integer,
  p_completed_at timestamptz
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare result jsonb;
begin
  select public.settle_paychangu_payment(
    p_tx_ref, p_provider_reference, p_amount, p_status
  ) into result;
  update public.payment_transactions
  set payment_method = nullif(trim(p_payment_method), ''),
      channel = nullif(trim(p_channel), ''),
      provider_type = nullif(trim(p_provider_type), ''),
      provider_mode = nullif(trim(p_provider_mode), ''),
      provider_charges = greatest(coalesce(p_provider_charges, 0), 0),
      completed_at = p_completed_at,
      updated_at = now()
  where tx_ref = p_tx_ref;
  return result;
end $$;

revoke all on function public.settle_paychangu_payment_details(text,text,integer,text,text,text,text,text,integer,timestamptz) from public, anon, authenticated;
grant execute on function public.settle_paychangu_payment_details(text,text,integer,text,text,text,text,text,integer,timestamptz) to service_role;
