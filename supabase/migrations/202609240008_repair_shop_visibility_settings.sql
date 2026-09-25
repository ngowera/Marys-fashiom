-- Repair for projects where the shop visibility migration was skipped.
alter table public.shop_settings
  add column if not exists enabled_categories jsonb not null default '["Outfit", "Topwear", "Bottomwear", "Footwear", "Dresses", "Shoes", "Bags", "Accessories"]'::jsonb;

alter table public.shop_settings
  add column if not exists enabled_collections jsonb not null default '["New Arrivals", "Best Sellers", "Sale / Clearance"]'::jsonb;

alter table public.shop_settings drop constraint if exists shop_settings_enabled_categories_check;
alter table public.shop_settings
  add constraint shop_settings_enabled_categories_check
  check (jsonb_typeof(enabled_categories) = 'array');

alter table public.shop_settings drop constraint if exists shop_settings_enabled_collections_check;
alter table public.shop_settings
  add constraint shop_settings_enabled_collections_check
  check (jsonb_typeof(enabled_collections) = 'array');

update public.shop_settings
set enabled_categories = '["Outfit", "Topwear", "Bottomwear", "Footwear", "Dresses", "Shoes", "Bags", "Accessories"]'::jsonb
where enabled_categories is null;

update public.shop_settings
set enabled_collections = '["New Arrivals", "Best Sellers", "Sale / Clearance"]'::jsonb
where enabled_collections is null;
