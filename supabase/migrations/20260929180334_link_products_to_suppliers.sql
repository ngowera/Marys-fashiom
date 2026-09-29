-- Keep supplier details private to staff and snapshot the supplier on each sale.
alter table public.suppliers
  add column if not exists phone text not null default '',
  add column if not exists location text not null default '';

update public.suppliers
set phone = trim(contact)
where trim(phone) = '' and trim(contact) <> '';

alter table public.suppliers
  drop constraint if exists suppliers_phone_check;
alter table public.suppliers
  add constraint suppliers_phone_check
  check (trim(phone) = '' or length(trim(phone)) between 7 and 30);

create table if not exists public.product_suppliers (
  product_id text primary key references public.products(id) on delete cascade,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  assigned_at timestamptz not null default now()
);

alter table public.product_suppliers enable row level security;

drop policy if exists "staff manage product suppliers" on public.product_suppliers;
create policy "staff manage product suppliers"
  on public.product_suppliers for all to authenticated
  using ((select private.is_staff()))
  with check ((select private.is_staff()));

revoke all on public.product_suppliers from public, anon;
grant select, insert, update, delete on public.product_suppliers to authenticated;

alter table public.order_items
  add column if not exists supplier_id uuid
  references public.suppliers(id) on delete restrict;

create index if not exists product_suppliers_supplier_idx
  on public.product_suppliers(supplier_id);

create index if not exists order_items_supplier_idx
  on public.order_items(supplier_id)
  where supplier_id is not null;

create or replace function public.place_order(
  p_key text, p_customer text, p_phone text, p_address text, p_delivery text,
  p_items jsonb, p_expected_total integer
) returns jsonb
language plpgsql security definer set search_path = extensions, pg_catalog, public
as $$
declare
  existing public.orders%rowtype; item jsonb; product_row public.products%rowtype;
  quantity integer; selected_variant text; available integer; selling_price integer;
  subtotal integer := 0; fee integer; order_id text; raw_token text; selected_supplier_id uuid;
begin
  if length(trim(p_key)) < 16 then raise exception 'Missing checkout reference'; end if;
  select * into existing from public.orders where idempotency_key = p_key;
  if found then return jsonb_build_object('id',existing.id,'total',existing.total,'status',existing.status); end if;
  if length(trim(p_customer)) not between 1 and 180 or length(regexp_replace(p_phone,'[^0-9]','','g')) not between 9 and 15 or length(trim(p_address)) not between 1 and 500 then raise exception 'Complete valid contact and delivery details'; end if;
  if p_delivery not in ('Pickup','Delivery','Express') then raise exception 'Choose a delivery method'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 50 then raise exception 'Your cart is empty or too large'; end if;
  select case p_delivery when 'Pickup' then 0 when 'Delivery' then standard_delivery_mwk else express_delivery_mwk end into fee from public.shop_settings where id;
  for item in select * from jsonb_array_elements(p_items) loop
    quantity := (item->>'qty')::integer; selected_variant := item->>'variant';
    if quantity not between 1 and 100 then raise exception 'Invalid quantity'; end if;
    select * into product_row from public.products where id = item->>'id' and active for update;
    if not found then raise exception 'Product is unavailable'; end if;
    available := coalesce((product_row.variants->>selected_variant)::integer, -1);
    if available < quantity then raise exception '%: selected size no longer has enough stock', product_row.name; end if;
    selling_price := coalesce(product_row.sale_price, product_row.regular_price);
    subtotal := subtotal + selling_price * quantity;
    product_row.variants := jsonb_set(product_row.variants, array[selected_variant], to_jsonb(available - quantity));
    update public.products set variants = product_row.variants, updated_at = now() where id = product_row.id;
  end loop;
  if subtotal + fee <> p_expected_total then raise exception 'A price changed. Review the updated cart'; end if;
  order_id := 'MF-' || upper(substr(encode(gen_random_bytes(6),'hex'),1,10)); raw_token := encode(gen_random_bytes(24),'base64');
  insert into public.orders(id,tracking_token_hash,idempotency_key,customer_user_id,customer,phone,address,delivery,delivery_fee,total)
  values(order_id,crypt(raw_token,gen_salt('bf')),p_key,(select auth.uid()),trim(p_customer),trim(p_phone),trim(p_address),p_delivery,fee,subtotal+fee);
  for item in select * from jsonb_array_elements(p_items) loop
    select * into product_row from public.products where id = item->>'id';
    select ps.supplier_id into selected_supplier_id
    from public.product_suppliers ps where ps.product_id = product_row.id;
    insert into public.order_items(order_id,product_id,product_name,variant,quantity,unit_price,regular_price,unit_cost,supplier_id)
    values(order_id,product_row.id,product_row.name,item->>'variant',(item->>'qty')::integer,coalesce(product_row.sale_price,product_row.regular_price),product_row.regular_price,product_row.unit_cost,selected_supplier_id);
  end loop;
  return jsonb_build_object('id',order_id,'token',raw_token,'total',subtotal+fee,'status','Placed');
