-- Igre reči (08.11.2026): šest dnevnih igara — Premetaljka, Pet slova, Lanac, Šifra, Mini ukrštenica, Zmija.
-- Zagonetke pravi alati/igre_reci.py (ista za sve igrače, po beogradskom danu); uvoz: kraj ovog fajla.
-- Odgovori su u zagonetki (igra radi i bez mreže posle učitavanja); rezultat za rang listu server sam ocenjuje.

create table if not exists public.igre_reci_zagonetke (
  igra text not null check (igra in ('premetaljka', 'pet_slova', 'lanac', 'sifra', 'ukrstenica', 'zmija')),
  datum date not null,
  podaci jsonb not null,
  primary key (igra, datum)
);

create table if not exists public.igre_reci_rezultati (
  korisnik uuid not null references auth.users(id) on delete cascade,
  igra text not null,
  datum date not null,
  resio boolean not null,
  poeni integer not null check (poeni between 0 and 1000),
  sekundi integer not null check (sekundi between 0 and 86400),
  pomoci integer not null default 0 check (pomoci between 0 and 50),
  created_at timestamptz not null default now(),
  primary key (korisnik, igra, datum),
  foreign key (igra, datum) references public.igre_reci_zagonetke (igra, datum)
);
-- rang lista dana: where igra, datum order by resio, poeni, sekundi
create index if not exists igre_reci_rezultati_rang on public.igre_reci_rezultati (igra, datum, resio desc, poeni desc, sekundi);

alter table public.igre_reci_zagonetke enable row level security;
alter table public.igre_reci_rezultati enable row level security;
revoke all on public.igre_reci_zagonetke, public.igre_reci_rezultati from anon, authenticated;

create or replace function public.igre_reci_danas() returns date
language sql stable set search_path = public as $$ select (now() at time zone 'Europe/Belgrade')::date $$;

/** Primer: igre_reci_jedno_slovo('kosa', 'kasa') → true. */
create or replace function public.igre_reci_jedno_slovo(a text, b text) returns boolean
language sql immutable set search_path = public as $$
  select length(a) = length(b)
     and (select count(*) from generate_series(1, length(a)) i where substr(a, i, 1) <> substr(b, i, 1)) = 1
$$;

/**
 * Zagonetke dana za svih šest igara + moj rezultat i niz rešenih dana po igri.
 * Primer: select igre_reci_dan(null) → {"datum":"2026-11-09","igre":{...},"moji":{"zmija":{"resio":true,...}},"nizovi":{"zmija":3}}
 * Budući dani se ne daju; prošlih 7 dana mogu da se igraju bez rang liste.
 */
