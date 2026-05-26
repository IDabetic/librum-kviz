-- ─────────────────────────────────────────────────────────────────
-- public.public_contributors view
-- ─────────────────────────────────────────────────────────────────
-- Run once in Supabase SQL Editor.
--
-- Aggregates per-user counts from question_reports + question_submissions
-- and joins with the safe public_profiles view so the front-end can show
-- a "Doprinos kvizu" leaderboard without exposing the underlying tables
-- (which have RLS for admins only).
--
-- SECURITY DEFINER view → bypasses RLS on the source tables. Only the
-- aggregated counts and display-safe profile fields leak out — never
-- individual report reasons, question texts, or user emails.
-- ─────────────────────────────────────────────────────────────────

create or replace view public.public_contributors
with (security_invoker = false) as
select
  pp.id,
  pp.first_name,
  pp.last_name,
  pp.nickname,
  pp.avatar,
  coalesce(r.cnt, 0)::int as reports,
  coalesce(s.cnt, 0)::int as submissions,
  (coalesce(r.cnt, 0) + coalesce(s.cnt, 0))::int as total_contributions
from public.public_profiles pp
left join (
  select user_id, count(*)::int as cnt
  from public.question_reports
  where user_id is not null
  group by user_id
) r on r.user_id = pp.id
left join (
  select submitted_by as user_id, count(*)::int as cnt
  from public.question_submissions
  where submitted_by is not null
  group by submitted_by
) s on s.user_id = pp.id
where (coalesce(r.cnt, 0) + coalesce(s.cnt, 0)) > 0;

grant select on public.public_contributors to anon, authenticated;

-- Sanity check:
--   select * from public.public_contributors order by total_contributions desc limit 10;
