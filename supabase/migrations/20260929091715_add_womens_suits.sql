-- Allow suits to be assigned to either the women's or men's catalogue.
alter table public.products
  drop constraint if exists products_audience_category_check;

alter table public.products
  add constraint products_audience_category_check
  check (
    (audience = 'Men' and category in ('Suit', 'Topwear', 'Bottomwear', 'Shoes', 'Accessories'))
    or
    (audience = 'Woman' and category in ('Suit', 'Outfit', 'Topwear', 'Bottomwear', 'Footwear', 'Dresses', 'Shoes', 'Bags', 'Accessories'))
  );

update public.shop_settings
set enabled_categories = enabled_categories || '["Suit"]'::jsonb,
    updated_at = now()
where not enabled_categories @> '["Suit"]'::jsonb;