create or replace function public.igre_reci_dan(p_datum date default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_danas date := igre_reci_danas();
  v_datum date := coalesce(p_datum, v_danas);
  v_ja uuid := auth.uid();
  v_nizovi jsonb := '{}';
  v_igra text;
  v_niz int;
  v_d date;
begin
  if v_datum > v_danas or v_datum < v_danas - 7 then
    raise exception 'Taj dan nije dostupan.' using errcode = '22023';
  end if;
  if v_ja is not null then
    foreach v_igra in array array['premetaljka', 'pet_slova', 'lanac', 'sifra', 'ukrstenica', 'zmija'] loop
      -- niz traje dok je juče rešeno, i kad danas još nije igrano
      v_d := v_danas;
      if not exists (select 1 from igre_reci_rezultati where korisnik = v_ja and igra = v_igra and datum = v_d and resio) then
        v_d := v_d - 1;
      end if;
      v_niz := 0;
      while exists (select 1 from igre_reci_rezultati where korisnik = v_ja and igra = v_igra and datum = v_d and resio) loop
        v_niz := v_niz + 1;
        v_d := v_d - 1;
      end loop;
      v_nizovi := v_nizovi || jsonb_build_object(v_igra, v_niz);
    end loop;
  end if;
  return jsonb_build_object(
    'datum', v_datum,
    'igre', coalesce((select jsonb_object_agg(igra, podaci) from igre_reci_zagonetke where datum = v_datum), '{}'),
    'moji', coalesce((select jsonb_object_agg(igra, jsonb_build_object('resio', resio, 'poeni', poeni, 'sekundi', sekundi, 'pomoci', pomoci))
                      from igre_reci_rezultati where korisnik = v_ja and datum = v_datum), '{}'),
    'nizovi', v_nizovi
  );
end $$;

/**
 * Upisuje prvi rezultat igrača za igru i dan (ponovljena igra se ne broji) i vraća mesto na rang listi.
 * p_odgovor po igri: premetaljka {"reci":[..]}, pet_slova {"pokusaji":[..]}, lanac {"put":[..]},
 * sifra {"kljuc":{"1":"a",..}}, ukrstenica {"reci":[..] redom kao u zagonetki}, zmija {"reci":[..]}.
 * Primer: select igre_reci_zavrsi('pet_slova', '2026-11-09', '{"pokusaji":["kuća","tetka"]}', 74, 0)
 */
create or replace function public.igre_reci_zavrsi(p_igra text, p_datum date, p_odgovor jsonb, p_sekundi int, p_pomoci int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_ja uuid := auth.uid();
  v_danas date := igre_reci_danas();
  z jsonb;
  v_resio boolean := false;
  v_poeni int := 0;
  v_reci text[];
  v_put text[];
  v_n int;
  v_mesto int;
  v_ukupno int;
begin
  if v_ja is null then raise exception 'Prijavi se da bi rezultat ušao na rang listu.' using errcode = '28000'; end if;
  if p_datum not between v_danas - 1 and v_danas then raise exception 'Rang lista prima samo današnju igru.' using errcode = '22023'; end if;
  select podaci into z from igre_reci_zagonetke where igra = p_igra and datum = p_datum;
  if z is null then raise exception 'Nema zagonetke za taj dan.' using errcode = 'P0002'; end if;
  p_sekundi := least(greatest(coalesce(p_sekundi, 0), 0), 86400);
  p_pomoci := least(greatest(coalesce(p_pomoci, 0), 0), 50);

  if p_igra = 'premetaljka' then
    select array_agg(distinct r) into v_reci
      from jsonb_array_elements_text(coalesce(p_odgovor -> 'reci', '[]')) r
     where z -> 'reci' ? r;
    v_reci := coalesce(v_reci, '{}');
    v_resio := (z ->> 'glavna') = any (v_reci);
    select coalesce(sum(case when r = z ->> 'glavna' then 15 else length(r) - 2 end), 0) into v_poeni from unnest(v_reci) r;
  elsif p_igra = 'pet_slova' then
    select array_agg(lower(r) order by o) into v_put from jsonb_array_elements_text(coalesce(p_odgovor -> 'pokusaji', '[]')) with ordinality t(r, o);
    v_n := coalesce(array_length(v_put, 1), 0);
    v_resio := v_n between 1 and 6 and v_put[v_n] = z ->> 'rec' and (select bool_and(length(r) = 5) from unnest(v_put) r);
    v_poeni := case when v_resio then (7 - v_n) * 10 else 0 end;
  elsif p_igra = 'lanac' then
    select array_agg(lower(r) order by o) into v_put from jsonb_array_elements_text(coalesce(p_odgovor -> 'put', '[]')) with ordinality t(r, o);
    v_n := coalesce(array_length(v_put, 1), 0);
    -- shortcut: postojanje reči proverava app (rečnik u paketu); server proverava krajeve i korake
    v_resio := v_n between 2 and 30 and v_put[1] = z ->> 'od' and v_put[v_n] = z ->> 'do'
           and (select bool_and(igre_reci_jedno_slovo(v_put[i], v_put[i + 1])) from generate_series(1, v_n - 1) i);
    v_poeni := case when v_resio then greatest(10, 60 - (v_n - 1 - (z ->> 'najmanje')::int) * 10) else 0 end;
  elsif p_igra = 'sifra' then
    v_resio := not exists (select 1 from jsonb_each_text(z -> 'kljuc') k where (p_odgovor -> 'kljuc' ->> k.key) is distinct from k.value);
    v_poeni := case when v_resio then 50 else 0 end;
  elsif p_igra = 'ukrstenica' then
    v_resio := jsonb_array_length(coalesce(p_odgovor -> 'reci', '[]')) = jsonb_array_length(z -> 'reci')
           and not exists (select 1 from jsonb_array_elements(z -> 'reci') with ordinality t(r, o)
                            where lower(p_odgovor -> 'reci' ->> (o - 1)::int) is distinct from r ->> 'rec');
    v_poeni := case when v_resio then 50 else 0 end;
  elsif p_igra = 'zmija' then
    v_resio := (select array_agg(r ->> 'rec' order by r ->> 'rec') from jsonb_array_elements(z -> 'reci') r)
             = (select array_agg(distinct lower(r) order by lower(r)) from jsonb_array_elements_text(coalesce(p_odgovor -> 'reci', '[]')) r);
    v_poeni := case when v_resio then 50 else 0 end;
  end if;

  v_resio := coalesce(v_resio, false);
  -- svaka pomoć skida 5 poena (rešeno ostaje rešeno)
  v_poeni := least(1000, greatest(0, v_poeni - 5 * p_pomoci));
  insert into igre_reci_rezultati (korisnik, igra, datum, resio, poeni, sekundi, pomoci)
  values (v_ja, p_igra, p_datum, v_resio, v_poeni, p_sekundi, p_pomoci)
  on conflict (korisnik, igra, datum) do nothing;

  select r.resio, r.poeni, r.sekundi into v_resio, v_poeni, p_sekundi from igre_reci_rezultati r
   where korisnik = v_ja and igra = p_igra and datum = p_datum;
  select count(*) + 1 into v_mesto from igre_reci_rezultati r
   where igra = p_igra and datum = p_datum
     and (r.resio::int, r.poeni, -r.sekundi) > (v_resio::int, v_poeni, -p_sekundi);
  select count(*) into v_ukupno from igre_reci_rezultati where igra = p_igra and datum = p_datum;
  return jsonb_build_object('resio', v_resio, 'poeni', v_poeni, 'sekundi', p_sekundi, 'mesto', v_mesto, 'ukupno', v_ukupno);
end $$;

/** Prvih 20 za igru i dan. Primer: select igre_reci_rang('zmija', null) */
create or replace function public.igre_reci_rang(p_igra text, p_datum date default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(red order by (red ->> 'mesto')::int), '[]') from (
    select jsonb_build_object(
      'mesto', (row_number() over (order by r.resio desc, r.poeni desc, r.sekundi))::int,
      'id', r.korisnik, 'ime', coalesce(nullif(p.nickname, ''), nullif(p.first_name, ''), 'Igrač'), 'avatar', p.avatar,
      'resio', r.resio, 'poeni', r.poeni, 'sekundi', r.sekundi) red
    from igre_reci_rezultati r left join public_profiles p on p.id = r.korisnik
    where r.igra = p_igra and r.datum = coalesce(p_datum, igre_reci_danas())
    order by r.resio desc, r.poeni desc, r.sekundi
    limit 20
  ) t
$$;

revoke all on function public.igre_reci_dan(date), public.igre_reci_rang(text, date),
  public.igre_reci_zavrsi(text, date, jsonb, int, int), public.igre_reci_jedno_slovo(text, text), public.igre_reci_danas() from public;
grant execute on function public.igre_reci_dan(date), public.igre_reci_rang(text, date) to anon, authenticated;
grant execute on function public.igre_reci_zavrsi(text, date, jsonb, int, int) to authenticated;

-- Uvoz zagonetki (posle push-a grane sa scripts/igre-reci/zagonetke.json), dva koraka zbog pg_net:
--   select net.http_get('https://raw.githubusercontent.com/IDabetic/librum-kviz/<grana>/scripts/igre-reci/zagonetke.json');
--   insert into igre_reci_zagonetke (igra, datum, podaci)
--   select g.key, d.key::date, g.value from net._http_response h, jsonb_each(h.content::jsonb) d, jsonb_each(d.value) g
--    where h.id = <id iz prvog koraka> and h.status_code = 200
--   on conflict (igra, datum) do update set podaci = excluded.podaci
--    where not exists (select 1 from igre_reci_rezultati r where r.igra = excluded.igra and r.datum = excluded.datum);
