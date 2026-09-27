-- Let authenticated Inventory staff reply publicly to verified product reviews.

alter table public.product_reviews
  add column if not exists reply_body text,
  add column if not exists replied_at timestamptz,
  add column if not exists replied_by uuid references auth.users(id) on delete set null;

alter table public.product_reviews
  drop constraint if exists product_reviews_reply_body_check;
alter table public.product_reviews
  add constraint product_reviews_reply_body_check
  check (reply_body is null or length(trim(reply_body)) between 1 and 2000);

grant select (reply_body, replied_at)
  on public.product_reviews to anon, authenticated;

create or replace function public.staff_reply_product_review(
  p_review_id bigint,
  p_reply text
) returns jsonb
language plpgsql
security definer
set search_path = extensions, pg_catalog, public
as $$
declare
  saved public.product_reviews%rowtype;
begin
  if (select auth.uid()) is null or not private.is_staff() then
    raise exception 'Staff access required';
  end if;
  if length(trim(coalesce(p_reply, ''))) not between 1 and 2000 then
    raise exception 'Write between 1 and 2000 characters';
  end if;

  update public.product_reviews
  set reply_body = trim(p_reply),
      replied_at = now(),
      replied_by = (select auth.uid()),
      updated_at = now()
  where id = p_review_id
  returning * into saved;

  if not found then
    raise exception 'Review not found';
  end if;

  return jsonb_build_object(
    'id', saved.id,
    'reply_body', saved.reply_body,
    'replied_at', saved.replied_at
  );
end $$;

revoke all on function public.staff_reply_product_review(bigint, text)
  from public, anon;
grant execute on function public.staff_reply_product_review(bigint, text)
  to authenticated;
