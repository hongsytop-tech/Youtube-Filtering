-- Transcript (collected by the extension) + on-demand AI summary cache.
alter table public.feed_videos
  add column if not exists transcript text;

alter table public.feed_videos
  add column if not exists summary text;

alter table public.feed_videos
  add column if not exists summarized_at timestamptz;
