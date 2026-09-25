-- Messaging RPCs call auth.uid(); include the auth schema in their secure search path.
alter function public.messaging_threads(boolean)
  set search_path = auth, pg_catalog, public, extensions;

alter function public.messaging_messages(uuid)
  set search_path = auth, pg_catalog, public, extensions;

alter function public.messaging_send(uuid, text, text)
  set search_path = auth, pg_catalog, public, extensions;

alter function public.messaging_mark_read(uuid)
  set search_path = auth, pg_catalog, public, extensions;

alter function public.messaging_set_status(uuid, text)
  set search_path = auth, pg_catalog, public, extensions;
