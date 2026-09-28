-- Keep the public catalogue visible after a shopper signs in with Google or email.
drop policy if exists "active products are public" on public.products;
drop policy if exists "Products are visible to shoppers" on public.products;
drop policy if exists "Active products are visible to shoppers" on public.products;
drop policy if exists "Staff can view every product" on public.products;

create policy "Active products are visible to shoppers"
on public.products for select to anon, authenticated
using (active = true);

create policy "Staff can view every product"
on public.products for select to authenticated
using ((select private.is_staff()));

drop policy if exists "settings are public" on public.shop_settings;
drop policy if exists "Settings are visible to shoppers" on public.shop_settings;
drop policy if exists "Staff can view settings" on public.shop_settings;

create policy "Settings are visible to shoppers"
on public.shop_settings for select to anon, authenticated
using (true);

create policy "Staff can view settings"
on public.shop_settings for select to authenticated
using ((select private.is_staff()));

grant select on public.products, public.shop_settings to anon, authenticated;
