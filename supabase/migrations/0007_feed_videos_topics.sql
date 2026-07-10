-- Fine-grained topic tags, assigned by the tag-feed Edge Function (Claude).
-- `tagged_at` distinguishes "not yet processed" (null) from "processed, no
-- topic matched" (empty array) so the tagger never reprocesses a row.
alter table public.feed_videos
  add column if not exists topics text[] not null default '{}';

alter table public.feed_videos
  add column if not exists tagged_at timestamptz;

-- Partial index to quickly find rows still needing tags.
create index if not exists feed_videos_untagged_idx
  on public.feed_videos (user_id)
  where tagged_at is null;