end $$;

revoke execute on function public.place_order(text,text,text,text,text,jsonb,integer) from public;
grant execute on function public.place_order(text,text,text,text,text,jsonb,integer) to anon, authenticated;

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

  if p_action = 'supplier-update' then
    if length(trim(coalesce(p_data->>'name',''))) not between 1 and 180
       or length(regexp_replace(coalesce(p_data->>'phone',''),'[^0-9+]','','g')) not between 7 and 20
       or length(trim(coalesce(p_data->>'location',''))) = 0 then
      raise exception 'Please complete supplier name, phone and location';
    end if;
    update public.suppliers
    set name = trim(p_data->>'name'),
        contact = trim(p_data->>'phone'),
        phone = trim(p_data->>'phone'),
        location = trim(p_data->>'location'),
        notes = left(coalesce(p_data->>'notes',''), 1000)
    where id = (p_data->>'id')::uuid;
    if not found then raise exception 'Supplier not found'; end if;
    return jsonb_build_object('ok', true, 'id', p_data->>'id');
  end if;

  if p_action = 'supplier' then
    if length(trim(coalesce(p_data->>'name',''))) not between 1 and 180
       or length(regexp_replace(coalesce(p_data->>'phone',''),'[^0-9+]','','g')) not between 7 and 20
       or length(trim(coalesce(p_data->>'location',''))) = 0 then
      raise exception 'Please complete supplier name, phone and location';
    end if;
    insert into public.suppliers(name, contact, phone, location, notes)
    values (
      trim(p_data->>'name'),
      trim(p_data->>'phone'),
      trim(p_data->>'phone'),
      trim(p_data->>'location'),
      left(coalesce(p_data->>'notes',''), 1000)
    )
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
    update public.products
    set variants = product_row.variants, updated_at = now()
    where id = product_row.id;
    if nullif(p_data->>'supplier','') is not null then
      insert into public.product_suppliers(product_id, supplier_id, assigned_at)
      values(product_row.id, (p_data->>'supplier')::uuid, now())
      on conflict (product_id) do update
      set supplier_id = excluded.supplier_id, assigned_at = now();
    end if;
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
    select * into order_row from public.orders where id = p_data->>'order_id' for update;
    if not found then raise exception 'Order not found'; end if;
    select * into item_row from public.order_items where id = (p_data->>'order_item_id')::bigint and order_id = order_row.id;
    if not found then raise exception 'Order item not found'; end if;
    quantity := (p_data->>'qty')::integer;
    select coalesce(sum(quantity),0) into previous_returns from public.returns where order_item_id = item_row.id and refund_status <> 'Rejected';
    purchased_quantity := item_row.quantity - previous_returns;
    if quantity < 1 or quantity > purchased_quantity then raise exception 'Return quantity exceeds purchased quantity'; end if;
    amount := least((p_data->>'amount')::integer, item_row.unit_price * quantity);
    insert into public.returns(idempotency_key,order_id,order_item_id,quantity,suitable_for_resale,amount,reason,staff_user_id)
    values(p_data->>'key',order_row.id,item_row.id,quantity,(p_data->>'restock')::boolean,amount,trim(p_data->>'reason'),staff_id);
    if (p_data->>'restock')::boolean then
      select * into product_row from public.products where id = item_row.product_id for update;
      product_row.variants := jsonb_set(product_row.variants,array[item_row.variant],to_jsonb(coalesce((product_row.variants->>item_row.variant)::integer,0)+quantity));
      update public.products set variants=product_row.variants,updated_at=now() where id=product_row.id;
      insert into public.stock_events(idempotency_key,kind,product_id,variant,quantity,delta,order_id,reference,reason,staff_user_id)
      values('return-'||p_data->>'key','Return',item_row.product_id,item_row.variant,quantity,quantity,order_row.id,order_row.id,'Customer return',staff_id);
    end if;
    update public.orders set payment_status = case when amount > 0 then 'Refund pending' else payment_status end, updated_at = now() where id = order_row.id;
    return jsonb_build_object('ok',true);
  end if;

  raise exception 'Unsupported staff operation';
end $$;

revoke all on function public.staff_operation(text,jsonb) from public, anon;
grant execute on function public.staff_operation(text,jsonb) to authenticated;
