alter table public.stock_events add column if not exists order_id text references public.orders(id) on delete restrict;

create or replace function public.staff_operation(p_action text, p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  staff_id uuid := auth.uid();
  order_row public.orders%rowtype;
  item_row public.order_items%rowtype;
  product_row public.products%rowtype;
  supplier_id uuid;
  current_status text;
  next_status text;
  quantity integer;
  amount integer;
  available integer;
  previous_returns integer;
  purchased_quantity integer;
begin
  if not private.is_staff() then raise exception 'Staff access required'; end if;

  if p_action = 'supplier' then
    if length(trim(coalesce(p_data->>'name',''))) not between 1 and 180
       or length(trim(coalesce(p_data->>'contact',''))) = 0 then
      raise exception 'Please complete supplier details';
    end if;
    insert into public.suppliers(name, contact, notes)
    values (trim(p_data->>'name'), trim(p_data->>'contact'), left(coalesce(p_data->>'notes',''), 1000))
    returning id into supplier_id;
    return jsonb_build_object('ok', true, 'id', supplier_id);
  end if;

  if p_action = 'stock-event' then
    if length(coalesce(p_data->>'key','')) < 16 then raise exception 'Missing operation reference'; end if;
    if exists (select 1 from public.stock_events where idempotency_key = p_data->>'key') then return jsonb_build_object('ok', true); end if;
    if p_data->>'kind' not in ('Receive','Damaged') then raise exception 'Choose a valid stock operation'; end if;
    quantity := (p_data->>'qty')::integer;
    if quantity < 1 then raise exception 'Enter a positive quantity'; end if;
    select * into product_row from public.products where id = p_data->>'product' for update;
    if not found then raise exception 'Product not found'; end if;
    available := coalesce((product_row.variants->>(p_data->>'variant'))::integer, -1);
    if available < 0 then raise exception 'Choose a valid size / colour'; end if;
    if p_data->>'kind' = 'Damaged' and available < quantity then raise exception 'Not enough available stock'; end if;
    product_row.variants := jsonb_set(product_row.variants, array[p_data->>'variant'], to_jsonb(available + case when p_data->>'kind' = 'Receive' then quantity else -quantity end));
    update public.products set variants = product_row.variants, updated_at = now() where id = product_row.id;
    insert into public.stock_events(idempotency_key, kind, product_id, variant, quantity, delta, supplier_id, reference, reason, staff_user_id)
    values (p_data->>'key', p_data->>'kind', product_row.id, p_data->>'variant', quantity,
      case when p_data->>'kind' = 'Receive' then quantity else -quantity end,
      nullif(p_data->>'supplier','')::uuid, trim(p_data->>'reference'), trim(p_data->>'reason'), staff_id);
    return jsonb_build_object('ok', true);
  end if;

  if p_action = 'status' then
    select * into order_row from public.orders where id = p_data->>'id' for update;
    if not found then raise exception 'Order not found'; end if;
    current_status := order_row.status; next_status := p_data->>'status';
    if not ((current_status = 'Placed' and next_status in ('Packed','Cancelled'))
      or (current_status = 'Packed' and next_status in ('Dispatched','Cancelled'))
      or (current_status = 'Dispatched' and next_status = 'Completed')) then
      raise exception 'This status transition is not allowed';
    end if;
    if next_status = 'Cancelled' then
      for item_row in select * from public.order_items where order_id = order_row.id loop
        select * into product_row from public.products where id = item_row.product_id for update;
        product_row.variants := jsonb_set(product_row.variants, array[item_row.variant], to_jsonb(coalesce((product_row.variants->>item_row.variant)::integer,0) + item_row.quantity));
        update public.products set variants = product_row.variants, updated_at = now() where id = product_row.id;
        insert into public.stock_events(idempotency_key, kind, product_id, variant, quantity, delta, order_id, reference, reason, staff_user_id)
        values ('cancel-' || order_row.id || '-' || item_row.id, 'Adjustment', item_row.product_id, item_row.variant, item_row.quantity, item_row.quantity, order_row.id, order_row.id, 'Order cancelled', staff_id)
        on conflict (idempotency_key) do nothing;
      end loop;
    end if;
    update public.orders set status = next_status, updated_at = now() where id = order_row.id;
    return jsonb_build_object('ok', true, 'status', next_status);
  end if;

  if p_action = 'collection' then
    select * into order_row from public.orders where id = p_data->>'order_id' for update;
    if not found or order_row.status <> 'Completed' then raise exception 'Record payment after completing the order'; end if;
    if order_row.payment_status = 'Paid' then return jsonb_build_object('ok', true); end if;
    insert into public.payment_collections(order_id, amount, reference, staff_user_id)
    values (order_row.id, order_row.total, trim(p_data->>'reference'), staff_id)
    on conflict (order_id) do nothing;
    update public.orders set payment_status = 'Paid', payment_reference = trim(p_data->>'reference'), updated_at = now() where id = order_row.id;
    return jsonb_build_object('ok', true);
  end if;

  if p_action = 'return' then
    if length(coalesce(p_data->>'key','')) < 16 then raise exception 'Missing operation reference'; end if;
    if exists (select 1 from public.returns where idempotency_key = p_data->>'key') then return jsonb_build_object('ok', true); end if;
    select * into order_row from public.orders where id = p_data->>'order_id';
    if not found or order_row.status <> 'Completed' then raise exception 'Returns are recorded for completed orders only'; end if;
    select * into item_row from public.order_items where id = (p_data->>'order_item_id')::bigint and order_id = order_row.id;
    if not found then raise exception 'Order item not found'; end if;
    quantity := (p_data->>'qty')::integer;
    select coalesce(sum(quantity),0) into previous_returns from public.returns where order_item_id = item_row.id;
    purchased_quantity := item_row.quantity;
    if quantity < 1 or quantity + previous_returns > purchased_quantity then raise exception 'Return quantity exceeds the unreturned quantity'; end if;
    amount := quantity * item_row.unit_price;
    insert into public.returns(idempotency_key, order_id, order_item_id, quantity, suitable_for_resale, amount, reason, refund_status, staff_user_id)
    values (p_data->>'key', order_row.id, item_row.id, quantity, (p_data->>'restock')::boolean, amount, trim(p_data->>'reason'), case when exists(select 1 from public.payment_collections where order_id = order_row.id) then 'Pending' else 'Review payment' end, staff_id);
    if (p_data->>'restock')::boolean then
      select * into product_row from public.products where id = item_row.product_id for update;
      product_row.variants := jsonb_set(product_row.variants, array[item_row.variant], to_jsonb(coalesce((product_row.variants->>item_row.variant)::integer,0) + quantity));
      update public.products set variants = product_row.variants, updated_at = now() where id = product_row.id;
      insert into public.stock_events(idempotency_key, kind, product_id, variant, quantity, delta, order_id, reference, reason, staff_user_id)
      values ('return-' || (p_data->>'key'), 'Return', item_row.product_id, item_row.variant, quantity, quantity, order_row.id, order_row.id, trim(p_data->>'reason'), staff_id)
      on conflict (idempotency_key) do nothing;
    end if;
    return jsonb_build_object('ok', true);
  end if;

  raise exception 'Unknown staff operation';
end $$;

revoke all on function public.staff_operation(text, jsonb) from public, anon, authenticated;
grant execute on function public.staff_operation(text, jsonb) to authenticated;