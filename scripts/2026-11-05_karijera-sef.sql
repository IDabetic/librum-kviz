-- Karijera: šef i pitanja po firmi, dodatak za stres, mirni režim (vlasnik 05.11.2026).
-- Primenjeno kao migracija karijera_20_sef_i_teme. Jačine: 0 isključeno, 1 blago, 2 srednje, 3 jako.
alter table karijera_firme add column if not exists sef_tacno int not null default 2 check (sef_tacno between 0 and 3);
alter table karijera_firme add column if not exists sef_netacno int not null default 2 check (sef_netacno between 0 and 3);
alter table karijera_firme add column if not exists sef_ometanja int not null default 1 check (sef_ometanja between 0 and 3);
alter table karijera_firme add column if not exists sef_smeh boolean not null default true;
alter table karijera_firme add column if not exists struka_udeo int not null default 60 check (struka_udeo between 40 and 80);
alter table karijera_firme add column if not exists fokus text[] not null default '{}';
alter table karijera_firme add column if not exists fokus_udeo int[] not null default '{}';
alter table karijera_firme add column if not exists teza boolean not null default false;
update karijera_firme set sef_tacno = 2, sef_netacno = 2, sef_ometanja = 2, sef_smeh = true where korporacija;
alter table karijera_igraci add column if not exists mirni boolean not null default false;

-- Dodatak za stres: srednji šef +5%, jak +10% (po jačem od dva komentara), ometanja visoko +5%. Mirni igrač ga nema.
create or replace function karijera_stres(f karijera_firme) returns numeric language sql immutable as $$
  select case when f.korporacija then 0 else
    (case greatest(f.sef_tacno, f.sef_netacno) when 3 then 0.10 when 2 then 0.05 else 0 end)
    + (case when f.sef_ometanja = 3 then 0.05 else 0 end) end
$$;

