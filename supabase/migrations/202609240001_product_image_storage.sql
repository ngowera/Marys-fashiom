-- Product image storage for the Supabase-backed inventory flow.
-- Run after the core migration and after the two staff profiles exist.

alter table public.products drop constraint if exists products_images_check;
alter table public.products
  add constraint products_images_check
  check (
    jsonb_typeof(images) = 'array'
    and jsonb_array_length(images) between 1 and 4
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  4194304,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can view product images" on storage.objects;
-- The bucket is public, so direct image URLs work without a SELECT/list policy.
-- This avoids allowing clients to list every file in the bucket.

drop policy if exists "Staff can upload product images" on storage.objects;
create policy "Staff can upload product images"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and exists (
    select 1
    from public.staff_profiles
    where user_id = (select auth.uid())
  )
);

drop policy if exists "Staff can update product images" on storage.objects;
create policy "Staff can update product images"
on storage.objects for update
to authenticated
using (
  bucket_id = 'product-images'
  and exists (
    select 1
    from public.staff_profiles
    where user_id = (select auth.uid())
  )
)
with check (
  bucket_id = 'product-images'
  and exists (
    select 1
    from public.staff_profiles
    where user_id = (select auth.uid())
  )
);

drop policy if exists "Staff can delete product images" on storage.objects;
create policy "Staff can delete product images"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'product-images'
  and exists (
    select 1
    from public.staff_profiles
    where user_id = (select auth.uid())
  )
);

create or replace function private.enforce_product_image_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  product_id text;
  image_count integer;
begin
  if new.bucket_id <> 'product-images' then
    return new;
  end if;

  product_id := (storage.foldername(new.name))[1];
  select count(*) into image_count
  from storage.objects
  where bucket_id = 'product-images'
    and (storage.foldername(name))[1] = product_id;

  if image_count >= 4 then
    raise exception 'A product can have at most 4 images';
  end if;
  return new;
end;
$$;

drop trigger if exists product_image_limit on storage.objects;
create trigger product_image_limit
before insert on storage.objects
for each row execute function private.enforce_product_image_limit();