-- Favorites folders. Videos get an optional folder_id; the folder list itself
-- is a per-user jsonb blob (id / name / order), mirroring filter_categories.

-- 1) folder assignment on each saved video (null = 미분류/unfiled).
alter table public.saved_videos
  add column if not exists folder_id text;

-- 2) the user's folder list (blob: one row per user, jsonb array).
create table if not exists public.favorite_folders (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.favorite_folders enable row level security;

-- drop-then-create so the migration is safe to re-run.
drop policy if exists "favorite_folders_select_own" on public.favorite_folders;
create policy "favorite_folders_select_own"
  on public.favorite_folders for select
  using (auth.uid() = user_id);

drop policy if exists "favorite_folders_insert_own" on public.favorite_folders;
create policy "favorite_folders_insert_own"
  on public.favorite_folders for insert
  with check (auth.uid() = user_id);

drop policy if exists "favorite_folders_update_own" on public.favorite_folders;
create policy "favorite_folders_update_own"
  on public.favorite_folders for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
