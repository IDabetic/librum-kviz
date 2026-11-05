-- Karijera, ispravke posle prve probe (primenjeno 04.11.2026. posle 2026-11-04_karijera.sql).
-- 1) karijera_izvuci: tema se računa tek za izabranih 10, opšti deo iz uzorka (tablesample):
--    pun prolaz kroz 157.000 pitanja trajao je 2,5 s, sada runda kreće za oko 0,1 s.
-- 2) karijera_zavrsi_rundu: promenljiva „tema” preimenovana u v_tema (sudar sa kolonom),
--    #variable_conflict use_column (kolona „placeno” u WHERE).
-- 3) karijera_tema(): tema pitanja bez tehničkih oznaka (izvor:, kontinent:, uvoz-…).

create or replace function karijera_tema(p_tags text[], p_prednost text[] default '{}') returns text
language sql immutable as $$
  select coalesce(
    (select t from unnest(p_tags) t where t = any(p_prednost) limit 1),
    (select t from unnest(p_tags) t where t not like '%:%' and t not like 'uvoz-%' and t not in ('opšte','opšte znanje','preformulisano') limit 1))
$$;

create or replace function karijera_izvuci(p_teme text[], p_struka int, p_ukupno int)
returns table (id uuid, question_text text, options jsonb, correct_answer int, tema text)
language sql security definer set search_path = public as $$
  with vidjena as (select * from moja_vidjena()),
  struka as (
    select q.id from questions q left join vidjena v on v.pitanje = q.id
    where q.is_active and jsonb_array_length(q.options) = 4 and q.tags && p_teme
    order by v.kad asc nulls first, random() limit p_struka
  ),
  opste as (
    select q.id from questions q tablesample system (2) left join vidjena v on v.pitanje = q.id
    where q.is_active and jsonb_array_length(q.options) = 4 and not (q.id in (select s.id from struka s))
    order by v.kad asc nulls first, random() limit greatest(0, p_ukupno - (select count(*) from struka))
  ),
  sve as (select s.id from struka s union all select o.id from opste o),
  upis as (
    insert into vidjena_pitanja (user_id, pitanje, kad)
    select auth.uid(), s.id, now() from sve s where auth.uid() is not null
    on conflict (user_id, pitanje) do update set kad = excluded.kad
  )
  select q.id, q.question_text, q.options, q.correct_answer::int, coalesce(karijera_tema(q.tags, p_teme), 'opšte')
  from sve s join questions q on q.id = s.id order by random()
$$;

do $do$
declare d text := pg_get_functiondef('karijera_zavrsi_rundu'::regproc);
begin
  if position('karijera_tema(q.tags)' in d) > 0 then return; end if;
  d := replace(d, E'AS $function$\n', E'AS $function$\n#variable_conflict use_column\n');
  d := replace(d, 'tema text; korp', 'v_tema text; korp');
  d := replace(d, $$    tema := (select t from unnest(q.tags) t where t not like '%:%' and t not in ('opšte','preformulisano') limit 1);$$, '    v_tema := karijera_tema(q.tags);');
  d := replace(d, 'and tema is not null', 'and v_tema is not null');
  d := replace(d, 'values (ja.user_id, tema,', 'values (ja.user_id, v_tema,');
  if position('karijera_tema(q.tags)' in d) = 0 then raise exception 'zamena u karijera_zavrsi_rundu nije uspela'; end if;
  execute d;
  delete from karijera_ekspertiza where tema like 'uvoz-%' or tema like '%:%';
end $do$;

-- 4) 4 varijante zgrade po nivou (Freepik AI komplet).
alter table karijera_firme drop constraint if exists karijera_firme_stil_check;
alter table karijera_firme add constraint karijera_firme_stil_check check (stil between 1 and 4);
update karijera_firme set stil = 1 + (abs(hashtext(id::text)) % 4) where vlasnik is null and not korporacija;
do $do$
declare d text := pg_get_functiondef('karijera_otvori_firmu'::regproc);
begin
  d := replace(d, 'if p_stil not between 1 and 3 then', 'if p_stil not between 1 and 4 then');
  execute d;
end $do$;

