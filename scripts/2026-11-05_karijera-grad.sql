-- Grad Karijere (05.11.2026), primenjeno kao migracije karijera_31_grad i karijera_32_grad_ime_korporacije.
-- Svaka firma ima parcelu: ulica = parcela / 7, mesto u ulici = parcela % 7. Korporacija je na parceli 3.
-- Zatvorene firme ostavljaju praznu parcelu (park). Pretraga po imenu ide preko trigram indeksa.
alter table public.karijera_firme add column if not exists parcela int;
alter table public.karijera_firme add column if not exists ime_trazi text;

update public.karijera_firme set parcela = 3 where korporacija;
with r as (select id, row_number() over (order by osnovana, id) as n from public.karijera_firme where not korporacija)
update public.karijera_firme f set parcela = case when r.n <= 3 then r.n - 1 else r.n end from r where f.id = r.id;

create sequence if not exists public.karijera_parcela_seq;
select setval('public.karijera_parcela_seq', (select coalesce(max(parcela), 3) from public.karijera_firme));
alter table public.karijera_firme alter column parcela set default nextval('public.karijera_parcela_seq');
create unique index if not exists karijera_firme_parcela_uq on public.karijera_firme (parcela);

create or replace function public.karijera_firme_ime_trazi() returns trigger
language plpgsql set search_path to 'public' as $$
begin
  new.ime_trazi := lower(coalesce(karijera_ime_firme(new), ''));
  return new;
end $$;
revoke all on function public.karijera_firme_ime_trazi() from public, anon, authenticated;
drop trigger if exists karijera_firme_ime_trazi on public.karijera_firme;
create trigger karijera_firme_ime_trazi before insert or update of ime, ime_prefiks, ime_oblik, pozicija on public.karijera_firme
  for each row execute function public.karijera_firme_ime_trazi();
update public.karijera_firme f set ime_trazi = lower(coalesce(karijera_ime_firme(f), ''));
create index if not exists karijera_firme_ime_trazi_trgm on public.karijera_firme using gin (ime_trazi gin_trgm_ops);

create or replace function public.karijera_balon(f public.karijera_firme) returns text
language sql stable security definer set search_path to 'public' as $$
  select case
    when f.korporacija then 'Probni rad'
    when exists (select 1 from karijera_izazovi z where z.firma_id = f.id and z.stanje in ('ceka', 'u_toku')) then 'Napadnuta!'
    when (select coalesce(sum(r.poeni), 0) from karijera_runde r where r.firma_id = f.id and r.dan = karijera_danas()) > 0
      then '+' || (select sum(r.poeni) from karijera_runde r where r.firma_id = f.id and r.dan = karijera_danas()) || ' poena'
    when (select count(*) from karijera_igraci i where i.firma_id = f.id) < 3 then 'Traži zaposlene'
    else null end
$$;
revoke all on function public.karijera_balon(public.karijera_firme) from public, anon, authenticated;

create or replace function public.karijera_grad(p_od int, p_do int) returns jsonb
language plpgsql stable security definer set search_path to 'public' as $$
declare od int := greatest(p_od, 0); doo int := least(p_do, greatest(p_od, 0) + 19);
begin
  if auth.uid() is null then raise exception 'Prijavi se da bi video grad.' using errcode = '42501'; end if;
  return jsonb_build_object(
    'ulica', (select coalesce(max(parcela), 0) / 7 + 1 from karijera_firme where not zatvorena),
    'firme', coalesce((select jsonb_agg(karijera_firma_red(f) || jsonb_build_object('parcela', f.parcela, 'balon', karijera_balon(f)) order by f.parcela)
                       from karijera_firme f where not f.zatvorena and f.parcela between od * 7 and doo * 7 + 6), '[]'::jsonb));
end $$;

create or replace function public.karijera_trazi_firmu(p_upit text) returns jsonb
language plpgsql stable security definer set search_path to 'public' as $$
declare q text := lower(btrim(coalesce(p_upit, '')));
begin
  if auth.uid() is null then raise exception 'Prijavi se.' using errcode = '42501'; end if;
  if char_length(q) < 2 then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('id', f.id, 'ime', case when f.korporacija then 'Korporacija' else karijera_ime_firme(f) end,
                              'parcela', f.parcela, 'nivo', f.nivo, 'stil', f.stil, 'korporacija', f.korporacija,
                              'vlasnik_ime', case when f.vlasnik is null then coalesce(f.npc_ime, 'Uprava') else karijera_nadimak(f.vlasnik) end) x
    from karijera_firme f where not f.zatvorena and f.ime_trazi ilike '%' || replace(replace(q, '%', ''), '_', '') || '%'
    order by similarity(f.ime_trazi, q) desc, f.nivo desc limit 20) s), '[]'::jsonb);
end $$;

revoke all on function public.karijera_grad(int, int), public.karijera_trazi_firmu(text) from public, anon;
grant execute on function public.karijera_grad(int, int), public.karijera_trazi_firmu(text) to authenticated;

-- karijera_33_stil_do_8: tabela je dozvoljavala samo stil 1–4, pa bi otvaranje firme sa novim zgradama puklo.
alter table public.karijera_firme drop constraint if exists karijera_firme_stil_check;
alter table public.karijera_firme add constraint karijera_firme_stil_check check (stil between 1 and 8);

-- karijera_34_balon_samo_igraci: „Traži zaposlene” samo za firme pravih igrača (NPC firme bez balončića).

-- karijera_35_grad_mapa: sve firme za izometrijsku mapu, po 500, keyset po parceli.

-- karijera_36/37: jedinstveno ime (ime_trazi), poruka 22023, karijera_odmor_povuci, odmor_do samo aktivan.
