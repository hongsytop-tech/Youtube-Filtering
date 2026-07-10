-- Track which version of the classifier tagged each row. When we improve the
-- prompt/taxonomy we bump TAGGER_VERSION in tag-feed; rows with an older (or
-- null) version are automatically re-tagged on the next runs. This lets the
-- classifier evolve without a manual reset.
alter table public.feed_videos
  add column if not exists tagger_version int;

create index if not exists feed_videos_tagger_version_idx
  on public.feed_videos (user_id, tagger_version);
