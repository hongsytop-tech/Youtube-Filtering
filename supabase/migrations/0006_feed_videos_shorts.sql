-- Store Shorts too (marked), so the app can include/exclude them via a toggle.
alter table public.feed_videos
  add column if not exists duration_seconds int;

alter table public.feed_videos
  add column if not exists is_short boolean not null default false;
