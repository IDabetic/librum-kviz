-- Kafanski kviz — music questions. Same shape as Book kviz: separate
-- pool table + per-answer log for 72h dedupe + sessions table for the
-- leaderboard. Plus a tiny extension on game_rooms so Trivia duel can
-- support both PRO and Kafanski pools without forking the duel pages.
--
-- Run once in Supabase SQL Editor.

-- ── Question pool ──────────────────────────────────────────────────────────
create table if not exists public.kafana_questions (
  id uuid primary key default gen_random_uuid(),
  question_text text not null unique,
  options text[] not null,
  correct_answer integer not null default 0,
  difficulty text not null default 'medium',
  is_active boolean not null default true,
  info text,
  tags text[],
  created_at timestamptz not null default now()
);
create index if not exists kafana_questions_active_idx
  on public.kafana_questions (is_active) where is_active = true;

alter table public.kafana_questions enable row level security;

-- Anyone signed in can read active questions.
drop policy if exists kafana_questions_select on public.kafana_questions;
create policy kafana_questions_select on public.kafana_questions
  for select using (auth.role() = 'authenticated');

-- Admins can insert/update/delete via the admin panel (mirrors questions/RLS).
drop policy if exists kafana_questions_admin on public.kafana_questions;
create policy kafana_questions_admin on public.kafana_questions
  for all using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.role in ('urednik', 'moderator', 'super_admin')
    )
  );

-- ── Per-answer log (powers 72h dedupe + admin stats) ─────────────────────
create table if not exists public.kafana_answer_log (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.kafana_questions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  was_correct boolean not null,
  picked_idx integer,
  time_ms integer,
  created_at timestamptz not null default now()
);
create index if not exists kafana_answer_log_user_recent_idx
  on public.kafana_answer_log (user_id, created_at desc);

alter table public.kafana_answer_log enable row level security;

drop policy if exists kafana_answer_log_self on public.kafana_answer_log;
create policy kafana_answer_log_self on public.kafana_answer_log
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ── Solo session results (leaderboard source) ────────────────────────────
create table if not exists public.kafana_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  score integer not null default 0,
  questions_reached integer not null default 0,
  correct_answers integer not null default 0,
  wrong_answers integer not null default 0,
  accuracy numeric(5,2) not null default 0,
  best_combo integer not null default 0,
  total_time_seconds integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists kafana_sessions_score_desc_idx
  on public.kafana_sessions (score desc);
create index if not exists kafana_sessions_user_idx
  on public.kafana_sessions (user_id);

alter table public.kafana_sessions enable row level security;

drop policy if exists kafana_sessions_insert_own on public.kafana_sessions;
create policy kafana_sessions_insert_own on public.kafana_sessions
  for insert with check (user_id = auth.uid());

drop policy if exists kafana_sessions_select_all on public.kafana_sessions;
create policy kafana_sessions_select_all on public.kafana_sessions
  for select using (auth.role() = 'authenticated');

-- ── Trivia duel: tag rooms with their quiz type so the duel pages can
--    pull questions from the right pool. Existing rooms become 'pro'.
alter table public.game_rooms
  add column if not exists quiz_type text not null default 'pro';

create index if not exists game_rooms_quiz_type_idx
  on public.game_rooms (quiz_type);
