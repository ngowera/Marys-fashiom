-- Separate the customer catalogue into Woman and Men sections.
-- Existing products remain in Woman; staff can reassign products in Mary Inventory.

alter table public.products
  add column if not exists audience text not null default 'Woman';

update public.products
set audience = 'Men'
where category = 'Suit';

alter table public.products drop constraint if exists products_audience_check;
alter table public.products
  add constraint products_audience_check
  check (audience in ('Woman', 'Men'));

alter table public.products drop constraint if exists products_category_check;
alter table public.products
  add constraint products_category_check
  check (category in ('Outfit','Topwear','Bottomwear','Footwear','Dresses','Shoes','Bags','Accessories','Suit'));

alter table public.products drop constraint if exists products_audience_category_check;
alter table public.products
  add constraint products_audience_category_check
  check (
    (audience = 'Men' and category in ('Suit', 'Topwear', 'Bottomwear', 'Shoes'))
    or
    (audience = 'Woman' and category in ('Outfit','Topwear','Bottomwear','Footwear','Dresses','Shoes','Bags','Accessories'))
  );

update public.shop_settings
set enabled_categories = enabled_categories || '["Suit"]'::jsonb,
    updated_at = now()
where not enabled_categories @> '["Suit"]'::jsonb;
