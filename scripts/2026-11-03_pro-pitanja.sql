-- PRO kviz na vebu: server bira p_broj pitanja (retke težine + srednja, prvo neviđena u 72 h). PRIMENJENO 03.11.
create index if not exists question_answer_log_user_vreme on public.question_answer_log (user_id, created_at desc);
create or replace function public.pro_pitanja(p_broj int default 300)
returns table (id uuid, question_text text, options jsonb, correct_answer int, difficulty text, info text)
language sql volatile security definer set search_path to 'public' as $$
  with videno as (
    select distinct question_id from question_answer_log
    where user_id = auth.uid() and created_at > now() - interval '72 hours'
  )
  select q.id, q.question_text, q.options, q.correct_answer, q.difficulty, q.info
  from questions q left join videno v on v.question_id = q.id
  where q.is_active
  order by (q.difficulty = 'medium'), (v.question_id is not null), random()
  limit least(greatest(p_broj, 50), 600);
$$;
grant execute on function public.pro_pitanja(int) to authenticated;
