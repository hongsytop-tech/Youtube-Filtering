-- Register a scheduled feed refresh via pg_cron + pg_net.
-- Run this in the Supabase SQL Editor AFTER replacing the placeholders.
-- Enable the extensions first (Dashboard → Database → Extensions):
--   pg_cron, pg_net

-- Placeholders:
--   «PROJECT_REF»       e.g. abcd1234
--   «SCHEDULER_SECRET»  same value set as the YT_SCHEDULER_SECRET function secret

select cron.schedule(
  'fetch-youtube-feed',
  '0 * * * *', -- hourly
  $$
  select net.http_post(
    url     := 'https://«PROJECT_REF».supabase.co/functions/v1/fetch-feed',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-scheduler-secret', '«SCHEDULER_SECRET»'
    ),
    body    := '{}'::jsonb
  );
  $$
);

-- To remove:  select cron.unschedule('fetch-youtube-feed');
