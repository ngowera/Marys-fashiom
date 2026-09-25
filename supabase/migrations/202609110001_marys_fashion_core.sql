create extension if not exists pgcrypto;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.staff_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(trim(display_name)) between 1 and 120),
  created_at timestamptz not null default now()
);

create table public.products (
  id text primary key,
  name text not null check (length(trim(name)) between 1 and 180),
  category text not null check (category in ('Dresses','Shoes','Bags','Accessories')),
  regular_price integer not null check (regular_price > 0),
  sale_price integer check (sale_price > 0 and sale_price < regular_price),
  unit_cost integer not null default 0 check (unit_cost >= 0),
  description text not null default '',
  images jsonb not null default '[]'::jsonb check (jsonb_typeof(images) = 'array' and jsonb_array_length(images) between 1 and 4),
  variants jsonb not null default '{}'::jsonb check (jsonb_typeof(variants) = 'object'),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.orders (
  id text primary key,
  tracking_token_hash text not null,
  idempotency_key text not null unique check (length(idempotency_key) between 16 and 120),
  customer text not null,
  phone text not null,
  address text not null,
  delivery text not null check (delivery in ('Pickup','Delivery','Express')),
  delivery_fee integer not null check (delivery_fee >= 0),
  total integer not null check (total > 0),
  status text not null default 'Placed' check (status in ('Placed','Packed','Dispatched','Completed','Cancelled')),
  payment_status text not null default 'Due' check (payment_status in ('Due','Pending','Paid','Failed','Refund pending','Refunded')),
  payment_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_items (
  id bigint generated always as identity primary key,
  order_id text not null references public.orders(id) on delete restrict,
  product_id text not null references public.products(id) on delete restrict,
  product_name text not null,
  variant text not null,
  quantity integer not null check (quantity between 1 and 100),
  unit_price integer not null check (unit_price > 0),
  regular_price integer not null check (regular_price > 0),
  unit_cost integer not null check (unit_cost >= 0)
);

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 180),
  contact text not null,
  notes text not null default '',
  created_at timestamptz not null default now()
);

