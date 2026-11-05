-- Praćenje igrača, izazovi sa profila, tokeni za obaveštenja (Firebase) i pretraga igrača.
-- Primenjeno 02.11.2026 (Supabase migracije pracenje_izazovi i public_profiles_nickname_trgm).

create table if not exists public.pracenja (
  ko uuid not null references auth.users(id) on delete cascade,
  koga uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (ko, koga),
  check (ko <> koga)
);
create index if not exists pracenja_koga on public.pracenja (koga);
alter table public.pracenja enable row level security;
drop policy if exists "pracenja citanje" on public.pracenja;
create policy "pracenja citanje" on public.pracenja for select to authenticated using (true);
drop policy if exists "pracenja upis" on public.pracenja;
create policy "pracenja upis" on public.pracenja for insert to authenticated with check ((select auth.uid()) = ko);
drop policy if exists "pracenja brisanje" on public.pracenja;
create policy "pracenja brisanje" on public.pracenja for delete to authenticated using ((select auth.uid()) = ko);

create table if not exists public.izazovi (
  id bigint generated always as identity primary key,
  od uuid not null references auth.users(id) on delete cascade,
  za uuid not null references auth.users(id) on delete cascade,
  igra text not null default 'duel' check (igra in ('duel', 'osvajanje')),
  kod_sobe text,
  status text not null default 'ceka' check (status in ('ceka', 'prihvacen', 'odbijen', 'istekao')),
  created_at timestamptz not null default now(),
  check (od <> za)
);
create index if not exists izazovi_za on public.izazovi (za, status, created_at desc);
alter table public.izazovi enable row level security;
drop policy if exists "izazovi svoji" on public.izazovi;
create policy "izazovi svoji" on public.izazovi for select to authenticated using ((select auth.uid()) in (od, za));
drop policy if exists "izazovi slanje" on public.izazovi;
create policy "izazovi slanje" on public.izazovi for insert to authenticated with check ((select auth.uid()) = od);
drop policy if exists "izazovi odgovor" on public.izazovi;
create policy "izazovi odgovor" on public.izazovi for update to authenticated using ((select auth.uid()) = za) with check ((select auth.uid()) = za);

create table if not exists public.push_tokeni (
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platforma text not null check (platforma in ('ios', 'android')),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);
alter table public.push_tokeni enable row level security;
drop policy if exists "push svoji" on public.push_tokeni;
create policy "push svoji" on public.push_tokeni for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Pretraga igrača po nadimku: prefiks ili trigram sličnost (indeks ispod), bez LIKE '%…%'.
create extension if not exists pg_trgm;
create index if not exists public_profiles_nickname_trgm on public.public_profiles using gin (nickname gin_trgm_ops);

create or replace function public.trazi_igrace(p_upit text, p_broj int default 20)
returns table (id uuid, nadimak text, avatar text, pratim boolean, prati_mene boolean)
language sql stable security definer set search_path = public as $$
  select p.id, coalesce(p.nickname, p.first_name, 'Igrač'), p.avatar,
         exists (select 1 from public.pracenja f where f.ko = (select auth.uid()) and f.koga = p.id),
         exists (select 1 from public.pracenja f where f.koga = (select auth.uid()) and f.ko = p.id)
  from public.public_profiles p
  where length(trim(p_upit)) >= 2 and p.id <> coalesce((select auth.uid()), '00000000-0000-0000-0000-000000000000')
    and (p.nickname ilike p_upit || '%' or similarity(coalesce(p.nickname, ''), p_upit) > 0.3)
  order by (p.nickname ilike p_upit || '%') desc, similarity(coalesce(p.nickname, ''), p_upit) desc
  limit least(greatest(p_broj, 1), 50);
$$;

create or replace function public.moja_pracenja()
returns table (id uuid, nadimak text, avatar text, pratim boolean, prati_mene boolean)
language sql stable security definer set search_path = public as $$
  select p.id, coalesce(p.nickname, p.first_name, 'Igrač'), p.avatar,
         exists (select 1 from public.pracenja f where f.ko = (select auth.uid()) and f.koga = p.id),
         exists (select 1 from public.pracenja f where f.koga = (select auth.uid()) and f.ko = p.id)
  from public.public_profiles p
  where p.id in (select koga from public.pracenja where ko = (select auth.uid())
                 union select ko from public.pracenja where koga = (select auth.uid()))
  order by 2;
$$;

create or replace function public.broj_pratilaca(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'pratilaca', (select count(*) from public.pracenja where koga = p_id),
    'prati', (select count(*) from public.pracenja where ko = p_id),
    'pratim', exists (select 1 from public.pracenja where ko = (select auth.uid()) and koga = p_id));
$$;

revoke all on function public.trazi_igrace(text, int) from public;
revoke all on function public.moja_pracenja() from public;
revoke all on function public.broj_pratilaca(uuid) from public;
grant execute on function public.trazi_igrace(text, int) to authenticated;
grant execute on function public.moja_pracenja() to authenticated;
grant execute on function public.broj_pratilaca(uuid) to anon, authenticated;