-- 5) Teme pozicije sa brojem pitanja (izbor tema za botove pri otvaranju officea).
create or replace function karijera_teme_pozicije(p_pozicija text) returns jsonb
language sql stable security definer set search_path = public as $$
  with t as (select unnest(teme) tema, generate_subscripts(teme, 1) red from karijera_pozicije where id = p_pozicija)
  select coalesce(jsonb_agg(jsonb_build_object('tema', t.tema, 'pitanja', (select count(*) from questions q where q.is_active and t.tema = any(q.tags))) order by t.red), '[]')
  from t
$$;

-- 6) Ime firme upisuje igrač (vlasnik 04.11): kolona ime, provera, jedinstveno, preimenovanje, prijava (Apple 1.2).
alter table karijera_firme add column if not exists ime text;
create unique index if not exists karijera_firme_ime_jedinstveno on karijera_firme (lower(ime)) where ime is not null and not zatvorena;
create table if not exists karijera_prijave_imena (
  firma_id uuid not null references karijera_firme(id) on delete cascade,
  prijavio uuid not null references auth.users(id) on delete cascade,
  kad timestamptz not null default now(),
  primary key (firma_id, prijavio)
);
alter table karijera_prijave_imena enable row level security;

create or replace function karijera_ime_firme(f karijera_firme) returns text language sql stable as $$
  select coalesce(f.ime, f.ime_prefiks || ' ' || p.oblast || ' ' || f.ime_oblik) from karijera_pozicije p where p.id = f.pozicija
$$;

create or replace function karijera_ime_dozvoljeno(p_ime text) returns text language plpgsql stable as $$
declare i text := regexp_replace(trim(coalesce(p_ime, '')), '\s+', ' ', 'g'); niska text;
begin
  if char_length(i) < 3 or char_length(i) > 32 then raise exception 'Ime firme ima 3 do 32 znaka' using errcode = '22023'; end if;
  if i !~ '^[[:alnum:]ČĆŽŠĐčćžšđ .&''-]+$' then raise exception 'Ime sme da ima slova, brojeve, razmak i znake . - & ''' using errcode = '22023'; end if;
  niska := lower(translate(i, '013457@$', 'oieastas'));
  if niska ~ '(jeb|kurac|kurc|picka|pička|picku|pizd|govno|sranje|kurva|drolj|peder|fuck|shit|bitch|cunt|nigg|whore|hitler|nazi|ustas|ustaš|cetnik|četnik)' then
    raise exception 'Ovo ime nije dozvoljeno' using errcode = '22023';
  end if;
  return i;
end $$;

create or replace function karijera_otvori_firmu(p_ime text, p_stil int, p_botovi text[]) returns jsonb
language plpgsql security definer set search_path = public as $$
declare ja karijera_igraci := karijera_ja(); mojih int; nova uuid; t text; botova int; prvi boolean; v_ime text;
begin
  if ja.pozicija is null then raise exception 'Prvo izaberi poziciju' using errcode = '22023'; end if;
  v_ime := karijera_ime_dozvoljeno(p_ime);
  if exists (select 1 from karijera_firme where lower(karijera_firme.ime) = lower(v_ime) and not zatvorena) then
    raise exception 'Firma sa tim imenom već postoji' using errcode = '23505';
  end if;
  if p_stil not between 1 and 4 then raise exception 'Nepoznat stil zgrade' using errcode = '22023'; end if;
  select count(*) into mojih from karijera_firme where vlasnik = ja.user_id and not zatvorena;
  prvi := ja.office_pravo is not null;
  if mojih >= karijera_slotova(ja.ugled) then raise exception 'Nemaš slobodno mesto za još jedan office (ugled otvara nova)' using errcode = '22023'; end if;
  if not prvi then
    if mojih = 0 then raise exception 'Za svoj office prvo prođi probni rad' using errcode = '22023'; end if;
    if ja.kapital < 5000 then raise exception 'Novi office košta 5.000 kapitala' using errcode = '22023'; end if;
  end if;
  botova := case when prvi then ja.office_pravo else 0 end;
  if coalesce(array_length(p_botovi, 1), 0) > botova then raise exception 'Možeš da zaposliš najviše % bota', botova using errcode = '22023'; end if;
  insert into karijera_firme (vlasnik, pozicija, ime, ime_prefiks, ime_oblik, stil, kljucne, poslednji_ulazak, obracunato)
  values (ja.user_id, ja.pozicija, v_ime, 'Nova', 'd.o.o.', p_stil,
    (select array(select unnest(p.teme) limit 3) from karijera_pozicije p where p.id = ja.pozicija), karijera_danas(), karijera_danas())
  returning id into nova;
  foreach t in array coalesce(p_botovi, '{}') loop perform karijera_novi_bot(nova, t); end loop;
  update karijera_igraci set office_pravo = null, kapital = kapital - case when prvi then 0 else 5000 end,
    firma_id = case when firma_id = karijera_korporacija() then null else firma_id end
  where user_id = ja.user_id;
  perform karijera_dogadjaj(ja.user_id, 'osnovao', 'Osnovao ' || v_ime || '.');
  return jsonb_build_object('firma', nova);
