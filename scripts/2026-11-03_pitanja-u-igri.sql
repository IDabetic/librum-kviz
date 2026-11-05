-- Broj aktivnih pitanja po igrama za početni ekran app („pitanja u igri”), vlasnik 03.11.2026.
-- App ga čita na ulazu i osvežava dok je početna otvorena, pa svaki uvoz odmah menja broj.
-- Sajt (src/app/page.tsx) koristi staru broj_pitanja() koja vraća jedan broj; ta ostaje.
create or replace function public.pitanja_u_igri()
returns json language sql stable security definer set search_path to 'public' as $$
  select json_build_object(
    'kviz', (select count(*) from questions where is_active),
    'knjige', (select count(*) from book_questions where is_active),
    'kafana', (select count(*) from kafana_questions where is_active)
  );
$$;
revoke all on function public.pitanja_u_igri() from public;
grant execute on function public.pitanja_u_igri() to anon, authenticated;
