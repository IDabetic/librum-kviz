-- Jedna tabela rezultata za svih 7 igara u aplikaciji + rang liste po periodu i javni profil.
-- Vlasnik 02.11: rang lista po igri dnevna/nedeljna/mesečna/godišnja, godišnja se resetuje
-- na kraju godine (period „godina” = tekuća kalendarska godina po beogradskom vremenu),
-- javni profil sa avatarom i prosečnom brzinom odgovora.
-- shortcut: poene računa telefon; serversko bodovanje je u docs/PREDLOZI-IGRE-TAKMICENJA.md (deo 4).

create table if not exists public.rezultati_igara (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  igra text not null check (igra in ('osvajanje', 'pro', 'book', 'duel', 'slikari', 'brzi', 'vesanje', 'tema')),
  poeni integer not null check (poeni between 0 and 100000),
  tacnih integer not null default 0 check (tacnih between 0 and 10000),
  netacnih integer not null default 0 check (netacnih between 0 and 10000),
  prosek_ms integer check (prosek_ms between 0 and 120000),
  created_at timestamptz not null default now()
);

create index if not exists rezultati_igara_igra_vreme on public.rezultati_igara (igra, created_at desc);
create index if not exists rezultati_igara_korisnik on public.rezultati_igara (user_id, created_at desc);

alter table public.rezultati_igara enable row level security;
drop policy if exists "upis sopstvenog rezultata" on public.rezultati_igara;
create policy "upis sopstvenog rezultata" on public.rezultati_igara for insert to authenticated
  with check ((select auth.uid()) = user_id);
-- Čitanje samo kroz RPC ispod (rang liste i profil), ne direktno iz tabele.

-- Početak perioda po beogradskom vremenu: dan, nedelja (od ponedeljka), mesec, godina.
create or replace function public.pocetak_perioda(p_period text)
returns timestamptz
language sql
stable
set search_path = public
as $$
  select (date_trunc(case p_period when 'dan' then 'day' when 'nedelja' then 'week' when 'mesec' then 'month' else 'year' end,
                     now() at time zone 'Europe/Belgrade')) at time zone 'Europe/Belgrade';
$$;

-- Rang lista igre za period: najbolji rezultat po igraču, uz broj partija i prosečnu brzinu.
create or replace function public.rang_lista_igre(p_igra text, p_period text, p_broj int default 50)
returns table (mesto bigint, user_id uuid, nadimak text, avatar text, poeni int, partija bigint, prosek_ms int)
language sql
stable
security definer
set search_path = public
as $$
  with r as (
    select r.user_id, max(r.poeni) as poeni, count(*) as partija, avg(r.prosek_ms)::int as prosek_ms
    from public.rezultati_igara r
    where r.igra = p_igra and r.created_at >= public.pocetak_perioda(p_period)
    group by r.user_id
  )
  select rank() over (order by r.poeni desc, r.prosek_ms asc nulls last), r.user_id,
         coalesce(p.nickname, p.first_name, 'Igrač'), p.avatar, r.poeni, r.partija, r.prosek_ms
  from r left join public.public_profiles p on p.id = r.user_id
  order by 1
  limit least(greatest(p_broj, 1), 100);
$$;

-- Mesto prijavljenog igrača u istoj listi (i kad nije među prvih 100).
create or replace function public.moje_mesto_igre(p_igra text, p_period text)
returns table (mesto bigint, poeni int, partija bigint, prosek_ms int, ukupno bigint)
language sql
stable
security definer
set search_path = public
as $$
  with r as (
    select r.user_id, max(r.poeni) as poeni, count(*) as partija, avg(r.prosek_ms)::int as prosek_ms
    from public.rezultati_igara r
    where r.igra = p_igra and r.created_at >= public.pocetak_perioda(p_period)
    group by r.user_id
  ), rangirano as (
    select r.*, rank() over (order by r.poeni desc, r.prosek_ms asc nulls last) as mesto, count(*) over () as ukupno from r
  )
  select mesto, poeni, partija, prosek_ms, ukupno from rangirano where user_id = (select auth.uid());
$$;

-- Javni profil igrača: ime, avatar, od kada igra i statistika po igri (bez ličnih podataka).
create or replace function public.profil_igraca(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', p.id,
    'nadimak', coalesce(p.nickname, p.first_name, 'Igrač'),
    'avatar', p.avatar,
    'od', p.created_at,
    'igre', coalesce((
      select jsonb_agg(jsonb_build_object(
        'igra', g.igra, 'partija', g.partija, 'najbolje', g.najbolje, 'prosek_ms', g.prosek_ms,
        'tacnost', case when g.odgovora > 0 then round(g.tacnih * 100.0 / g.odgovora) end) order by g.partija desc)
      from (
        select igra, count(*) as partija, max(poeni) as najbolje, avg(prosek_ms)::int as prosek_ms,
               sum(tacnih) as tacnih, sum(tacnih + netacnih) as odgovora
        from public.rezultati_igara where user_id = p.id group by igra
      ) g), '[]'::jsonb)
  )
  from public.public_profiles p where p.id = p_id;
$$;

revoke all on function public.rang_lista_igre(text, text, int) from public;
revoke all on function public.moje_mesto_igre(text, text) from public;
revoke all on function public.profil_igraca(uuid) from public;
grant execute on function public.rang_lista_igre(text, text, int) to anon, authenticated;
grant execute on function public.moje_mesto_igre(text, text) to authenticated;
grant execute on function public.profil_igraca(uuid) to anon, authenticated;
grant execute on function public.pocetak_perioda(text) to anon, authenticated;

-- Dopuna isti dan: koja pomoć je korišćena u partiji (za „koliko često i koju pomoć” na profilu).
alter table public.rezultati_igara add column if not exists pomoc text
  check (pomoc in ('polaPola', 'nagovestaj', 'vreme', 'preskok', 'slovo'));
-- profil_igraca je zamenjen verzijom koja vraća i 'sa_pomoci' po igri i 'pomoci' po vrsti
-- (tekst funkcije je u migraciji rezultati_igara_pomoc u Supabase).
