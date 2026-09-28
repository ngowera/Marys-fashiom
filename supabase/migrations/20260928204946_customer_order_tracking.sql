-- Let signed-in customers view only orders created by their own Google account.
create or replace function public.customer_orders()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  customer_id uuid := (select auth.uid());
begin
  if customer_id is null then
    raise exception 'Sign in with Google to view your orders';
  end if;

  return (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', o.id,
          'status', o.status,
          'payment_status', o.payment_status,
          'total', o.total,
          'delivery', o.delivery,
          'created_at', o.created_at,
          'updated_at', o.updated_at,
          'items', (
            select coalesce(
              jsonb_agg(
                jsonb_build_object(
                  'name', i.product_name,
                  'variant', i.variant,
                  'qty', i.quantity,
                  'price', i.unit_price
                ) order by i.id
              ),
              '[]'::jsonb
            )
            from public.order_items i
            where i.order_id = o.id
          )
        ) order by o.created_at desc
      ),
      '[]'::jsonb
    )
    from public.orders o
    where o.customer_user_id = customer_id
  );
end $$;

revoke all on function public.customer_orders() from public, anon;
grant execute on function public.customer_orders() to authenticated;

-- Signed-in customers can still track an older guest order with its private code.
grant execute on function public.track_order(text, text) to authenticated;
