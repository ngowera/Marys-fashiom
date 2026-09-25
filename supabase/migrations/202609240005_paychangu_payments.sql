alter table public.payment_collections
  alter column staff_user_id drop not null;

alter table public.stock_events
  alter column staff_user_id drop not null;

create table if not exists public.payment_transactions (
  tx_ref text primary key,
  order_id text not null references public.orders(id) on delete restrict,
  amount integer not null check (amount > 0),
  currency text not null default 'MWK' check (currency = 'MWK'),
  status text not null default 'pending' check (status in ('pending','success','failed')),
  provider_reference text,
  return_url text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.payment_transactions enable row level security;
create policy "Staff can view payment transactions"
on public.payment_transactions for select to authenticated
using ((select private.is_staff()));

create or replace function public.begin_paychangu_payment(
  p_order_id text,
  p_token text,
  p_tx_ref text,
  p_return_url text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  order_row public.orders%rowtype;
begin
  select * into order_row
  from public.orders
  where id = p_order_id
    and tracking_token_hash = crypt(p_token, tracking_token_hash)
  for update;
  if not found then raise exception 'Order not found'; end if;
  if order_row.status = 'Cancelled' then raise exception 'Cancelled orders cannot be paid'; end if;
  if order_row.payment_status = 'Paid' then raise exception 'Order is already paid'; end if;
  if length(trim(p_tx_ref)) < 12 or length(trim(p_return_url)) < 8 then raise exception 'Invalid payment session'; end if;

  insert into public.payment_transactions(tx_ref, order_id, amount, return_url)
  values (trim(p_tx_ref), order_row.id, order_row.total, p_return_url)
  on conflict (tx_ref) do update set return_url = excluded.return_url, updated_at = now();
  update public.orders
  set payment_status = 'Pending', payment_reference = trim(p_tx_ref), updated_at = now()
  where id = order_row.id and payment_status <> 'Paid';
  return jsonb_build_object('order_id', order_row.id, 'amount', order_row.total,
    'customer', order_row.customer, 'phone', order_row.phone, 'status', 'pending');
end $$;

create or replace function public.paychangu_payment_status(
  p_order_id text,
  p_token text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  order_row public.orders%rowtype;
begin
  select * into order_row from public.orders
  where id = p_order_id and tracking_token_hash = crypt(p_token, tracking_token_hash);
  if not found then raise exception 'Order not found'; end if;
  return jsonb_build_object('id', order_row.id, 'status', order_row.status,
    'payment_status', order_row.payment_status, 'total', order_row.total,
    'payment_reference', order_row.payment_reference);
end $$;

create or replace function public.settle_paychangu_payment(
  p_tx_ref text,
  p_provider_reference text,
  p_amount integer,
  p_status text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  payment_row public.payment_transactions%rowtype;
  order_row public.orders%rowtype;
  item_row public.order_items%rowtype;
  product_row public.products%rowtype;
begin
  select * into payment_row from public.payment_transactions where tx_ref = p_tx_ref for update;
  if not found then raise exception 'Payment transaction not found'; end if;
  select * into order_row from public.orders where id = payment_row.order_id for update;
  if p_status = 'success' then
    if p_amount < payment_row.amount then raise exception 'Paid amount is below the order total'; end if;
    update public.payment_transactions set status = 'success', provider_reference = p_provider_reference, updated_at = now() where tx_ref = p_tx_ref;
    update public.orders set payment_status = 'Paid', payment_reference = coalesce(p_provider_reference, p_tx_ref), updated_at = now() where id = order_row.id;
    insert into public.payment_collections(order_id, amount, reference)
    values (order_row.id, p_amount, coalesce(p_provider_reference, p_tx_ref))
    on conflict (order_id) do update set amount = excluded.amount, reference = excluded.reference;
  else
    update public.payment_transactions set status = 'failed', provider_reference = p_provider_reference, updated_at = now() where tx_ref = p_tx_ref and status <> 'success';
    if order_row.status not in ('Cancelled','Completed') and order_row.payment_status <> 'Paid' then
      for item_row in select * from public.order_items where order_id = order_row.id loop
        select * into product_row from public.products where id = item_row.product_id for update;
        product_row.variants := jsonb_set(product_row.variants, array[item_row.variant], to_jsonb(coalesce((product_row.variants->>item_row.variant)::integer,0) + item_row.quantity));
        update public.products set variants = product_row.variants, updated_at = now() where id = product_row.id;
        insert into public.stock_events(idempotency_key, kind, product_id, variant, quantity, delta, order_id, reference, reason, staff_user_id)
        values ('payment-failed-' || order_row.id || '-' || item_row.id, 'Adjustment', item_row.product_id, item_row.variant, item_row.quantity, item_row.quantity, order_row.id, p_tx_ref, 'Payment failed; stock released', null)
        on conflict (idempotency_key) do nothing;
      end loop;
      update public.orders set status = 'Cancelled', payment_status = 'Failed', updated_at = now() where id = order_row.id;
    else
      update public.orders set payment_status = 'Failed', updated_at = now() where id = order_row.id and payment_status <> 'Paid';
    end if;
  end if;
  return jsonb_build_object('ok', true, 'order_id', order_row.id, 'status', p_status);
end $$;

revoke all on function public.begin_paychangu_payment(text,text,text,text) from public, authenticated;
grant execute on function public.begin_paychangu_payment(text,text,text,text) to anon;
revoke all on function public.paychangu_payment_status(text,text) from public, authenticated;
grant execute on function public.paychangu_payment_status(text,text) to anon;
revoke all on function public.settle_paychangu_payment(text,text,integer,text) from public, anon, authenticated;
grant execute on function public.settle_paychangu_payment(text,text,integer,text) to service_role;