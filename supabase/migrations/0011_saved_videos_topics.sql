-- Store the LLM topic tags on each favorite so favorites can be grouped by
-- 주제(topic) even after the video leaves the feed. Empty for link-added ones.
alter table public.saved_videos
  add column if not exists topics jsonb not null default '[]'::jsonb;
