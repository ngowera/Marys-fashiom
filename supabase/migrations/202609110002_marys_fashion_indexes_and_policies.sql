alter table public.stock_events add column if not exists order_id text references public.orders(id) on delete restrict;

create index if not exists order_items_order_id_idx on public.order_items(order_id);
create index if not exists order_items_product_id_idx on public.order_items(product_id);
create index if not exists stock_events_product_id_idx on public.stock_events(product_id);
create index if not exists stock_events_order_id_idx on public.stock_events(order_id);
create index if not exists returns_order_id_idx on public.returns(order_id);
create index if not exists payment_collections_order_id_idx on public.payment_collections(order_id);

drop policy if exists "Products are visible to shoppers" on public.products;
create policy "Active products are visible to shoppers"
on public.products for select to anon
using (active = true);
create policy "Staff can view every product"
on public.products for select to authenticated
using ((select private.is_staff()));

drop policy if exists "Settings are visible to shoppers" on public.shop_settings;
create policy "Settings are visible to shoppers"
on public.shop_settings for select to anon
using (true);
create policy "Staff can view settings"
on public.shop_settings for select to authenticated
using ((select private.is_staff()));
