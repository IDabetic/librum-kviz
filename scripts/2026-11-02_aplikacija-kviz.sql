-- Aplikacija: kviz po temi (10 pitanja) za tok iz kita (detalji → spremi se → pitanja → rezultati).
-- p_fond: 'opste' ili 'book'; p_zanr: žanr Book pitanja (null = svi);
-- p_tezina: 'tesko' daje samo hard/impossible opšta pitanja.
-- SECURITY INVOKER: isti RLS kao direktno čitanje.

create or replace function public.aplikacija_kviz(p_fond text, p_zanr text default null, p_tezina text default null, p_broj int default 10)
returns table (id uuid, question_text text, options jsonb, correct_answer int, genre text)
language sql
stable
security invoker
set search_path = public
as $$
  select * from (
  select q.id, q.question_text, q.options, q.correct_answer::int, null::text
  from public.questions q
  where p_fond = 'opste' and q.is_active and jsonb_array_length(q.options) = 4
    and (p_tezina is distinct from 'tesko' or q.difficulty in ('hard', 'impossible'))
  union all
  select b.id, b.question_text, b.options, b.correct_answer::int, b.genre
  from public.book_questions b
  where p_fond = 'book' and b.is_active and jsonb_array_length(b.options) = 4
    and (p_zanr is null or b.genre = p_zanr)
  ) t
  order by random()
  limit least(greatest(p_broj, 1), 30);
$$;

grant execute on function public.aplikacija_kviz(text, text, text, int) to anon, authenticated;
