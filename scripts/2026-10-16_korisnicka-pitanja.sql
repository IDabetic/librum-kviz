-- Korisnička pitanja + 3-dnevna suspenzija posle 2 prijave.
-- Pokrenuti jednom u Supabase SQL editoru. Aditivno: stari sajt i dalje radi.

alter table public.question_submissions
  add column if not exists wrong_answers text[] not null default '{}',
  add column if not exists segment text not null default 'pro',
  add column if not exists genre text,
  add column if not exists source text not null default 'form',
  add column if not exists status text not null default 'pending',
  add column if not exists reject_reason text,
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid,
  add column if not exists accepted_id uuid,
  add column if not exists accepted_table text;

alter table public.profiles
  add column if not exists suspended_until timestamptz;

alter table public.questions
  add column if not exists created_by uuid;
alter table public.book_questions
  add column if not exists created_by uuid;
alter table public.kafana_questions
  add column if not exists created_by uuid;

create unique index if not exists question_reports_user_question
  on public.question_reports (user_id, source, question_id)
  where user_id is not null;

create index if not exists question_submissions_author_status
  on public.question_submissions (submitted_by, status);

create or replace function public.prag_bedza()
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(trim((select value from public.admin_settings where key = 'prag_bedza')), '')::int,
    3
  );
$$;

grant execute on function public.prag_bedza() to anon, authenticated;

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
  coalesce(a.cnt, 0)::int as accepted,
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
left join (
  select submitted_by as user_id, count(*)::int as cnt
  from public.question_submissions
  where submitted_by is not null and status = 'accepted'
  group by submitted_by
) a on a.user_id = pp.id
where (coalesce(r.cnt, 0) + coalesce(s.cnt, 0)) > 0;

grant select on public.public_contributors to anon, authenticated;
