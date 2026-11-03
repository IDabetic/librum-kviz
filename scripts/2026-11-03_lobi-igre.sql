-- Lobi igre (03.11.2026, vlasnik): pre svake igre vidi se koliko je igrača igralo, ko je prvi, ko igra sada.
-- „Igra sada” = ulaz u igru u poslednjih 5 minuta (aplikacija javlja `u_igri` na ulazu i svaki minut).

create table if not exists public.u_igri (
  user_id uuid primary key references auth.users (id) on delete cascade,
  igra text not null,
  kad timestamptz not null default now()
);
alter table public.u_igri enable row level security;
create index if not exists u_igri_igra_kad on public.u_igri (igra, kad desc);
create index if not exists rezultati_igara_igra_poeni on public.rezultati_igara (igra, poeni desc);

-- Prijavljen igrač javlja da je u igri (jedan red po igraču, poslednja igra).
create or replace function public.javi_u_igri(p_igra text)
returns void language sql security definer set search_path to 'public' as $$
  insert into u_igri (user_id, igra, kad) select auth.uid(), left(p_igra, 40), now() where auth.uid() is not null
  on conflict (user_id) do update set igra = excluded.igra, kad = excluded.kad;
$$;

-- Brojke za lobi: ukupno igrača, partija danas, igra sada, najbolji ikada i moj rekord i mesto.
create or replace function public.lobi_igre(p_igra text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  -- Aplikacija (rezultati_igara) + istorija sa sajta (survivor/book/quick/hangman_sessions), da lobi ne krene od nule.
  with sve as (
    select r.user_id, r.poeni, r.created_at from rezultati_igara r where r.igra = p_igra
    union all select s.user_id, s.score, s.created_at from survivor_sessions s where p_igra = 'pro'
    union all select s.user_id, s.score, s.created_at from book_sessions s where p_igra = 'book'
    union all select s.user_id, s.score, s.created_at from quick_sessions s where p_igra = 'brzi'
    union all select s.user_id, s.score, s.created_at from hangman_sessions s where p_igra = 'vesanje'
  ),
  naj as (select user_id, max(poeni) poeni from sve where user_id is not null group by user_id),
  prvi as (
    select n.user_id, n.poeni, coalesce(nullif(p.nickname, ''), nullif(p.first_name, ''), 'Igrač') nadimak, p.avatar
    from naj n left join profiles p on p.id = n.user_id order by n.poeni desc limit 1
  ),
  moj as (select poeni from naj where user_id = auth.uid())
  select jsonb_build_object(
    'igraca', (select count(*) from naj),
    'partija_danas', (select count(*) from sve where created_at > date_trunc('day', now() at time zone 'Europe/Belgrade') at time zone 'Europe/Belgrade'),
    'igra_sada', (select count(*) from u_igri where igra = p_igra and kad > now() - interval '5 minutes'),
    'prvi', (select jsonb_build_object('id', user_id, 'nadimak', nadimak, 'avatar', avatar, 'poeni', poeni) from prvi),
    'moj_rekord', (select poeni from moj),
    'moje_mesto', case when exists (select 1 from moj) then (select count(*) + 1 from naj where poeni > (select poeni from moj)) end
  );
$$;

revoke all on function public.javi_u_igri(text) from public, anon;
grant execute on function public.javi_u_igri(text) to authenticated;
grant execute on function public.lobi_igre(text) to anon, authenticated;