create or replace function karijera_podesi_sefa(p_firma uuid, p_tacno int, p_netacno int, p_ometanja int, p_smeh boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare f karijera_firme := karijera_moja_firma(p_firma);
begin
  if least(p_tacno, p_netacno, p_ometanja) < 0 or greatest(p_tacno, p_netacno, p_ometanja) > 3 then raise exception 'Jačina je od 0 do 3' using errcode = '22023'; end if;
  update karijera_firme set sef_tacno = p_tacno, sef_netacno = p_netacno, sef_ometanja = p_ometanja, sef_smeh = coalesce(p_smeh, true) where id = f.id;
  return karijera_firma(p_firma);
end $$;

create or replace function karijera_podesi_pitanja(p_firma uuid, p_struka int, p_fokus text[], p_fokus_udeo int[], p_teza boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare f karijera_firme := karijera_moja_firma(p_firma); t text; n int;
begin
  if p_struka not between 40 and 80 then raise exception 'Struka je od 40 do 80%%' using errcode = '22023'; end if;
  if coalesce(array_length(p_fokus, 1), 0) > 2 or coalesce(array_length(p_fokus, 1), 0) <> coalesce(array_length(p_fokus_udeo, 1), 0) then
    raise exception 'Najviše 2 teme fokusa, svaka sa svojim udelom' using errcode = '22023';
  end if;
  if (select coalesce(sum(u), 0) from unnest(p_fokus_udeo) u) > 100 or exists (select 1 from unnest(p_fokus_udeo) u where u < 10 or u > 50) then
    raise exception 'Svaka tema fokusa je 10 do 50%% opšteg dela' using errcode = '22023';
  end if;
  foreach t in array coalesce(p_fokus, '{}') loop
    select count(*) into n from questions q where q.tags @> array[t] and q.is_active;
    if n < 200 then raise exception 'Tema „%” ima premalo pitanja (%)', t, n using errcode = '22023'; end if;
  end loop;
  update karijera_firme set struka_udeo = p_struka, fokus = coalesce(p_fokus, '{}'), fokus_udeo = coalesce(p_fokus_udeo, '{}'), teza = coalesce(p_teza, false) where id = f.id;
  return karijera_firma(p_firma);
end $$;

-- Teme koje vlasnik može da stavi u fokus: opšte kategorije sa bar 200 pitanja.
create or replace function karijera_teme_fokusa() returns jsonb language sql stable security definer set search_path = public as $$
  with t(tema) as (values ('nauka'),('tehnika'),('istorija'),('geografija'),('sport'),('muzika'),('film i tv'),('književnost'),
    ('jezik'),('priroda'),('umetnost'),('religija i mitologija'),('hrana i piće'),('ličnosti'),('kultura'),('medicina'),('ekonomija'),('filozofija'),('tehnologija'))
  select coalesce(jsonb_agg(jsonb_build_object('tema', t.tema, 'pitanja', n) order by n desc), '[]')
  from (select t.tema, (select count(*) from questions q where q.tags @> array[t.tema] and q.is_active) n from t) t where n >= 200
$$;

create or replace function karijera_mirni(p_da boolean) returns jsonb language plpgsql security definer set search_path = public as $$
declare ja karijera_igraci := karijera_ja();
begin
  update karijera_igraci set mirni = coalesce(p_da, false) where user_id = ja.user_id;
  return jsonb_build_object('mirni', coalesce(p_da, false));
end $$;

-- Deo runde: p_broj pitanja iz tema, bez p_bez, najviše 2× u 7 dana, teža na zahtev.
create or replace function karijera_izvuci_deo(p_teme text[], p_broj int, p_teza boolean, p_bez uuid[]) returns uuid[]
language sql volatile security definer set search_path = public as $$
  with vidjena as (
    select v.pitanje, count(*) n, max(v.kad) kad from karijera_vidjena v
    where v.user_id = auth.uid() and v.kad > now() - interval '7 days' group by v.pitanje
  )
  select coalesce(array_agg(x.id), '{}') from (
    select q.id from questions q left join vidjena v on v.pitanje = q.id
    where coalesce(array_length(p_teme, 1), 0) > 0 and q.tags && p_teme and q.is_active and jsonb_array_length(q.options) = 4
      and coalesce(v.n, 0) < 2 and not (q.id = any(p_bez))
    order by (p_teza and q.difficulty in ('hard', 'impossible')) desc, v.kad asc nulls first, random() limit greatest(p_broj, 0)
  ) x
$$;

create or replace function karijera_izvuci_opste(p_broj int, p_teza boolean, p_bez uuid[]) returns uuid[]
language sql volatile security definer set search_path = public as $$
  with vidjena as (
    select v.pitanje, count(*) n, max(v.kad) kad from karijera_vidjena v
    where v.user_id = auth.uid() and v.kad > now() - interval '7 days' group by v.pitanje
  )
  select coalesce(array_agg(x.id), '{}') from (
    select q.id from questions q tablesample system (2) left join vidjena v on v.pitanje = q.id
    where q.is_active and jsonb_array_length(q.options) = 4 and coalesce(v.n, 0) < 2 and not (q.id = any(p_bez))
    order by (p_teza and q.difficulty in ('hard', 'impossible')) desc, v.kad asc nulls first, random() limit greatest(p_broj, 0)
  ) x
$$;

-- Runda po mešavini firme: struka (udeo), fokus teme (udeo opšteg dela), ostatak opšte.
create or replace function karijera_runda_pitanja(p_firma uuid)
returns table (id uuid, question_text text, options jsonb, correct_answer int, tema text)
language plpgsql security definer set search_path = public as $$
declare
  ja karijera_igraci := karijera_ja(); f karijera_firme; teme text[]; ids uuid[] := '{}'; deo uuid[];
  n_struka int; n_opste int; i int; n_fokus int;
begin
  if ja.pozicija is null then raise exception 'Prvo izaberi poziciju' using errcode = '22023'; end if;
  f := karijera_pristup(p_firma, ja);
  select p.teme into teme from karijera_pozicije p where p.id = ja.pozicija;
  teme := teme || f.kljucne;
  n_struka := round(10 * f.struka_udeo / 100.0);
  n_opste := 10 - n_struka;
  ids := karijera_izvuci_deo(teme, n_struka, f.teza, ids);
  for i in 1 .. coalesce(array_length(f.fokus, 1), 0) loop
    n_fokus := least(round(n_opste * f.fokus_udeo[i] / 100.0)::int, 10 - coalesce(array_length(ids, 1), 0)); -- zaokruživanje dve teme ne sme preko 10
    deo := karijera_izvuci_deo(array[f.fokus[i]], n_fokus, f.teza, ids);
    ids := ids || deo;
  end loop;
  ids := ids || karijera_izvuci_opste(10 - coalesce(array_length(ids, 1), 0), f.teza, ids);
  if auth.uid() is not null then
    insert into karijera_vidjena (user_id, pitanje) select auth.uid(), x from unnest(ids) x;
    insert into vidjena_pitanja (user_id, pitanje, kad) select auth.uid(), x, now() from unnest(ids) x
      on conflict (user_id, pitanje) do update set kad = excluded.kad;
  end if;
  return query select q.id, q.question_text, q.options, q.correct_answer::int,
    coalesce(karijera_tema(q.tags, teme || f.fokus), 'opšte')
  from unnest(ids) x(pid) join questions q on q.id = x.pid order by random();
end $$;

-- Plata sa dodatkom za stres (iz kasinog dela; mirni igrač bez dodatka).
do $do$
declare d text := pg_get_functiondef('karijera_zavrsi_rundu'::regproc);
begin
  d := replace(d, $$    if 'pregovarac' = any(t) then plata := round(plata * 1.1, 2); end if;$$,
    $$    if 'pregovarac' = any(t) then plata := round(plata * 1.1, 2); end if;
    if udeo > 0 and not ja.mirni and karijera_stres(f) > 0 then
      kasi := greatest(0, kasi - round(plata * karijera_stres(f), 2));
      plata := round(plata * (1 + karijera_stres(f)), 2);
    end if;$$);
  if position('karijera_stres' in d) = 0 then raise exception 'runda zamena'; end if;
  execute d;
end $do$;

create or replace function karijera_firma_red(f karijera_firme) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', f.id, 'ime', case when f.korporacija then 'Korporacija' else karijera_ime_firme(f) end,
    'korporacija', f.korporacija, 'npc', f.vlasnik is null and not f.korporacija,
    'vlasnik', f.vlasnik, 'vlasnik_ime', case when f.korporacija then 'Šef' when f.vlasnik is null then coalesce(f.npc_ime, 'Uprava') else karijera_nadimak(f.vlasnik) end,
    'pozicija', f.pozicija, 'nivo', f.nivo, 'stil', f.stil, 'udeo', case when f.korporacija then 'korporacija' else f.udeo end,
    'kljucne', f.kljucne, 'rekord', f.rekord, 'rekord_ime', f.rekord_ime, 'rekord_igrac', f.rekord_igrac,
    'zaposlenih', (select count(*) from karijera_igraci i where i.firma_id = f.id),
    'botova', (select count(*) from karijera_botovi b where b.firma_id = f.id),
    'zastita_do', f.zastita_do,
    'sef_tacno', f.sef_tacno, 'sef_netacno', f.sef_netacno, 'sef_ometanja', f.sef_ometanja, 'sef_smeh', f.sef_smeh,
    'stres', karijera_stres(f), 'struka_udeo', f.struka_udeo, 'fokus', f.fokus, 'fokus_udeo', f.fokus_udeo, 'teza', f.teza)
$$;

do $do$
declare d text := pg_get_functiondef('karijera_stanje'::regproc);
begin
  d := replace(d, $$'pomoci', to_jsonb(ja.pomoci),$$, $$'pomoci', to_jsonb(ja.pomoci), 'mirni', ja.mirni,$$);
  if position($$'mirni', ja.mirni$$ in d) = 0 then raise exception 'stanje zamena'; end if;
  execute d;
end $do$;

-- karijera_22_lik_sefa: izgled šefa (Korporacija svoj; vlasnik bira 1 od 6; NPC po id-ju firme).
alter table karijera_firme add column if not exists sef_lik text check (sef_lik in ('korporacija','m_mladi','m_srednji','m_stari','z_mlada','z_srednja','z_starija'));
create or replace function karijera_lik_sefa(f karijera_firme) returns text language sql immutable as $$
  select coalesce(f.sef_lik, case when f.korporacija then 'korporacija'
    else (array['m_mladi','m_srednji','m_stari','z_mlada','z_srednja','z_starija'])[1 + abs(hashtext(f.id::text)) % 6] end)
$$;
drop function if exists karijera_podesi_sefa(uuid, int, int, int, boolean);
create or replace function karijera_podesi_sefa(p_firma uuid, p_tacno int, p_netacno int, p_ometanja int, p_smeh boolean, p_lik text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare f karijera_firme := karijera_moja_firma(p_firma);
begin
  if least(p_tacno, p_netacno, p_ometanja) < 0 or greatest(p_tacno, p_netacno, p_ometanja) > 3 then raise exception 'Jačina je od 0 do 3' using errcode = '22023'; end if;
  if p_lik is not null and p_lik not in ('korporacija','m_mladi','m_srednji','m_stari','z_mlada','z_srednja','z_starija') then raise exception 'Nepoznat izgled šefa' using errcode = '22023'; end if;
  update karijera_firme set sef_tacno = p_tacno, sef_netacno = p_netacno, sef_ometanja = p_ometanja, sef_smeh = coalesce(p_smeh, true),
    sef_lik = coalesce(p_lik, sef_lik) where id = f.id;
  return karijera_firma(p_firma);
end $$;
do $do$
declare d text := pg_get_functiondef('karijera_firma_red'::regproc);
begin
  d := replace(d, $$'sef_smeh', f.sef_smeh,$$, $$'sef_smeh', f.sef_smeh, 'sef_lik', karijera_lik_sefa(f),$$);
  if position('karijera_lik_sefa' in d) = 0 then raise exception 'zamena'; end if;
  execute d;
end $do$;
