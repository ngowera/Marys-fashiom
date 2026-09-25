-- Supabase installs pgcrypto functions in the extensions schema. These functions
-- use an empty search_path for security, so explicitly include extensions.
alter function public.place_order(text, text, text, text, text, jsonb, integer)
  set search_path = extensions, pg_catalog, public;

alter function public.track_order(text, text)
  set search_path = extensions, pg_catalog, public;

alter function public.begin_paychangu_payment(text, text, text, text)
  set search_path = extensions, pg_catalog, public;

alter function public.paychangu_payment_status(text, text)
  set search_path = extensions, pg_catalog, public;