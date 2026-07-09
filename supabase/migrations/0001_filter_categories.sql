-- User-defined filter categories (blob: one row per user, jsonb array).
create table if not exists public.filter_categories (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.filter_categories enable row level security;

create policy "filter_categories_select_own"
  on public.filter_categories for select
  using (auth.uid() = user_id);

create policy "filter_categories_insert_own"
  on public.filter_categories for insert
  with check (auth.uid() = user_id);

create policy "filter_categories_update_own"
  on public.filter_categories for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