end $$;

create or replace function karijera_preimenuj(p_firma uuid, p_ime text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare f karijera_firme := karijera_moja_firma(p_firma); v_ime text := karijera_ime_dozvoljeno(p_ime);
begin
  if exists (select 1 from karijera_firme where lower(karijera_firme.ime) = lower(v_ime) and not zatvorena and id <> f.id) then
    raise exception 'Firma sa tim imenom već postoji' using errcode = '23505';
  end if;
  update karijera_firme set ime = v_ime where id = f.id;
  delete from karijera_prijave_imena where firma_id = f.id;
  return karijera_firma(p_firma);
end $$;

create or replace function karijera_prijavi_ime(p_firma uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare ja karijera_igraci := karijera_ja(); f karijera_firme; broj int;
begin
  select * into f from karijera_firme where id = p_firma;
  if not found or f.ime is null then raise exception 'Ova firma nema ime koje se prijavljuje' using errcode = 'P0002'; end if;
  if f.vlasnik = ja.user_id then raise exception 'Ne možeš da prijaviš svoju firmu' using errcode = '22023'; end if;
  insert into karijera_prijave_imena (firma_id, prijavio) values (f.id, ja.user_id) on conflict do nothing;
  select count(*) into broj from karijera_prijave_imena where firma_id = f.id;
  if broj >= 3 then
    update karijera_firme set ime = null where id = f.id;
    delete from karijera_prijave_imena where firma_id = f.id;
    perform karijera_dogadjaj(f.vlasnik, 'ime', 'Ime firme je skinuto posle prijava igrača. Izaberi novo u podešavanjima firme.');
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- 7) Brojanje pitanja po temi preko GIN indeksa („tags @> array[t]”, ne „t = any(tags)”).
create or replace function karijera_teme_firme(p_firma uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  with f as (select * from karijera_firme where id = p_firma),
  teme as (select distinct unnest(p.teme || f.kljucne) t from f join karijera_pozicije p on p.id = f.pozicija),
  broj as (select t.t, (select count(*) from questions q where q.tags @> array[t.t] and q.is_active) n from teme t)
  select coalesce(jsonb_agg(jsonb_build_object('tema', b.t, 'pitanja', b.n) order by b.t), '[]') from broj b where b.n >= 10
$$;
create or replace function karijera_teme_pozicije(p_pozicija text) returns jsonb
language sql stable security definer set search_path = public as $$
  with t as (select unnest(teme) tema, generate_subscripts(teme, 1) red from karijera_pozicije where id = p_pozicija)
  select coalesce(jsonb_agg(jsonb_build_object('tema', t.tema, 'pitanja', (select count(*) from questions q where q.tags @> array[t.tema] and q.is_active)) order by t.red), '[]')
  from t
$$;
create or replace function karijera_pitanja_teme(p_tema text, p_bez uuid[]) returns uuid[]
language sql volatile security definer set search_path = public as $$
  select array(select q.id from questions q where q.tags @> array[p_tema] and q.is_active and jsonb_array_length(q.options) = 4
    and not (q.id = any(p_bez)) order by random() limit 10)
$$;
