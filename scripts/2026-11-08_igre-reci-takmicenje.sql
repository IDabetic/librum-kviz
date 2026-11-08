-- Igre reči u „Igraj sa drugima” (08.11.2026): šest igara ulazi u postojeće sobe (takmicenja), svi u sobi igraju istu
-- zagonetku iz baze izazova (alati/igre_reci.py izazovi), po težini: lako / srednje (soba „normalno”) / teško.

alter table public.takmicenja drop constraint if exists takmicenja_igra_check;
alter table public.takmicenja add constraint takmicenja_igra_check check (igra in (
  'pro', 'book', 'slikari', 'brzi', 'vesanje', 'premetaljka', 'pet_slova', 'lanac', 'sifra', 'ukrstenica', 'zmija'));

create table if not exists public.igre_reci_izazovi (
  id serial primary key,
  igra text not null check (igra in ('premetaljka', 'pet_slova', 'lanac', 'sifra', 'ukrstenica', 'zmija')),
  tezina text not null check (tezina in ('lako', 'srednje', 'tesko')),
  podaci jsonb not null
);
-- nasumičan izbor po igri i težini
create index if not exists igre_reci_izazovi_igra on public.igre_reci_izazovi (igra, tezina);
alter table public.igre_reci_izazovi enable row level security;
revoke all on public.igre_reci_izazovi from anon, authenticated;

/**
 * Nasumična zagonetka za sobu. Težina sobe „normalno” je „srednje”.
 * Primer: select igre_reci_izazov('zmija', 'lako') → {"tema":"Voće",...,"tezina":"lako"}
 */
create or replace function public.igre_reci_izazov(p_igra text, p_tezina text) returns jsonb
language sql volatile security definer set search_path = public as $$
  select podaci from igre_reci_izazovi
  where igra = p_igra and tezina = case p_tezina when 'normalno' then 'srednje' else p_tezina end
  order by random() limit 1
$$;
revoke all on function public.igre_reci_izazov(text, text) from public;
grant execute on function public.igre_reci_izazov(text, text) to authenticated;

-- Uvoz baze izazova (posle push-a scripts/igre-reci/izazovi.json):
--   select net.http_get('https://raw.githubusercontent.com/IDabetic/librum-kviz/<commit>/scripts/igre-reci/izazovi.json');
--   truncate igre_reci_izazovi;
--   insert into igre_reci_izazovi (igra, tezina, podaci)
--   select g.key, t.key, z from net._http_response h, jsonb_each(h.content::jsonb) g, jsonb_each(g.value) t, jsonb_array_elements(t.value) z
--    where h.id = <id> and h.status_code = 200;
