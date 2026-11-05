-- Osvajanje: napadač bira temu pitanja (vlasnik 03.11.2026). Pitanja opšteg znanja dobijaju temu iz oznake
-- kategorije (prva poznata oznaka, veliko početno slovo); ranije je genre bio null. Ostalo isto kao 2026-11-03_vidjena-pitanja.sql.

create or replace function public.aplikacija_pitanja(p_igra text, p_broj integer default 60)
returns table(id uuid, question_text text, options jsonb, correct_answer integer, genre text)
language sql security definer set search_path to 'public' as $function$
  with sve as (
    select q.id, q.question_text, q.options, q.correct_answer::int as correct_answer,
           (select case t when 'film i tv' then 'Film i TV' else upper(left(t, 1)) || substr(t, 2) end from unnest(q.tags) with ordinality as x(t, i)
            where t in ('film i tv', 'muzika', 'geografija', 'jezik', 'sport', 'istorija', 'književnost', 'ličnosti', 'kultura',
                        'nauka', 'priroda', 'umetnost', 'religija i mitologija', 'hrana i piće', 'tehnika', 'tradicija')
            order by i limit 1) as genre
    from questions q where p_igra = 'opste' and q.is_active and jsonb_array_length(q.options) = 4
    union all
    select b.id, b.question_text, b.options, b.correct_answer::int, b.genre
    from book_questions b where p_igra = 'book' and b.is_active and jsonb_array_length(b.options) = 4
    union all
    select k.id, k.question_text, to_jsonb(k.options), k.correct_answer, null::text
    from kafana_questions k where p_igra = 'kafana' and k.is_active and array_length(k.options, 1) = 4
  ),
  n as (select least(greatest(p_broj, 1), 80) as broj),
  vidjeno as (select * from moja_vidjena()),
  rang as (
    select s.*, g.grupa, row_number() over (partition by g.grupa order by random()) as rb
    from sve s left join vidjeno v on v.pitanje = s.id
    cross join lateral (select case when v.kad is null then 0 when v.kad < now() - interval '7 days' then 1 else 2 end as grupa) g
  ),
  izbor as (
    select r.* from rang r, n
    order by case when r.grupa = 0 or (r.grupa = 1 and r.rb <= ceil(n.broj * 0.1)) then 0 else r.grupa end, random()
    limit (select broj from n)
  ),
  upis as (
    insert into vidjena_pitanja (user_id, pitanje, kad)
    select auth.uid(), i.id, now() from izbor i where auth.uid() is not null
    on conflict (user_id, pitanje) do update set kad = excluded.kad
  )
  select i.id, i.question_text, i.options, i.correct_answer, i.genre from izbor i;
$function$;
