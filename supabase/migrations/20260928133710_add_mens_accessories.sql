-- Allow accessories to be assigned to either the Men or Woman storefront audience.

alter table public.products
  drop constraint if exists products_audience_category_check;

alter table public.products
  add constraint products_audience_category_check
  check (
    (audience = 'Men' and category in ('Suit', 'Topwear', 'Bottomwear', 'Shoes', 'Accessories'))
    or
    (audience = 'Woman' and category in ('Outfit', 'Topwear', 'Bottomwear', 'Footwear', 'Dresses', 'Shoes', 'Bags', 'Accessories'))
  );
