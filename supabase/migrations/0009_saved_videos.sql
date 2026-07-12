-- Favorited / saved videos. Stores a snapshot of the video's metadata so a
-- favorite persists even after it leaves the feed (or was added by link).
-- Written directly by the client (RLS: each user only their own rows).
create table if not exists public.saved_videos (
  user_id       uuid not null references auth.users (id) on delete cascade,
  video_id      text not null,
  title         text not null default '',
  channel_title text not null default '',
  thumbnail_url text not null default '',
  published_at  timestamptz,
  pinned        boolean not null default false,
  created_at    timestamptz not null default now(),
  primary key (user_id, video_id)
);

create index if not exists saved_videos_user_idx
  on public.saved_videos (user_id, pinned desc, created_at desc);

alter table public.saved_videos enable row level security;

create policy "saved_videos_select_own"
  on public.saved_videos for select
  using (auth.uid() = user_id);

create policy "saved_videos_insert_own"
  on public.saved_videos for insert
  with check (auth.uid() = user_id);

create policy "saved_videos_update_own"
  on public.saved_videos for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "saved_videos_delete_own"
  on public.saved_videos for delete
  using (auth.uid() = user_id);
