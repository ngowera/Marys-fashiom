-- Real customer reviews, restricted to authenticated purchasers.

alter table public.orders
  add column if not exists customer_user_id uuid references auth.users(id) on delete set null;

create index if not exists orders_customer_user_idx
  on public.orders(customer_user_id, created_at desc)
  where customer_user_id is not null;

create table if not exists public.product_reviews (
  id bigint generated always as identity primary key,
  product_id text not null references public.products(id) on delete cascade,
  order_id text not null references public.orders(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  reviewer_name text not null check (length(trim(reviewer_name)) between 1 and 80),
  rating smallint not null check (rating between 1 and 5),
  body text not null check (length(trim(body)) between 10 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, product_id)
);

create index if not exists product_reviews_product_idx
  on public.product_reviews(product_id, created_at desc);

alter table public.product_reviews enable row level security;

drop policy if exists "published reviews are public" on public.product_reviews;
create policy "published reviews are public"
on public.product_reviews for select
to anon, authenticated
using (true);

drop policy if exists "staff moderate reviews" on public.product_reviews;
create policy "staff moderate reviews"
on public.product_reviews for delete
to authenticated
using (private.is_staff());

revoke all on public.product_reviews from public, anon, authenticated;
grant select (id, product_id, reviewer_name, rating, body, created_at)
  on public.product_reviews to anon, authenticated;
grant delete on public.product_reviews to authenticated;
create or replace function public.submit_product_review(
  p_product_id text,
  p_rating integer,
  p_body text
) returns jsonb
language plpgsql
security definer
set search_path = extensions, pg_catalog, public
as $$
declare
  buyer_id uuid := (select auth.uid());
  purchase public.orders%rowtype;
  customer_words text[];
  public_name text;
  saved public.product_reviews%rowtype;
begin
  if buyer_id is null then
    raise exception 'Sign in before writing a review';
  end if;
  if p_rating not between 1 and 5 then
    raise exception 'Choose a rating from 1 to 5';
  end if;
  if length(trim(coalesce(p_body, ''))) not between 10 and 1000 then
    raise exception 'Write between 10 and 1000 characters';
  end if;

  select o.* into purchase
  from public.orders o
  where o.customer_user_id = buyer_id
    and (o.status = 'Completed' or o.payment_status = 'Paid')
    and exists (
      select 1 from public.order_items i
      where i.order_id = o.id and i.product_id = p_product_id
    )
  order by o.created_at desc
  limit 1;

  if not found then
    raise exception 'Only customers who purchased this item can review it';
  end if;

  customer_words := regexp_split_to_array(trim(purchase.customer), '\\s+');
  public_name := customer_words[1];
  if coalesce(array_length(customer_words, 1), 0) > 1 then
    public_name := public_name || ' ' || upper(left(customer_words[array_length(customer_words, 1)], 1)) || '.';
  end if;

  insert into public.product_reviews(product_id, order_id, user_id, reviewer_name, rating, body)
  values (p_product_id, purchase.id, buyer_id, public_name, p_rating, trim(p_body))
  on conflict (user_id, product_id) do update
    set rating = excluded.rating,
        body = excluded.body,
        order_id = excluded.order_id,
        reviewer_name = excluded.reviewer_name,
        updated_at = now()
  returning * into saved;

  return jsonb_build_object(
    'id', saved.id,
    'product_id', saved.product_id,
    'reviewer_name', saved.reviewer_name,
    'rating', saved.rating,
    'body', saved.body,
    'created_at', saved.created_at
  );
end $$;

revoke all on function public.submit_product_review(text, integer, text) from public, anon;
grant execute on function public.submit_product_review(text, integer, text) to authenticated;

create or replace function public.place_order(
  p_key text, p_customer text, p_phone text, p_address text, p_delivery text,
  p_items jsonb, p_expected_total integer
) returns jsonb
language plpgsql security definer set search_path = extensions, pg_catalog, public
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
  insert into public.orders(id,tracking_token_hash,idempotency_key,customer_user_id,customer,phone,address,delivery,delivery_fee,total)
  values(order_id,crypt(raw_token,gen_salt('bf')),p_key,(select auth.uid()),trim(p_customer),trim(p_phone),trim(p_address),p_delivery,fee,subtotal+fee);
  for item in select * from jsonb_array_elements(p_items) loop
    select * into product_row from public.products where id = item->>'id';
    insert into public.order_items(order_id,product_id,product_name,variant,quantity,unit_price,regular_price,unit_cost)
    values(order_id,product_row.id,product_row.name,item->>'variant',(item->>'qty')::integer,coalesce(product_row.sale_price,product_row.regular_price),product_row.regular_price,product_row.unit_cost);
  end loop;
  return jsonb_build_object('id',order_id,'token',raw_token,'total',subtotal+fee,'status','Placed');
end $$;

revoke execute on function public.place_order(text,text,text,text,text,jsonb,integer) from public;
grant execute on function public.place_order(text,text,text,text,text,jsonb,integer) to anon, authenticated;
