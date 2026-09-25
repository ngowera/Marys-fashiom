create table if not exists public.customer_threads (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null default 'Message from customer' check (length(trim(subject)) between 1 and 180),
  status text not null default 'open' check (status in ('open','closed')),
  last_message_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_messages (
  id bigint generated always as identity primary key,
  thread_id uuid not null references public.customer_threads(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (length(trim(body)) between 1 and 4000),
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists customer_threads_customer_idx on public.customer_threads(customer_user_id, last_message_at desc);
create index if not exists customer_threads_status_idx on public.customer_threads(status, last_message_at desc);
create index if not exists customer_messages_thread_idx on public.customer_messages(thread_id, created_at);

alter table public.customer_threads enable row level security;
alter table public.customer_messages enable row level security;

create policy "Customers view own threads" on public.customer_threads
for select to authenticated using (customer_user_id = auth.uid() or private.is_staff());
create policy "Staff update threads" on public.customer_threads
for update to authenticated using (private.is_staff()) with check (private.is_staff());
create policy "Customers view own messages" on public.customer_messages
for select to authenticated using (
  exists (select 1 from public.customer_threads t where t.id = thread_id and (t.customer_user_id = auth.uid() or private.is_staff()))
);

create or replace function public.messaging_threads(p_staff boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if p_staff and not private.is_staff() then raise exception 'Staff access required'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', t.id,
      'customer_user_id', t.customer_user_id,
      'customer_email', (select u.email from auth.users u where u.id = t.customer_user_id),
      'subject', t.subject,
      'status', t.status,
      'last_message_at', t.last_message_at,
      'unread', exists (select 1 from public.customer_messages m where m.thread_id = t.id and m.read_at is null and m.sender_user_id <> auth.uid()),
      'created_at', t.created_at
    ) order by t.last_message_at desc)
    from public.customer_threads t
    where (p_staff and private.is_staff()) or (not p_staff and t.customer_user_id = auth.uid())), '[]'::jsonb);
end $$;

create or replace function public.messaging_messages(p_thread_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare allowed boolean;
begin
  select (t.customer_user_id = auth.uid() or private.is_staff()) into allowed from public.customer_threads t where t.id = p_thread_id;
  if coalesce(allowed, false) = false then raise exception 'Conversation not found'; end if;
  return coalesce((select jsonb_agg(to_jsonb(m) order by m.created_at)
    from public.customer_messages m where m.thread_id = p_thread_id), '[]'::jsonb);
end $$;

create or replace function public.messaging_send(
  p_thread_id uuid, p_body text, p_subject text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare thread_row public.customer_threads%rowtype; message_row public.customer_messages%rowtype; staff boolean;
begin
  staff := private.is_staff();
  if length(trim(coalesce(p_body,''))) not between 1 and 4000 then raise exception 'Message cannot be empty'; end if;
  if p_thread_id is null then
    if staff then raise exception 'Staff must reply to an existing conversation'; end if;
    insert into public.customer_threads(customer_user_id, subject) values (auth.uid(), coalesce(nullif(trim(p_subject),''),'Message from customer')) returning * into thread_row;
  else
    select * into thread_row from public.customer_threads where id = p_thread_id for update;
    if not found or (not staff and thread_row.customer_user_id <> auth.uid()) then raise exception 'Conversation not found'; end if;
    if thread_row.status = 'closed' and not staff then raise exception 'This conversation is closed'; end if;
    if staff and thread_row.status = 'closed' then update public.customer_threads set status = 'open' where id = thread_row.id; end if;
  end if;
  insert into public.customer_messages(thread_id, sender_user_id, body) values (thread_row.id, auth.uid(), trim(p_body)) returning * into message_row;
  update public.customer_threads set last_message_at = now(), updated_at = now() where id = thread_row.id;
  return jsonb_build_object('thread_id', thread_row.id, 'message', to_jsonb(message_row));
end $$;

create or replace function public.messaging_mark_read(p_thread_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  update public.customer_messages m set read_at = now()
  where m.thread_id = p_thread_id and m.sender_user_id <> auth.uid()
    and exists (select 1 from public.customer_threads t where t.id = p_thread_id and (t.customer_user_id = auth.uid() or private.is_staff()));
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.messaging_set_status(p_thread_id uuid, p_status text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_staff() then raise exception 'Staff access required'; end if;
  if p_status not in ('open','closed') then raise exception 'Invalid conversation status'; end if;
  update public.customer_threads set status = p_status, updated_at = now() where id = p_thread_id;
  return jsonb_build_object('ok', true, 'status', p_status);
end $$;

revoke all on function public.messaging_threads(boolean), public.messaging_messages(uuid), public.messaging_send(uuid,text,text), public.messaging_mark_read(uuid), public.messaging_set_status(uuid,text) from public, anon;
grant execute on function public.messaging_threads(boolean), public.messaging_messages(uuid), public.messaging_send(uuid,text,text), public.messaging_mark_read(uuid), public.messaging_set_status(uuid,text) to authenticated;
