-- Private review history for the signed-in customer profile.
create or replace function public.customer_review_history()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  customer_id uuid := (select auth.uid());
begin
  if customer_id is null then
    raise exception 'Sign in with Google to view your reviews';
  end if;

  return (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', r.id,
          'product_id', r.product_id,
          'rating', r.rating,
          'body', r.body,
          'created_at', r.created_at
        ) order by r.created_at desc
      ),
      '[]'::jsonb
    )
    from public.product_reviews r
    where r.user_id = customer_id
  );
end $$;

revoke all on function public.customer_review_history() from public, anon;
grant execute on function public.customer_review_history() to authenticated;
