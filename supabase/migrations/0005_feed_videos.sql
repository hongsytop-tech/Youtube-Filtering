-- Server-populated feed cache. Written by the fetch-feed Edge Function
-- (service role); each user reads only their own rows.
create table if not exists public.feed_videos (
  user_id       uuid not null references auth.users (id) on delete cascade,
  video_id      text not null,
  title         text not null default '',
  channel_id    text not null default '',
  channel_title text not null default '',
  thumbnail_url text not null default '',
  category_id   text not null default '',
  published_at  timestamptz,
  fetched_at    timestamptz not null default now(),
  primary key (user_id, video_id)
);

create index if not exists feed_videos_user_published_idx
  on public.feed_videos (user_id, published_at desc);

alter table public.feed_videos enable row level security;

create policy "feed_videos_select_own"
  on public.feed_videos for select
  using (auth.uid() = user_id);
-- No insert/update/delete policies: only the service role writes here.
