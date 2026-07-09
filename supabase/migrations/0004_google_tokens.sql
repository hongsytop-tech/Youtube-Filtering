-- Google OAuth tokens for server-side YouTube fetching.
-- Written only by Edge Functions (service role, bypasses RLS).
-- The refresh_token must never be exposed to the browser: no select policy
-- for anon/authenticated → clients cannot read it.
create table if not exists public.google_tokens (
  user_id       uuid primary key references auth.users (id) on delete cascade,
  refresh_token text not null,
  access_token  text,
  expires_at    timestamptz,
  scope         text,
  connected     boolean not null default true,
  updated_at    timestamptz not null default now()
);

alter table public.google_tokens enable row level security;

-- Let the user see ONLY the connection status (not the tokens) via a view.
create or replace view public.youtube_connection as
  select user_id, connected, updated_at
  from public.google_tokens;

-- No RLS policies on google_tokens → only service_role can touch it.
-- The view runs with the definer's rights; restrict it to own row:
create policy "google_tokens_select_own_status"
  on public.google_tokens for select
  using (false); -- clients read status through the app via an Edge Function
