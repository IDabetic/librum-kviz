-- Osvajanje: bitka za državu pita i o njenom kontinentu (vlasnik 03.11.2026, „raspoređena po kontinentima”).
-- Pitanja imaju oznaku kontinent:<ime> (uvoz Librum kontinenti); kao i opšti paket, samo neviđena, pa najstarija.
-- GIN indeks na oznakama: 141 ms → 4 ms (EXPLAIN ANALYZE, Okeanija, 20 pitanja).
create index if not exists questions_tags_gin on public.questions using gin (tags);

create or replace function public.aplikacija_pitanja_kontinent(p_kontinent text, p_broj integer default 20)
returns table(id uuid, question_text text, options jsonb, correct_answer integer, genre text)
language sql security definer set search_path to 'public' as $function$
  with izbor as (
    select q.id, q.question_text, q.options, q.correct_answer::int as correct_answer
    from questions q left join moja_vidjena() v on v.pitanje = q.id
    where q.tags @> array['kontinent:' || p_kontinent] and q.is_active and jsonb_array_length(q.options) = 4
    order by v.kad asc nulls first, random()
    limit least(greatest(p_broj, 1), 40)
  ),
  upis as (
    insert into vidjena_pitanja (user_id, pitanje, kad)
    select auth.uid(), i.id, now() from izbor i where auth.uid() is not null
    on conflict (user_id, pitanje) do update set kad = excluded.kad
  )
  select i.id, i.question_text, i.options, i.correct_answer, p_kontinent from izbor i;
$function$;
revoke all on function public.aplikacija_pitanja_kontinent(text, integer) from public;
grant execute on function public.aplikacija_pitanja_kontinent(text, integer) to anon, authenticated;
