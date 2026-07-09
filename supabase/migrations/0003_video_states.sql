-- Per-video interaction state (row-level: hidden / saved / watched).
create table if not exists public.video_states (
  user_id    uuid not null references auth.users (id) on delete cascade,
  video_id   text not null,
  status     text not null default 'none',
  updated_at timestamptz not null default now(),
  primary key (user_id, video_id)
);

alter table public.video_states enable row level security;

create policy "video_states_select_own"
  on public.video_states for select
  using (auth.uid() = user_id);

create policy "video_states_insert_own"
  on public.video_states for insert
  with check (auth.uid() = user_id);

create policy "video_states_update_own"
  on public.video_states for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "video_states_delete_own"
  on public.video_states for delete
  using (auth.uid() = user_id);
