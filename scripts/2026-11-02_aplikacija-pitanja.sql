-- Aplikacija: jedan nasumičan paket po igri umesto povlačenja cele tabele.
-- SECURITY INVOKER: važi isti RLS kao za direktno čitanje (kafana samo prijavljenima).
-- p_igra: 'opste' (PRO, Brzi, Duel), 'book', 'kafana'.

create or replace function public.aplikacija_pitanja(p_igra text, p_broj int default 60)
returns table (id uuid, question_text text, options jsonb, correct_answer int, genre text)
language sql
stable
security invoker
set search_path = public
as $$
  select q.id, q.question_text, q.options, q.correct_answer::int, null::text
  from public.questions q
  where p_igra = 'opste' and q.is_active and jsonb_array_length(q.options) = 4
  union all
  select b.id, b.question_text, b.options, b.correct_answer::int, b.genre
  from public.book_questions b
  where p_igra = 'book' and b.is_active and jsonb_array_length(b.options) = 4
  union all
  select k.id, k.question_text, to_jsonb(k.options), k.correct_answer, null::text
  from public.kafana_questions k
  where p_igra = 'kafana' and k.is_active and array_length(k.options, 1) = 4
  order by random()
  limit least(greatest(p_broj, 1), 80);
$$;

create or replace function public.aplikacija_reci(p_broj int default 40)
returns table (id uuid, word text, hint text, category text)
language sql
stable
security invoker
set search_path = public
as $$
  select w.id, w.word, w.hint, w.category
  from public.hangman_words w
  where w.is_active
  order by random()
  limit least(greatest(p_broj, 1), 80);
$$;

-- Pitanja duela po id-jevima sobe, sa istim RLS-om.
create or replace function public.aplikacija_pitanja_po_id(p_igra text, p_ids uuid[])
returns table (id uuid, question_text text, options jsonb, correct_answer int)
language sql
stable
security invoker
set search_path = public
as $$
  select q.id, q.question_text, q.options, q.correct_answer from public.questions q where p_igra <> 'kafana' and q.id = any(p_ids)
  union all
  select k.id, k.question_text, to_jsonb(k.options), k.correct_answer from public.kafana_questions k where p_igra = 'kafana' and k.id = any(p_ids);
$$;

grant execute on function public.aplikacija_pitanja(text, int) to anon, authenticated;
grant execute on function public.aplikacija_reci(int) to anon, authenticated;
grant execute on function public.aplikacija_pitanja_po_id(text, uuid[]) to authenticated;
