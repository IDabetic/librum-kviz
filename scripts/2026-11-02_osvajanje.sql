-- Osvajanje sveta: nasumičan paket pitanja za jednu partiju.
-- Zašto RPC: ostale igre povlače i do 1200 redova na početku partije, što je
-- glavni izvor izlaznog saobraćaja (projekat je 02.11.2026 blokiran zbog
-- exceed_egress_quota). Ovde baza bira nasumično i vraća samo potrebno.
-- SECURITY INVOKER: važi isti RLS kao za direktno čitanje `questions`.

create or replace function public.osvajanje_pitanja(p_broj int default 60)
returns table (id uuid, question_text text, options jsonb, correct_answer int)
language sql
stable
security invoker
set search_path = public
as $$
  select q.id, q.question_text, q.options, q.correct_answer
  from public.questions q
  where q.is_active
    and jsonb_typeof(q.options) = 'array'
    and jsonb_array_length(q.options) = 4
  order by random()
  limit least(greatest(p_broj, 1), 80);
$$;

grant execute on function public.osvajanje_pitanja(int) to anon, authenticated;
