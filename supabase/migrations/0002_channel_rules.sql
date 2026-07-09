-- Per-channel rules (blob: one row per user, jsonb array).
create table if not exists public.channel_rules (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.channel_rules enable row level security;

create policy "channel_rules_select_own"
  on public.channel_rules for select
  using (auth.uid() = user_id);

create policy "channel_rules_insert_own"
  on public.channel_rules for insert
  with check (auth.uid() = user_id);

create policy "channel_rules_update_own"
  on public.channel_rules for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
