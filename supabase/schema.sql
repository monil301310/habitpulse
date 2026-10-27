-- HabitPulse V1 schema for Supabase.
-- Run this once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.

-- ---------------------------------------------------------------- habits
create table if not exists public.habits (
  id                text primary key,
  user_id           uuid not null default auth.uid(),
  name              text not null,
  icon              text not null default 'bolt',
  colour            text not null default '#4ADE80',
  type              text not null default 'yes_no',
  target_value      double precision,
  unit              text,
  schedule_type     text not null default 'daily',
  schedule_days     text not null default '',
  times_per_week    integer,
  start_date        text,
  archived_at       timestamptz,
  sort_order        integer not null default 0,
  source            text not null default 'manual',
  created_at        timestamptz not null,
  updated_at        timestamptz not null,
  deleted_at        timestamptz
);

-- ------------------------------------------------------------- reminders
create table if not exists public.reminders (
  id          text primary key,
  user_id     uuid not null default auth.uid(),
  habit_id    text not null references public.habits(id) on delete cascade,
  time_of_day text not null,
  days_of_week text not null default '',
  enabled     boolean not null default true,
  updated_at  timestamptz not null,
  deleted_at  timestamptz
);

-- ------------------------------------------------------------------ logs
-- No unique constraint on (habit_id, date): two offline devices may create
-- different ids for the same day and the client merges them by "done wins".
create table if not exists public.logs (
  id          text primary key,
  user_id     uuid not null default auth.uid(),
  habit_id    text not null references public.habits(id) on delete cascade,
  date        text not null,
  value       double precision not null default 0,
  status      text not null default 'done',
  note        text,
  updated_at  timestamptz not null,
  deleted_at  timestamptz
);

-- -------------------------------------------------------------- settings
create table if not exists public.settings (
  user_id               uuid primary key default auth.uid(),
  theme                 text not null default 'dark',
  week_start            integer not null default 1,
  day_rollover_time     text not null default '03:00',
  quiet_hours           text not null default '23:00-07:00',
  recheck_time          text not null default '21:30',
  morning_recheck_time  text,
  notification_sound    boolean not null default true,
  updated_at            timestamptz not null
);

-- ---------------------------------------------------------------- indexes
create index if not exists habits_user_updated_idx
  on public.habits (user_id, updated_at);

create index if not exists reminders_user_updated_idx
  on public.reminders (user_id, updated_at);
create index if not exists reminders_habit_idx
  on public.reminders (habit_id);

create index if not exists logs_user_updated_idx
  on public.logs (user_id, updated_at);
create index if not exists logs_habit_date_idx
  on public.logs (habit_id, date);

-- ------------------------------------------------------ row level security
alter table public.habits    enable row level security;
alter table public.reminders enable row level security;
alter table public.logs      enable row level security;
alter table public.settings  enable row level security;

drop policy if exists habits_owner on public.habits;
create policy habits_owner on public.habits
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists reminders_owner on public.reminders;
create policy reminders_owner on public.reminders
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists logs_owner on public.logs;
create policy logs_owner on public.logs
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists settings_owner on public.settings;
create policy settings_owner on public.settings
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- --------------------------------------------------------------- realtime
-- Adds the tables to Supabase Realtime so other devices update within seconds.
do $$
begin
  begin
    alter publication supabase_realtime add table public.habits;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.reminders;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.logs;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.settings;
  exception when duplicate_object then null;
  end;
end $$;