create table public.stock_events (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique,
  kind text not null check (kind in ('Receive','Damaged','Adjustment','Return')),
  product_id text not null references public.products(id) on delete restrict,
  variant text not null,
  quantity integer not null check (quantity > 0),
  delta integer not null check (delta <> 0),
  supplier_id uuid references public.suppliers(id) on delete restrict,
  reference text not null,
  reason text not null,
  staff_user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.returns (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique,
  order_id text not null references public.orders(id) on delete restrict,
  order_item_id bigint not null references public.order_items(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  suitable_for_resale boolean not null default false,
  amount integer not null check (amount >= 0),
  reason text not null,
  refund_status text not null default 'Pending' check (refund_status in ('Pending','Review payment','Refunded','Rejected')),
  staff_user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.payment_collections (
  id uuid primary key default gen_random_uuid(),
  order_id text not null unique references public.orders(id) on delete restrict,
  amount integer not null check (amount > 0),
  reference text not null,
  staff_user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.shop_settings (
  id boolean primary key default true check (id),
  standard_delivery_mwk integer not null default 3000 check (standard_delivery_mwk >= 0),
  express_delivery_mwk integer not null default 6000 check (express_delivery_mwk >= standard_delivery_mwk),
  delivery_areas text not null default '',
  pickup_location text not null default '',
  contact text not null default '',
  returns_policy text not null default '',
  updated_at timestamptz not null default now()
);

insert into public.shop_settings(id) values (true) on conflict do nothing;

create or replace function private.is_staff()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.staff_profiles where user_id = (select auth.uid())) $$;
revoke all on function private.is_staff() from public;
grant usage on schema private to authenticated;
grant execute on function private.is_staff() to authenticated;

alter table public.staff_profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.suppliers enable row level security;
alter table public.stock_events enable row level security;
alter table public.returns enable row level security;
alter table public.payment_collections enable row level security;
alter table public.shop_settings enable row level security;

create policy "active products are public" on public.products for select to anon, authenticated using (active or private.is_staff());
create policy "staff manage products" on public.products for all to authenticated using (private.is_staff()) with check (private.is_staff());
create policy "staff view own profile" on public.staff_profiles for select to authenticated using (user_id = (select auth.uid()));
create policy "staff manage orders" on public.orders for all to authenticated using (private.is_staff()) with check (private.is_staff());
create policy "staff manage order items" on public.order_items for all to authenticated using (private.is_staff()) with check (private.is_staff());
create policy "staff manage suppliers" on public.suppliers for all to authenticated using (private.is_staff()) with check (private.is_staff());
create policy "staff manage stock events" on public.stock_events for all to authenticated using (private.is_staff()) with check (private.is_staff());
create policy "staff manage returns" on public.returns for all to authenticated using (private.is_staff()) with check (private.is_staff());
create policy "staff manage collections" on public.payment_collections for all to authenticated using (private.is_staff()) with check (private.is_staff());
create policy "settings are public" on public.shop_settings for select to anon, authenticated using (true);
create policy "staff manage settings" on public.shop_settings for all to authenticated using (private.is_staff()) with check (private.is_staff());

grant select on public.products, public.shop_settings to anon, authenticated;
grant select, insert, update, delete on public.products, public.orders, public.order_items, public.suppliers, public.stock_events, public.returns, public.payment_collections, public.shop_settings to authenticated;
grant select on public.staff_profiles to authenticated;
grant usage, select on all sequences in schema public to authenticated;
revoke all on public.orders, public.order_items, public.suppliers, public.stock_events, public.returns, public.payment_collections, public.staff_profiles from anon;

create or replace function public.place_order(
  p_key text, p_customer text, p_phone text, p_address text, p_delivery text,
  p_items jsonb, p_expected_total integer
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  existing public.orders%rowtype; item jsonb; product_row public.products%rowtype;
  quantity integer; selected_variant text; available integer; selling_price integer;
  subtotal integer := 0; fee integer; order_id text; raw_token text;
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
  insert into public.orders(id,tracking_token_hash,idempotency_key,customer,phone,address,delivery,delivery_fee,total)
  values(order_id,crypt(raw_token,gen_salt('bf')),p_key,trim(p_customer),trim(p_phone),trim(p_address),p_delivery,fee,subtotal+fee);
  for item in select * from jsonb_array_elements(p_items) loop
    select * into product_row from public.products where id = item->>'id';
    insert into public.order_items(order_id,product_id,product_name,variant,quantity,unit_price,regular_price,unit_cost)
    values(order_id,product_row.id,product_row.name,item->>'variant',(item->>'qty')::integer,coalesce(product_row.sale_price,product_row.regular_price),product_row.regular_price,product_row.unit_cost);
  end loop;
  return jsonb_build_object('id',order_id,'token',raw_token,'total',subtotal+fee,'status','Placed');
end $$;

create or replace function public.track_order(p_id text, p_token text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare o public.orders%rowtype;
begin
  select * into o from public.orders where id=p_id and tracking_token_hash=crypt(p_token,tracking_token_hash);
  if not found then raise exception 'Order not found'; end if;
  return jsonb_build_object('id',o.id,'status',o.status,'total',o.total,'delivery',o.delivery,'created_at',o.created_at,
    'items',(select coalesce(jsonb_agg(jsonb_build_object('name',i.product_name,'variant',i.variant,'qty',i.quantity,'price',i.unit_price)),'[]'::jsonb) from public.order_items i where i.order_id=o.id));
end $$;

revoke execute on function public.place_order(text,text,text,text,text,jsonb,integer) from public, authenticated;
revoke execute on function public.track_order(text,text) from public, authenticated;
grant execute on function public.place_order(text,text,text,text,text,jsonb,integer) to anon;
grant execute on function public.track_order(text,text) to anon;

insert into public.products(id,name,category,regular_price,unit_cost,description,images,variants) values
('D01','The terracotta maxi','Dresses',28500,18000,'An easy silhouette for days that turn into evenings.','["dress.jpg"]','{"S / Terracotta":6,"M / Terracotta":8,"L / Terracotta":4}'),
('D02','The terracotta maxi · curve','Dresses',42000,27000,'A statement dress for celebrations and special evenings.','["evening.jpg"]','{"XL / Terracotta":3,"2XL / Terracotta":5,"3XL / Terracotta":2}'),
('S01','The occasion heel','Shoes',32000,20000,'A polished finishing touch for your favourite outfit.','["heels.jpg"]','{"37 / Black":5,"38 / Black":7,"39 / Black":3,"40 / Black":2}'),
('B01','Everyday carry','Bags',24000,15000,'Room for daily essentials, with a timeless shape.','["bag.jpg"]','{"One size / Tan":9}'),
('S02','Weekend sneakers','Shoes',36000,24000,'Easy-going shoes for your everyday rotation.','["sneakers.jpg"]','{"37 / White":4,"38 / White":6,"39 / White":5}'),
('A01','Everyday sunglasses','Accessories',8500,4500,'A simple accessory to make the outfit your own.','["accessory.jpg"]','{"One size / Black":12}')
on conflict (id) do nothing;

insert into public.stock_events(idempotency_key,kind,product_id,variant,quantity,delta,reference,reason,staff_user_id)
select 'seed-'||p.id||'-'||e.key,'Adjustment',p.id,e.key,(e.value::text)::integer,(e.value::text)::integer,'Initial catalogue','Opening stock',
       (select id from auth.users order by created_at limit 1)
from public.products p cross join lateral jsonb_each(p.variants) e
where exists(select 1 from auth.users)
on conflict (idempotency_key) do nothing;
