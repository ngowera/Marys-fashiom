-- Expanded product taxonomy and optional storefront collections.

alter table public.products drop constraint if exists products_category_check;
alter table public.products
  add constraint products_category_check
  check (category in ('Outfit','Topwear','Bottomwear','Footwear','Dresses','Shoes','Bags','Accessories'));

alter table public.products
  add column if not exists collections jsonb not null default '[]'::jsonb;

alter table public.products drop constraint if exists products_collections_check;
alter table public.products
  add constraint products_collections_check
  check (
    jsonb_typeof(collections) = 'array'
    and collections <@ '["New Arrivals", "Best Sellers", "Sale / Clearance"]'::jsonb
  );
