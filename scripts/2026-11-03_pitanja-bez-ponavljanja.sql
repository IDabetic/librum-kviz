-- Pitanja se nigde ne ponavljaju (vlasnik 03.11.2026): ranije je 10% paketa bilo od pitanja viđenih pre više od 7 dana.
-- Sada idu samo neviđena; viđeno se vraća tek kad igrač potroši ceo fond te igre, i to najstarije prvo.
-- Viđeno = vidjena_pitanja (svaki paket koji je stigao na telefon) + question_answer_log (moja_vidjena()).
create or replace function public.aplikacija_pitanja(p_igra text, p_broj integer default 60)
returns table(id uuid, question_text text, options jsonb, correct_answer integer, genre text)
language sql security definer set search_path to 'public' as $function$
  with sve as (
    -- Tema (žanr) iz oznaka se računa tek za izabranih ≤ 80, ne za ceo fond (EXPLAIN: 526 ms → ispod 200 ms).
    select q.id, q.question_text, q.options, q.correct_answer::int as correct_answer, null::text as genre, q.tags
    from questions q where p_igra = 'opste' and q.is_active and jsonb_array_length(q.options) = 4
    union all
    select b.id, b.question_text, b.options, b.correct_answer::int, b.genre, null::text[]
    from book_questions b where p_igra = 'book' and b.is_active and jsonb_array_length(b.options) = 4
    union all
    select k.id, k.question_text, to_jsonb(k.options), k.correct_answer, null::text, null::text[]
    from kafana_questions k where p_igra = 'kafana' and k.is_active and array_length(k.options, 1) = 4
  ),
  izbor as (
    select s.* from sve s left join moja_vidjena() v on v.pitanje = s.id
    order by v.kad asc nulls first, random()
    limit least(greatest(p_broj, 1), 80)
  ),
  upis as (
    insert into vidjena_pitanja (user_id, pitanje, kad)
    select auth.uid(), i.id, now() from izbor i where auth.uid() is not null
    on conflict (user_id, pitanje) do update set kad = excluded.kad
  )
  select i.id, i.question_text, i.options, i.correct_answer,
         coalesce(i.genre, (select case t when 'film i tv' then 'Film i TV' else upper(left(t, 1)) || substr(t, 2) end
            from unnest(i.tags) with ordinality as x(t, n)
            where t in ('film i tv', 'muzika', 'geografija', 'jezik', 'sport', 'istorija', 'književnost', 'ličnosti', 'kultura',
                        'nauka', 'priroda', 'umetnost', 'religija i mitologija', 'hrana i piće', 'tehnika', 'tradicija')
            order by n limit 1))
  from izbor i;
$function$;

create or replace function public.aplikacija_kviz(p_fond text, p_zanr text default null, p_tezina text default null, p_broj integer default 10)
returns table(id uuid, question_text text, options jsonb, correct_answer integer, genre text)
language sql security definer set search_path to 'public' as $function$
  with sve as (
    select q.id, q.question_text, q.options, q.correct_answer::int as correct_answer, null::text as genre
    from questions q
    where p_fond = 'opste' and q.is_active and jsonb_array_length(q.options) = 4
      and (p_tezina is distinct from 'tesko' or q.difficulty in ('hard', 'impossible'))
      and (p_zanr is null or p_zanr = any(q.tags))
    union all
    select b.id, b.question_text, b.options, b.correct_answer::int, b.genre
    from book_questions b
    where p_fond = 'book' and b.is_active and jsonb_array_length(b.options) = 4 and (p_zanr is null or b.genre = p_zanr)
  ),
  izbor as (
    select s.* from sve s left join moja_vidjena() v on v.pitanje = s.id
    order by v.kad asc nulls first, random()
    limit least(greatest(p_broj, 1), 30)
  ),
  upis as (
    insert into vidjena_pitanja (user_id, pitanje, kad)
    select auth.uid(), i.id, now() from izbor i where auth.uid() is not null
    on conflict (user_id, pitanje) do update set kad = excluded.kad
  )
  select i.id, i.question_text, i.options, i.correct_answer, i.genre from izbor i;
$function$;
