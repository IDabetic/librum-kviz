-- Karijera (docs/KARIJERA-PRAVILA.md): pozicije, probni rad, firme, botovi, rekord, duel za firmu.
-- Sve ide kroz SECURITY DEFINER RPC; tabele imaju RLS bez politika (niko ih ne čita direktno).
-- Aditivno: ne menja nijednu postojeću tabelu ni funkciju.

-- ============ Tabele ============

create table if not exists karijera_pozicije (
  id text primary key,
  naziv text not null,
  opis text not null,
  oblast text not null,          -- drugi deo imena firme („Medika”, „Pravni tim”)
  ikonica text not null,
  teme text[] not null,          -- oznake iz questions.tags; nove oznake rade bez nove verzije app
  redosled int not null
);

create table if not exists karijera_firme (
  id uuid primary key default gen_random_uuid(),
  vlasnik uuid references auth.users(id) on delete set null,
  npc_ime text,                  -- izmišljen vlasnik NPC firme
  korporacija boolean not null default false,
  pozicija text not null references karijera_pozicije(id),
  ime_prefiks text not null,
  ime_oblik text not null,
  nivo int not null default 1 check (nivo between 1 and 5),
  stil int not null default 1 check (stil between 1 and 3),
  kasa numeric(14,2) not null default 0,
  udeo text not null default 'posten' check (udeo in ('skrt','posten','izdasan')),
  udeo_menjan timestamptz,
  kljucne text[] not null default '{}',
  rekord int not null default 0,
  rekord_igrac uuid references auth.users(id) on delete set null,
  rekord_ime text,
  vlasnik_od timestamptz not null default now(),
  zastita_do timestamptz not null default now() + interval '3 days',
  poslednji_ulazak date,
  obracunato date,
  otkaza_od_ulaska int not null default 0,
  dividenda_dan date,
  zatvorena boolean not null default false,
  osnovana timestamptz not null default now()
);
create index if not exists karijera_firme_vlasnik on karijera_firme (vlasnik) where not zatvorena;
create index if not exists karijera_firme_otvorene on karijera_firme (nivo desc) where not zatvorena;

create table if not exists karijera_igraci (
  user_id uuid primary key references auth.users(id) on delete cascade,
  pozicija text references karijera_pozicije(id),
  kapital numeric(14,2) not null default 0,
  ugled int not null default 0,
  firma_id uuid references karijera_firme(id) on delete set null,   -- gde je zaposlen
  zaposlen_od timestamptz,
  probni_runde int not null default 0,
  probni_tacnih int not null default 0,
  probni_cilj int not null default 10,
  probni_ishod int,             -- null u toku; 2/1/0 = office sa toliko botova; -1 = pao
  probni_kraj date,
  office_pravo int,             -- broj botova uz pravo na prvi office; null = nema prava
  bivsi_vlasnik boolean not null default false,
  odmor_mesec text,
  odmor_iskorisceno int not null default 0,
  odmor_do date,
  napravljen timestamptz not null default now()
);
create index if not exists karijera_igraci_firma on karijera_igraci (firma_id);

create table if not exists karijera_botovi (
  id uuid primary key default gen_random_uuid(),
  firma_id uuid not null references karijera_firme(id) on delete cascade,
  ime text not null,
  tema text not null,
  nivo int not null default 60 check (nivo in (60, 75, 90)),
  pomoci_dan date,
  pomoci_iskorisceno int not null default 0,
  zaposlen timestamptz not null default now()
);
create index if not exists karijera_botovi_firma on karijera_botovi (firma_id);

create table if not exists karijera_ekspertiza (
  user_id uuid not null references auth.users(id) on delete cascade,
  tema text not null,
  ocena int not null default 0,
  poslednje timestamptz not null default now(),
  primary key (user_id, tema)
);

create table if not exists karijera_runde (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  firma_id uuid references karijera_firme(id) on delete set null,
  dan date not null,
  tacnih int not null,
  poeni int not null,
  placeno boolean not null,
  plata numeric(14,2) not null default 0,
  kasi numeric(14,2) not null default 0,
  kad timestamptz not null default now()
);
create index if not exists karijera_runde_igrac_dan on karijera_runde (user_id, dan);
create index if not exists karijera_runde_firma_dan on karijera_runde (firma_id, dan);

create table if not exists karijera_izazovi (
  id uuid primary key default gen_random_uuid(),
  firma_id uuid not null references karijera_firme(id) on delete cascade,
  vlasnik uuid references auth.users(id) on delete set null,     -- null = NPC
  izazivac uuid not null references auth.users(id) on delete cascade,
  pokusaj int not null,
  revans boolean not null default false,
  tema_izazivac text not null,
  tema1 text,
  tema3 text,
  pitanja uuid[],
  botova int not null default 0,
  bot_pomoci jsonb not null default '{}',
  stanje text not null default 'ceka' check (stanje in ('ceka','u_toku','gotov')),
  rok timestamptz not null default now() + interval '24 hours',
  vlasnik_tacnih int, vlasnik_ms int,
  izazivac_tacnih int, izazivac_ms int,
  pobednik uuid,
  ishod text,
  kad timestamptz not null default now(),
  zavrsen timestamptz
);
create index if not exists karijera_izazovi_firma on karijera_izazovi (firma_id, stanje);
create index if not exists karijera_izazovi_izazivac on karijera_izazovi (izazivac, kad desc);
create index if not exists karijera_izazovi_vlasnik on karijera_izazovi (vlasnik, kad desc);

create table if not exists karijera_dogadjaji (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  vrsta text not null,
  tekst text not null,
  kad timestamptz not null default now()
);
create index if not exists karijera_dogadjaji_igrac on karijera_dogadjaji (user_id, kad desc);

alter table karijera_pozicije enable row level security;
alter table karijera_firme enable row level security;
alter table karijera_igraci enable row level security;
alter table karijera_botovi enable row level security;
alter table karijera_ekspertiza enable row level security;
alter table karijera_runde enable row level security;
alter table karijera_izazovi enable row level security;
alter table karijera_dogadjaji enable row level security;

-- ============ Pozicije (teme: postojeće oznake + nove koje dolaze generisanjem) ============

insert into karijera_pozicije (id, naziv, opis, oblast, ikonica, teme, redosled) values
 ('marketing','Marketing menadžer','Brendovi, reklame, mediji i kupci.','Media','megaphone', array['marketing','brendovi','reklame','društvene mreže','mediji','ekonomija','društvo'],1),
 ('novinar','Novinar','Politika, savremena istorija i ličnosti.','Press','newspaper', array['mediji','politika','savremena istorija','ličnosti','društvo','istorija','geografija'],2),
 ('advokat','Advokat','Pravo, ustav, suđenja i institucije.','Pravni tim','building.columns', array['pravo','ustav','ljudska prava','međunarodne institucije','istorija','društvo','filozofija'],3),
 ('lekar','Lekar','Medicina, anatomija, bolesti i ishrana.','Medika','cross.case', array['medicina','anatomija','biologija','ishrana','nauka','priroda'],4),
 ('inzenjer','Inženjer','Fizika, matematika, izumi i građevine.','Inženjering','gearshape.2', array['fizika','matematika','izumi','tehnika','tehnologija','arhitektura','nauka'],5),
 ('programer','Programer','Računari, internet i tehnološke firme.','Soft','laptopcomputer', array['računari','internet','it kompanije','video-igre','tehnologija','tehnika','matematika'],6),
 ('bankar','Bankar','Ekonomija, novac, berza i kompanije.','Finans','banknote', array['ekonomija','finansije','berza','valute','kompanije','matematika'],7),
 ('istoricar','Istoričar','Vladari, ratovi, antika i arheologija.','Arhiv','scroll', array['istorija','vladari','ratovi','antika','arheologija','Vladari','Godine događaja'],8),
 ('izdavac','Izdavač','Pisci, knjige, likovi i nagrade.','Knjiga','books.vertical', array['književnost','Klasici','Književna dela','Pisci i dela','Književni pravci','religija i mitologija'],9),
 ('kustos','Kustos muzeja','Slikarstvo, skulptura i arhitektura.','Galerija','paintpalette', array['umetnost','slikari','arhitektura','skulptura','muzeji','kultura'],10),
 ('muzicki','Muzički producent','Kompozitori, bendovi i instrumenti.','Zvuk','music.note', array['muzika','kompozitori','opera','evrovizija','instrumenti'],11),
 ('filmski','Filmski producent','Film, glumci, serije i pozorište.','Film','film', array['film i tv','Film','pozorište','glumci','serije'],12),
 ('turizam','Turistički menadžer','Države, gradovi, zastave i znamenitosti.','Tura','airplane', array['geografija','Znamenitosti','Gradovi i reke','glavni gradovi','zastave','valute'],13),
 ('diplomata','Diplomata','Međunarodni odnosi, jezici i religije.','Ambasada','globe.europe.africa', array['politika','međunarodni odnosi','geografija','istorija','religija i mitologija','jezik'],14),
 ('kuvar','Šef kuhinje','Jela sveta, vino i namirnice.','Gastro','fork.knife', array['hrana i piće','gastronomija','vino','začini'],15),
 ('naucnik','Naučnik','Hemija, biologija, svemir i otkrića.','Laboratorija','atom', array['nauka','hemija','biologija','astronomija','fizika','medicina'],16),
 ('veterinar','Veterinar','Životinje, biljke i priroda.','Vet','pawprint', array['priroda','životinje','biljke','ekologija','klima'],17),
 ('psiholog','Psiholog','Psihologija, filozofija i ponašanje.','Psiha','brain.head.profile', array['psihologija','filozofija','društvo','religija i mitologija','sociologija'],18),
 ('sportski','Sportski menadžer','Fudbal, košarka, tenis i rekordi.','Sport','sportscourt', array['sport','Sportisti','Sportisti po godinama','fudbal','košarka','olimpijske igre'],19),
 ('moda','Modni dizajner','Moda, dizajn i poznate ličnosti.','Atelje','tshirt', array['moda','dizajn','umetnost','ličnosti','kultura'],20)
on conflict (id) do update set naziv = excluded.naziv, opis = excluded.opis, oblast = excluded.oblast,
  ikonica = excluded.ikonica, teme = excluded.teme, redosled = excluded.redosled;

-- ============ Pomoćne funkcije ============

create or replace function karijera_danas() returns date language sql stable
as $$ select (now() at time zone 'Europe/Belgrade')::date $$;

create or replace function karijera_prefiksi() returns text[] language sql immutable as $$
  select array['Atlas','Orion','Dunav','Kruna','Sever','Feniks','Avala','Morava','Sirius','Vega','Polaris','Titan',
    'Kosmaj','Rudnik','Tara','Zlatibor','Delta','Omega','Alfa','Beta','Gama','Sigma','Lambda','Kappa',
    'Hermes','Apolon','Atena','Minerva','Janus','Vesta','Merkur','Saturn','Neptun','Pluton','Mars','Luna',
    'Sunce','Zora','Duga','Iskra','Plamen','Kamen','Hrast','Bor','Lipa','Javor','Jela','Breza',
    'Soko','Orao','Vuk','Ris','Jelen','Lav','Delfin','Kit','Galeb','Sova','Labud','Ždral',
    'Vardar','Drina','Sava','Tisa','Ibar','Timok','Lim','Neretva','Una','Kolubara','Mlava','Pek',
    'Prizma','Kompas','Most','Luka','Kula','Tvrđava','Kapija','Trg','Ulica','Pristan','Svetionik','Mlin',
    'Nova','Prva','Velika','Mala','Zlatna','Srebrna','Plava','Zelena','Crvena','Bela','Siva','Crna']
$$;

create or replace function karijera_oblici() returns text[] language sql immutable
as $$ select array['d.o.o.','grupa','studio','biro','holding'] $$;

create or replace function karijera_ime_firme(f karijera_firme) returns text language sql stable as $$
  select f.ime_prefiks || ' ' || p.oblast || ' ' || f.ime_oblik from karijera_pozicije p where p.id = f.pozicija
$$;

create or replace function karijera_nadimak(p uuid) returns text language sql stable security definer set search_path = public as $$
  select coalesce(nullif(trim(pp.nickname), ''), 'Igrač') from public_profiles pp where pp.id = p
$$;

create or replace function karijera_titula(p_ugled int) returns int language sql immutable as $$
  select case when p_ugled >= 30000 then 3 when p_ugled >= 10000 then 2 when p_ugled >= 3000 then 1 else 0 end
$$;

create or replace function karijera_slotova(p_ugled int) returns int language sql immutable as $$
  select 1 + (case when p_ugled / 1000 + 1 >= 10 then 1 else 0 end)
           + (case when p_ugled / 1000 + 1 >= 25 then 1 else 0 end)
           + (case when p_ugled / 1000 + 1 >= 50 then 1 else 0 end)
$$;

-- Cene i granice po nivou zgrade (1..5).
create or replace function karijera_cena_nivoa(n int) returns numeric language sql immutable
as $$ select (array[0, 2000, 10000, 40000, 150000])[n]::numeric $$;
create or replace function karijera_min_zaposlenih(n int) returns int language sql immutable
as $$ select (array[0, 1, 3, 8, 20])[n] $$;
create or replace function karijera_vrednost_zgrade(n int) returns numeric language sql immutable
as $$ select (array[500, 2500, 12500, 52500, 202500])[n]::numeric $$;

create or replace function karijera_dogadjaj(p uuid, p_vrsta text, p_tekst text) returns void
language sql security definer set search_path = public
as $$ insert into karijera_dogadjaji (user_id, vrsta, tekst) select p, p_vrsta, p_tekst where p is not null $$;

create or replace function karijera_korporacija() returns uuid language sql stable security definer set search_path = public
as $$ select id from karijera_firme where korporacija limit 1 $$;

create or replace function karijera_ja() returns karijera_igraci language plpgsql security definer set search_path = public as $$
declare r karijera_igraci;
begin
  if auth.uid() is null then raise exception 'Prijavi se da bi igrao Karijeru' using errcode = '42501'; end if;
  insert into karijera_igraci (user_id) values (auth.uid()) on conflict do nothing;
  select * into r from karijera_igraci where user_id = auth.uid() for update;
  return r;
end $$;

-- ============ Održavanje (lenjo: računa se kad vlasnik otvori Karijeru, bez crona) ============

create or replace function karijera_odrzi(p_firma uuid) returns void language plpgsql security definer set search_path = public as $$
declare
  f karijera_firme; danas date := karijera_danas(); dan date; trosak numeric; botova int;
  odmor date; efektivni date; propusteno int; treba_otkaza int; b record;
begin
  select * into f from karijera_firme where id = p_firma for update;
  if f is null or f.zatvorena or f.korporacija or f.vlasnik is null then return; end if;

  -- Dnevno održavanje iz kase; bez dovoljno kase jedan bot odlazi.
  dan := coalesce(f.obracunato, f.osnovana::date);
  while dan < danas loop
    dan := dan + 1;
    select count(*) into botova from karijera_botovi where firma_id = f.id;
    trosak := 40 * f.nivo + 25 * botova;
    if f.kasa >= trosak then
      f.kasa := f.kasa - trosak;
    else
      f.kasa := 0;
      select id, ime into b from karijera_botovi where firma_id = f.id order by zaposlen desc limit 1;
      if found then
        delete from karijera_botovi where id = b.id;
        perform karijera_dogadjaj(f.vlasnik, 'otkaz', b.ime || ' je dao otkaz: u kasi nije bilo za plate.');
      end if;
    end if;
  end loop;
  update karijera_firme set kasa = f.kasa, obracunato = danas where id = f.id;

  -- Neaktivnost: 1 propušten dan bot odlazi, 2 drugi, 3 firma se zatvara. Godišnji odmor ne računa.
  select odmor_do into odmor from karijera_igraci where user_id = f.vlasnik;
  efektivni := greatest(coalesce(f.poslednji_ulazak, f.osnovana::date), least(coalesce(odmor, '1900-01-01'), danas - 1));
  propusteno := greatest(0, danas - efektivni - 1);
  if propusteno >= 3 then
    update karijera_firme set zatvorena = true where id = f.id;
    delete from karijera_botovi where firma_id = f.id;
    update karijera_igraci set firma_id = null where firma_id = f.id;
    update karijera_igraci set bivsi_vlasnik = true where user_id = f.vlasnik;
    perform karijera_dogadjaj(f.vlasnik, 'zatvorena', karijera_ime_firme(f) || ' je zatvorena posle 3 dana bez vlasnika.');
    return;
  end if;
  treba_otkaza := least(propusteno, 2) - f.otkaza_od_ulaska;
  while treba_otkaza > 0 loop
    select id, ime into b from karijera_botovi where firma_id = f.id order by zaposlen desc limit 1;
    exit when not found;
    delete from karijera_botovi where id = b.id;
    perform karijera_dogadjaj(f.vlasnik, 'otkaz', b.ime || ' je dao otkaz: vlasnika nije bilo u firmi.');
    update karijera_firme set otkaza_od_ulaska = otkaza_od_ulaska + 1 where id = f.id;
    treba_otkaza := treba_otkaza - 1;
  end loop;
end $$;

-- ============ Pitanja ============

-- 10 pitanja: p_struka iz tema, ostatak opšte. 7 dana bez ponavljanja kao u ostalim igrama (moja_vidjena).
create or replace function karijera_izvuci(p_teme text[], p_struka int, p_ukupno int)
returns table (id uuid, question_text text, options jsonb, correct_answer int, tema text)
language sql security definer set search_path = public as $$
  with vidjena as (select * from moja_vidjena()),
  struka as (
    select q.id, q.question_text, q.options, q.correct_answer::int,
      (select t from unnest(q.tags) t where t = any(p_teme) limit 1) as tema
    from questions q left join vidjena v on v.pitanje = q.id
    where q.is_active and jsonb_array_length(q.options) = 4 and q.tags && p_teme
    order by v.kad asc nulls first, random() limit p_struka
  ),
  opste as (
    select q.id, q.question_text, q.options, q.correct_answer::int,
      coalesce((select t from unnest(q.tags) t where t not like '%:%' and t not in ('opšte','preformulisano') limit 1), 'opšte') as tema
    from questions q left join vidjena v on v.pitanje = q.id
    where q.is_active and jsonb_array_length(q.options) = 4 and not (q.id in (select s.id from struka s))
    order by v.kad asc nulls first, random() limit greatest(0, p_ukupno - (select count(*) from struka))
  ),
  sve as (select * from struka union all select * from opste),
  upis as (
    insert into vidjena_pitanja (user_id, pitanje, kad)
    select auth.uid(), s.id, now() from sve s where auth.uid() is not null
    on conflict (user_id, pitanje) do update set kad = excluded.kad
  )
  select * from sve order by random()
$$;

-- Može li igrač da igra rundu u ovoj firmi: Korporacija, firma gde je zaposlen ili svoja.
create or replace function karijera_pristup(p_firma uuid, ja karijera_igraci) returns karijera_firme
language plpgsql security definer set search_path = public as $$
declare f karijera_firme;
begin
  select * into f from karijera_firme where id = p_firma and not zatvorena;
  if f is null then raise exception 'Ta firma više ne radi' using errcode = 'P0002'; end if;
  if not (f.korporacija or f.vlasnik = ja.user_id or ja.firma_id = f.id) then
    raise exception 'Ne radiš u ovoj firmi' using errcode = '42501';
  end if;
  return f;
end $$;

create or replace function karijera_runda_pitanja(p_firma uuid)
returns table (id uuid, question_text text, options jsonb, correct_answer int, tema text)
language plpgsql security definer set search_path = public as $$
declare ja karijera_igraci := karijera_ja(); f karijera_firme; teme text[];
begin
  if ja.pozicija is null then raise exception 'Prvo izaberi poziciju' using errcode = '22023'; end if;
  f := karijera_pristup(p_firma, ja);
  select p.teme into teme from karijera_pozicije p where p.id = ja.pozicija;
  teme := teme || f.kljucne;
  return query select * from karijera_izvuci(teme, 6, 10);
end $$;

-- ============ Runda ============

-- p_odgovori: [{"id": uuid, "izbor": 0..3 ili -1 (isteklo), "ms": int, "pomoc": null|kolega|guglanje|asistent|bot}]
-- izbor je indeks u originalnom redosledu options iz baze (aplikacija ga vraća posle mešanja).
create or replace function karijera_zavrsi_rundu(p_firma uuid, p_odgovori jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  ja karijera_igraci := karijera_ja(); f karijera_firme; danas date := karijera_danas();
  o jsonb; q record; tacan boolean; niz int := 0; tacnih int := 0; promet numeric := 0; vrednost numeric;
  kurs numeric; tezina numeric; brzina numeric; mnozilac_niza numeric; pomoc numeric; titula_mn numeric;
  placenih int; placeno boolean; udeo numeric; plata numeric := 0; kasi numeric := 0; ugled_plus int := 20;
  poeni int; danas_u_firmi int; nov_rekord boolean := false; probni jsonb := null; ishod int; procenat numeric;
  tema text; korp uuid := karijera_korporacija(); u_probnom boolean;
begin
  if ja.pozicija is null then raise exception 'Prvo izaberi poziciju' using errcode = '22023'; end if;
  if jsonb_typeof(p_odgovori) <> 'array' or jsonb_array_length(p_odgovori) <> 10 then
    raise exception 'Runda ima tačno 10 odgovora' using errcode = '22023';
  end if;
  f := karijera_pristup(p_firma, ja);
  titula_mn := (array[1, 1.3, 1.6, 2])[karijera_titula(ja.ugled) + 1];
  u_probnom := ja.probni_ishod is null and f.korporacija;
  if u_probnom and ja.probni_runde < ja.probni_cilj
     and (select count(*) from karijera_runde r where r.user_id = ja.user_id and r.dan = danas and r.firma_id = korp) >= 4 then
    raise exception 'Probni rad: najviše 4 runde dnevno. Nastavi sutra.' using errcode = '22023';
  end if;

  for o in select * from jsonb_array_elements(p_odgovori) loop
    select qq.correct_answer, qq.difficulty, qq.tags into q from questions qq where qq.id = (o->>'id')::uuid;
    if not found then continue; end if;
    tacan := (o->>'izbor')::int = q.correct_answer;
    tema := (select t from unnest(q.tags) t where t not like '%:%' and t not in ('opšte','preformulisano') limit 1);
    if tacan then
      tacnih := tacnih + 1; niz := niz + 1;
      kurs := case when not f.korporacija and q.tags && f.kljucne then 2 else 1 end;
      tezina := case q.difficulty when 'easy' then 1 when 'medium' then 2 else 4 end;
      brzina := case when (o->>'ms')::int <= 5000 then 1.5 when (o->>'ms')::int <= 10000 then 1.2 else 1 end;
      mnozilac_niza := case when niz >= 10 then 1.5 when niz >= 5 then 1.2 else 1 end;
      pomoc := case o->>'pomoc' when 'kolega' then 0.7 when 'asistent' then 0.6 when 'bot' then 0.6 when 'guglanje' then 0.5 else 1 end;
      vrednost := 10 * kurs * tezina * brzina * mnozilac_niza * titula_mn * pomoc;
      promet := promet + vrednost;
    else
      niz := 0;
    end if;
    -- Ugled i ekspertiza samo bez pomoći.
    if coalesce(o->>'pomoc', '') = '' and tema is not null then
      if tacan then ugled_plus := ugled_plus + 10; end if;
      insert into karijera_ekspertiza (user_id, tema, ocena) values (ja.user_id, tema, case when tacan then (5 * case q.difficulty when 'easy' then 1 when 'medium' then 2 else 4 end) else 0 end)
      on conflict (user_id, tema) do update set ocena = greatest(0, karijera_ekspertiza.ocena + case when tacan then (5 * case q.difficulty when 'easy' then 1 when 'medium' then 2 else 4 end) else -2 end), poslednje = now();
    end if;
  end loop;

  poeni := round(promet);
  select count(*) into placenih from karijera_runde where user_id = ja.user_id and dan = danas and placeno;
  placeno := placenih < 10;

  if placeno then
    if f.korporacija then udeo := 0.4;
    elsif f.vlasnik = ja.user_id then udeo := 0;
    else udeo := case f.udeo when 'skrt' then 0.5 when 'izdasan' then 0.8 else 0.65 end;
    end if;
    plata := round(promet * udeo, 2);
    kasi := case when f.korporacija then 0 else round(promet - plata, 2) end;
  end if;

  insert into karijera_runde (user_id, firma_id, dan, tacnih, poeni, placeno, plata, kasi)
  values (ja.user_id, f.id, danas, tacnih, poeni, placeno, plata, kasi);
  update karijera_igraci set kapital = kapital + plata, ugled = ugled + ugled_plus where user_id = ja.user_id;
  update karijera_firme set kasa = kasa + kasi where id = f.id;

  -- Ulazak vlasnika u svoj office: brojač otkaza kreće iz početka.
  if f.vlasnik = ja.user_id then
    update karijera_firme set poslednji_ulazak = danas, otkaza_od_ulaska = 0 where id = f.id;
  end if;

  -- Rekord firme: poeni jednog igrača za dan, u plaćenim rundama.
  if placeno and not f.korporacija then
    select coalesce(sum(r.poeni), 0) into danas_u_firmi from karijera_runde r where r.user_id = ja.user_id and r.firma_id = f.id and r.dan = danas and r.placeno;
    if danas_u_firmi > f.rekord then
      update karijera_firme set rekord = danas_u_firmi, rekord_igrac = ja.user_id, rekord_ime = karijera_nadimak(ja.user_id) where id = f.id;
      nov_rekord := true;
      if f.rekord_igrac is distinct from ja.user_id and f.vlasnik is distinct from ja.user_id then
        perform karijera_dogadjaj(f.vlasnik, 'rekord', karijera_nadimak(ja.user_id) || ' je oborio rekord firme ' || karijera_ime_firme(f) || ' i može da traži preuzimanje.');
      end if;
    end if;
  end if;

  -- Probni rad.
  if u_probnom and ja.probni_runde < ja.probni_cilj then
    update karijera_igraci set probni_runde = probni_runde + 1, probni_tacnih = probni_tacnih + tacnih where user_id = ja.user_id
      returning * into ja;
    if ja.probni_runde >= ja.probni_cilj then
      procenat := ja.probni_tacnih::numeric / (ja.probni_cilj * 10);
      ishod := case when procenat >= 0.9 then 2 when procenat >= 0.75 then 1 when procenat >= 0.6 then 0 else -1 end;
      update karijera_igraci set probni_ishod = ishod, probni_kraj = danas,
        office_pravo = case when ishod >= 0 then ishod end where user_id = ja.user_id;
      perform karijera_dogadjaj(ja.user_id, 'probni', case when ishod >= 0
        then 'Prošao probni rad sa ' || round(procenat * 100) || '% tačnih. Pravo na svoj office.'
        else 'Probni rad: ' || round(procenat * 100) || '% tačnih. Ostaje u Korporaciji.' end);
    end if;
    probni := jsonb_build_object('runde', ja.probni_runde, 'cilj', ja.probni_cilj, 'tacnih', ja.probni_tacnih, 'ishod', ishod);
  end if;

  return jsonb_build_object('tacnih', tacnih, 'poeni', poeni, 'placeno', placeno, 'plata', plata, 'kasi', kasi,
    'ugled', ugled_plus, 'rekord', nov_rekord, 'probni', probni,
    'placenih_danas', placenih + case when placeno then 1 else 0 end);
end $$;

-- ============ Izbor pozicije i probni ============

create or replace function karijera_izaberi_poziciju(p_pozicija text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare ja karijera_igraci := karijera_ja();
begin
  if not exists (select 1 from karijera_pozicije where id = p_pozicija) then raise exception 'Nepoznata pozicija' using errcode = '22023'; end if;
  if ja.pozicija is not null and (ja.probni_ishod is null and ja.probni_runde > 0) then
    raise exception 'Pozicija se ne menja usred probnog rada' using errcode = '22023';
  end if;
  update karijera_igraci set pozicija = p_pozicija,
    firma_id = coalesce(firma_id, karijera_korporacija()), zaposlen_od = coalesce(zaposlen_od, now())
  where user_id = ja.user_id;
  if ja.pozicija is null then
    perform karijera_dogadjaj(ja.user_id, 'pocetak', 'Počeo karijeru u Korporaciji kao ' || (select lower(naziv) from karijera_pozicije where id = p_pozicija) || '.');
  end if;
  return karijera_stanje();
end $$;

-- Novi probni posle neuspeha: 3 radna dana u Korporaciji; bivši vlasnik odmah, skraćeni (3 runde).
create or replace function karijera_novi_probni() returns jsonb
language plpgsql security definer set search_path = public as $$
declare ja karijera_igraci := karijera_ja(); dana int;
begin
  if ja.office_pravo is not null then raise exception 'Već imaš pravo na office' using errcode = '22023'; end if;
  if ja.probni_ishod is null then raise exception 'Probni rad je već u toku' using errcode = '22023'; end if;
  if not ja.bivsi_vlasnik then
    select count(distinct dan) into dana from karijera_runde where user_id = ja.user_id and firma_id = karijera_korporacija() and dan > ja.probni_kraj;
    if dana < 3 then raise exception 'Novi probni rad posle 3 radna dana u Korporaciji (još %)', 3 - dana using errcode = '22023'; end if;
  end if;
  update karijera_igraci set probni_runde = 0, probni_tacnih = 0, probni_ishod = null,
    probni_cilj = case when bivsi_vlasnik then 3 else 10 end, probni_kraj = karijera_danas(),
    firma_id = coalesce(firma_id, karijera_korporacija())
  where user_id = ja.user_id;
  return karijera_stanje();
end $$;

-- ============ Firma: otvaranje, podešavanja, botovi, zgrada, dividenda ============

create or replace function karijera_imena_botova() returns text[] language sql immutable as $$
  select array['Mina','Luka','Sara','Vuk','Nina','Pavle','Iva','Đorđe','Lena','Filip','Tea','Marko','Una','Relja','Ana','Bogdan','Kaja','Stefan','Mila','Ognjen']
$$;

create or replace function karijera_novi_bot(p_firma uuid, p_tema text, p_nivo int default 60) returns void
language sql security definer set search_path = public as $$
  insert into karijera_botovi (firma_id, ime, tema, nivo)
  select p_firma, (karijera_imena_botova())[1 + floor(random() * array_length(karijera_imena_botova(), 1))::int], p_tema, p_nivo
$$;

-- p_botovi: niz tema (koliko bota, toliko tema; najviše office_pravo za prvi office).
create or replace function karijera_otvori_firmu(p_prefiks text, p_oblik text, p_stil int, p_botovi text[]) returns jsonb
language plpgsql security definer set search_path = public as $$
declare ja karijera_igraci := karijera_ja(); mojih int; nova uuid; t text; botova int; prvi boolean;
begin
  if ja.pozicija is null then raise exception 'Prvo izaberi poziciju' using errcode = '22023'; end if;
  if not p_prefiks = any(karijera_prefiksi()) or not p_oblik = any(karijera_oblici()) or p_oblik = 'holding' then
    raise exception 'Ime firme se sastavlja od ponuđenih delova' using errcode = '22023';
  end if;
  if p_stil not between 1 and 3 then raise exception 'Nepoznat stil zgrade' using errcode = '22023'; end if;
  select count(*) into mojih from karijera_firme where vlasnik = ja.user_id and not zatvorena;
  prvi := ja.office_pravo is not null;
  if mojih >= karijera_slotova(ja.ugled) then raise exception 'Nemaš slobodno mesto za još jedan office (ugled otvara nova)' using errcode = '22023'; end if;
  if not prvi then
    if mojih = 0 then raise exception 'Za svoj office prvo prođi probni rad' using errcode = '22023'; end if;
    if ja.kapital < 5000 then raise exception 'Novi office košta 5.000 kapitala' using errcode = '22023'; end if;
  end if;
  botova := case when prvi then ja.office_pravo else 0 end;
  if coalesce(array_length(p_botovi, 1), 0) > botova then raise exception 'Možeš da zaposliš najviše % bota', botova using errcode = '22023'; end if;

  insert into karijera_firme (vlasnik, pozicija, ime_prefiks, ime_oblik, stil, kljucne, poslednji_ulazak, obracunato)
  values (ja.user_id, ja.pozicija, p_prefiks, p_oblik, p_stil,
    (select array(select unnest(p.teme) limit 3) from karijera_pozicije p where p.id = ja.pozicija), karijera_danas(), karijera_danas())
  returning id into nova;
  foreach t in array coalesce(p_botovi, '{}') loop perform karijera_novi_bot(nova, t); end loop;
  update karijera_igraci set office_pravo = null, kapital = kapital - case when prvi then 0 else 5000 end,
    firma_id = case when firma_id = karijera_korporacija() then null else firma_id end
  where user_id = ja.user_id;
  perform karijera_dogadjaj(ja.user_id, 'osnovao', 'Osnovao ' || p_prefiks || ' ' || (select oblast from karijera_pozicije where id = ja.pozicija) || ' ' || p_oblik || '.');
  return jsonb_build_object('firma', nova);
end $$;

create or replace function karijera_moja_firma(p_firma uuid) returns karijera_firme
language plpgsql security definer set search_path = public as $$
declare f karijera_firme;
begin
  select * into f from karijera_firme where id = p_firma and vlasnik = auth.uid() and not zatvorena for update;
  if f is null then raise exception 'Ovo nije tvoja firma' using errcode = '42501'; end if;
  return f;
end $$;

create or replace function karijera_podesi_firmu(p_firma uuid, p_udeo text, p_kljucne text[]) returns jsonb
language plpgsql security definer set search_path = public as $$
declare f karijera_firme := karijera_moja_firma(p_firma);
begin
  if p_udeo is not null and p_udeo <> f.udeo then
    if p_udeo not in ('skrt','posten','izdasan') then raise exception 'Nepoznat nivo plate' using errcode = '22023'; end if;
    if f.udeo_menjan > now() - interval '7 days' then raise exception 'Plata se menja jednom u 7 dana' using errcode = '22023'; end if;
    update karijera_firme set udeo = p_udeo, udeo_menjan = now() where id = f.id;
  end if;
  if p_kljucne is not null then
    if coalesce(array_length(p_kljucne, 1), 0) > 3 then raise exception 'Najviše 3 ključne oblasti' using errcode = '22023'; end if;
    update karijera_firme set kljucne = p_kljucne where id = f.id;
  end if;
  return karijera_firma(p_firma);
end $$;

create or replace function karijera_zaposli_bota(p_firma uuid, p_tema text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare f karijera_firme := karijera_moja_firma(p_firma); botova int;
begin
  select count(*) into botova from karijera_botovi where firma_id = f.id;
  if botova >= f.nivo then raise exception 'Zgrada ima mesta za % bota; nadogradi je', f.nivo using errcode = '22023'; end if;
  if f.kasa < 1000 then raise exception 'Zapošljavanje bota košta 1.000 iz kase' using errcode = '22023'; end if;
  update karijera_firme set kasa = kasa - 1000 where id = f.id;
  perform karijera_novi_bot(f.id, p_tema);
  return karijera_firma(p_firma);
end $$;

create or replace function karijera_obuci_bota(p_bot uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare b karijera_botovi; f karijera_firme; cena numeric;
begin
  select * into b from karijera_botovi where id = p_bot;
  if not found then raise exception 'Bot ne postoji' using errcode = 'P0002'; end if;
  f := karijera_moja_firma(b.firma_id);
  if b.nivo >= 90 then raise exception 'Bot je već na najvišem nivou' using errcode = '22023'; end if;
  cena := case b.nivo when 60 then 3000 else 8000 end;
  if f.kasa < cena then raise exception 'Obuka košta % iz kase', cena using errcode = '22023'; end if;
  update karijera_firme set kasa = kasa - cena where id = f.id;
  update karijera_botovi set nivo = case nivo when 60 then 75 else 90 end where id = b.id;
  return karijera_firma(f.id);
end $$;

create or replace function karijera_nadogradi(p_firma uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare f karijera_firme := karijera_moja_firma(p_firma); aktivnih int; cena numeric;
begin
  if f.nivo >= 5 then raise exception 'Neboder je najviši nivo' using errcode = '22023'; end if;
  cena := karijera_cena_nivoa(f.nivo + 1);
  select count(distinct r.user_id) into aktivnih from karijera_runde r where r.firma_id = f.id and r.user_id <> f.vlasnik and r.dan > karijera_danas() - 7;
  if aktivnih < karijera_min_zaposlenih(f.nivo + 1) then
    raise exception 'Za sledeći nivo treba % aktivnih zaposlenih u 7 dana (sada %)', karijera_min_zaposlenih(f.nivo + 1), aktivnih using errcode = '22023';
  end if;
  if f.kasa < cena then raise exception 'Nadogradnja košta % iz kase', cena using errcode = '22023'; end if;
  update karijera_firme set kasa = kasa - cena, nivo = nivo + 1 where id = f.id;
  perform karijera_dogadjaj(f.vlasnik, 'nadogradnja', karijera_ime_firme(f) || ': nova zgrada, nivo ' || (f.nivo + 1) || '.');
  return karijera_firma(p_firma);
end $$;

create or replace function karijera_dividenda(p_firma uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare f karijera_firme := karijera_moja_firma(p_firma); iznos numeric;
begin
  if f.dividenda_dan = karijera_danas() then raise exception 'Dividenda je već podignuta danas' using errcode = '22023'; end if;
  iznos := round(f.kasa * 0.10, 2);
  if iznos <= 0 then raise exception 'Kasa je prazna' using errcode = '22023'; end if;
  update karijera_firme set kasa = kasa - iznos, dividenda_dan = karijera_danas() where id = f.id;
  update karijera_igraci set kapital = kapital + iznos where user_id = f.vlasnik;
  return karijera_firma(p_firma);
end $$;

create or replace function karijera_otpusti(p_firma uuid, p_igrac uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare f karijera_firme := karijera_moja_firma(p_firma);
begin
  if exists (select 1 from karijera_izazovi where firma_id = f.id and izazivac = p_igrac and stanje <> 'gotov') then
    raise exception 'Izazivač ne može biti otpušten dok duel traje' using errcode = '22023';
  end if;
  update karijera_igraci set firma_id = karijera_korporacija(), zaposlen_od = now() where user_id = p_igrac and firma_id = f.id;
  perform karijera_dogadjaj(p_igrac, 'otpusten', 'Otpušten iz firme ' || karijera_ime_firme(f) || '.');
  return karijera_firma(p_firma);
end $$;

create or replace function karijera_odmor(p_dana int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare ja karijera_igraci := karijera_ja(); mesec text := to_char(karijera_danas(), 'YYYY-MM'); iskorisceno int;
begin
  if p_dana not between 1 and 3 then raise exception 'Odmor je 1 do 3 dana' using errcode = '22023'; end if;
  iskorisceno := case when ja.odmor_mesec = mesec then ja.odmor_iskorisceno else 0 end;
  if iskorisceno + p_dana > 3 then raise exception 'Ovog meseca imaš još % dana odmora', 3 - iskorisceno using errcode = '22023'; end if;
  update karijera_igraci set odmor_mesec = mesec, odmor_iskorisceno = iskorisceno + p_dana,
    odmor_do = greatest(coalesce(odmor_do, karijera_danas()), karijera_danas()) + p_dana
  where user_id = ja.user_id;
  return karijera_stanje();
end $$;

-- ============ Berza poslova ============

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
    'zastita_do', f.zastita_do)
$$;

create or replace function karijera_berza(p_pozicija text default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(karijera_firma_red(f) order by f.korporacija desc, f.nivo desc, f.rekord desc), '[]')
  from (select * from karijera_firme f where not f.zatvorena and (p_pozicija is null or f.pozicija = p_pozicija or f.korporacija)
        order by f.korporacija desc, f.nivo desc, f.rekord desc limit 100) f
$$;

create or replace function karijera_zaposli_se(p_firma uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare ja karijera_igraci := karijera_ja(); f karijera_firme; mesta int;
begin
  select * into f from karijera_firme where id = p_firma and not zatvorena;
  if f is null then raise exception 'Ta firma više ne radi' using errcode = 'P0002'; end if;
  if f.vlasnik = ja.user_id then raise exception 'U svojoj firmi si vlasnik' using errcode = '22023'; end if;
  if not f.korporacija and ja.probni_ishod is null then raise exception 'Prvo završi probni rad u Korporaciji' using errcode = '22023'; end if;
  mesta := (array[3, 10, 25, 60, 150])[f.nivo];
  if not f.korporacija and (select count(*) from karijera_igraci where firma_id = f.id) >= mesta then
    raise exception 'Firma nema slobodnih mesta' using errcode = '22023';
  end if;
  update karijera_igraci set firma_id = f.id, zaposlen_od = now() where user_id = ja.user_id;
  if not f.korporacija then
    perform karijera_dogadjaj(ja.user_id, 'zaposlen', 'Zaposlio se u firmi ' || karijera_ime_firme(f) || '.');
  end if;
  return karijera_stanje();
end $$;

-- ============ Pomoć bota ============

-- Bot u svojoj temi predlaže odgovor; tačan je sa verovatnoćom svog nivoa. U duelu samo vlasniku, 2 po botu.
create or replace function karijera_bot_pomoc(p_firma uuid, p_pitanje uuid, p_izazov uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  ja karijera_igraci := karijera_ja(); f karijera_firme; q record; b karijera_botovi; i karijera_izazovi;
  izbor int; tacno boolean; sigurnost int; dozvoljeno int; iskorisceno int; danas date := karijera_danas(); nasao boolean := false;
begin
  select qq.correct_answer, qq.tags into q from questions qq where qq.id = p_pitanje;
  if not found then raise exception 'Nepoznato pitanje' using errcode = 'P0002'; end if;
  if p_izazov is not null then
    select * into i from karijera_izazovi where id = p_izazov for update;
    if not found or i.vlasnik is distinct from ja.user_id or i.stanje <> 'u_toku' then raise exception 'Botovi pomažu samo vlasniku u duelu' using errcode = '42501'; end if;
    if not p_pitanje = any(i.pitanja) then raise exception 'Pitanje nije iz ovog duela' using errcode = '22023'; end if;
    p_firma := i.firma_id;
  else
    f := karijera_pristup(p_firma, ja);
  end if;

  for b in select * from karijera_botovi where firma_id = p_firma and tema = any(q.tags) order by nivo desc, zaposlen loop
    if p_izazov is not null then
      -- 1. pokušaj svi botovi, 2. jedan (najbolji), 3.+ nijedan.
      dozvoljeno := case when i.botova = 0 then 0 else 2 end;
      iskorisceno := coalesce((i.bot_pomoci->>b.id::text)::int, 0);
      -- Bot koji je već pomagao sme opet; nov bot samo dok ima mesta u broju dozvoljenih botova.
      if iskorisceno < dozvoljeno and (i.bot_pomoci ? b.id::text or (select count(*) from jsonb_object_keys(i.bot_pomoci)) < i.botova) then
        update karijera_izazovi set bot_pomoci = bot_pomoci || jsonb_build_object(b.id::text, iskorisceno + 1) where id = i.id;
        nasao := true; exit;
      end if;
    else
      iskorisceno := case when b.pomoci_dan = danas then b.pomoci_iskorisceno else 0 end;
      if iskorisceno < 5 then
        update karijera_botovi set pomoci_dan = danas, pomoci_iskorisceno = iskorisceno + 1 where id = b.id;
        nasao := true; exit;
      end if;
    end if;
  end loop;
  if not nasao then raise exception 'Nijedan bot ne zna ovu temu ili su potrošili pomoći' using errcode = '22023'; end if;

  tacno := random() * 100 < b.nivo;
  izbor := case when tacno then q.correct_answer else ((q.correct_answer + 1 + floor(random() * 3)::int) % 4) end;
  sigurnost := case when tacno then least(99, b.nivo - 10 + floor(random() * 19)::int) else 40 + floor(random() * (b.nivo - 40))::int end;
  return jsonb_build_object('bot', b.ime, 'tema', b.tema, 'izbor', izbor, 'sigurnost', sigurnost);
end $$;

-- ============ Izazov i duel za firmu ============

create or replace function karijera_prenesi(i karijera_izazovi, p_razlog text) returns void
language plpgsql security definer set search_path = public as $$
declare f karijera_firme; otpremnina numeric;
begin
  select * into f from karijera_firme where id = i.firma_id for update;
  otpremnina := case when f.vlasnik is null then 0 else round(f.kasa * 0.2, 2) end;
  update karijera_firme set vlasnik = i.izazivac, npc_ime = null, kasa = kasa - otpremnina, vlasnik_od = now(),
    zastita_do = now() + interval '5 days', poslednji_ulazak = karijera_danas(), obracunato = karijera_danas(),
    otkaza_od_ulaska = 0, rekord_igrac = i.izazivac, rekord_ime = karijera_nadimak(i.izazivac)
  where id = f.id;
  update karijera_igraci set firma_id = null where user_id = i.izazivac and firma_id = f.id;
  if f.vlasnik is not null then
    update karijera_igraci set kapital = kapital + otpremnina, bivsi_vlasnik = true where user_id = f.vlasnik;
    perform karijera_dogadjaj(f.vlasnik, 'izgubio', karijera_nadimak(i.izazivac) || ' je preuzeo ' || karijera_ime_firme(f) || ' (' || p_razlog || '). Otpremnina ' || otpremnina || '.');
  end if;
  perform karijera_dogadjaj(i.izazivac, 'preuzeo', 'Preuzeo ' || karijera_ime_firme(f) || ' od ' || case when f.vlasnik is null then coalesce(f.npc_ime, 'Uprave') else karijera_nadimak(f.vlasnik) end || '.');
end $$;

create or replace function karijera_resi_duel(p_izazov uuid) returns void
language plpgsql security definer set search_path = public as $$
declare i karijera_izazovi; pobedio_izazivac boolean; razlog text;
begin
  select * into i from karijera_izazovi where id = p_izazov for update;
  if i.stanje = 'gotov' then return; end if;
  if i.izazivac_tacnih is null and i.vlasnik_tacnih is null then pobedio_izazivac := false; razlog := 'niko nije odigrao';
  elsif i.izazivac_tacnih is null then pobedio_izazivac := false; razlog := 'izazivač nije odigrao';
  elsif i.vlasnik_tacnih is null then pobedio_izazivac := true; razlog := 'vlasnik nije odigrao duel';
  elsif i.izazivac_tacnih <> i.vlasnik_tacnih then pobedio_izazivac := i.izazivac_tacnih > i.vlasnik_tacnih; razlog := i.izazivac_tacnih || ':' || i.vlasnik_tacnih;
  else pobedio_izazivac := i.izazivac_ms < i.vlasnik_ms; razlog := i.izazivac_tacnih || ':' || i.vlasnik_tacnih || ', odlučilo vreme';
  end if;
  update karijera_izazovi set stanje = 'gotov', zavrsen = now(), ishod = razlog,
    pobednik = case when pobedio_izazivac then izazivac else vlasnik end where id = i.id;
  if pobedio_izazivac then
    perform karijera_prenesi(i, razlog);
  else
    update karijera_firme set zastita_do = now() + interval '5 days' where id = i.firma_id;
    perform karijera_dogadjaj(i.vlasnik, 'odbranio', 'Odbranio firmu od ' || karijera_nadimak(i.izazivac) || ' (' || razlog || ').');
    perform karijera_dogadjaj(i.izazivac, 'duel', 'Izgubio duel za firmu (' || razlog || ').');
  end if;
end $$;

-- Lenjo rešavanje isteklih rokova (bez crona).
create or replace function karijera_obradi_izazove() returns void
language plpgsql security definer set search_path = public as $$
declare i karijera_izazovi;
begin
  for i in select * from karijera_izazovi where stanje <> 'gotov' and rok < now()
           and (vlasnik = auth.uid() or izazivac = auth.uid()) for update skip locked loop
    if i.stanje = 'ceka' then
      update karijera_izazovi set stanje = 'gotov', zavrsen = now(), pobednik = izazivac, ishod = 'vlasnik nije odgovorio za 24 h' where id = i.id;
      perform karijera_prenesi(i, 'vlasnik nije odgovorio za 24 h');
    else
      perform karijera_resi_duel(i.id);
    end if;
  end loop;
end $$;

create or replace function karijera_teme_firme(p_firma uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  with f as (select * from karijera_firme where id = p_firma),
  teme as (select distinct unnest(p.teme || f.kljucne) t from f join karijera_pozicije p on p.id = f.pozicija),
  broj as (select t.t, (select count(*) from questions q where q.is_active and t.t = any(q.tags)) n from teme t)
  select coalesce(jsonb_agg(jsonb_build_object('tema', b.t, 'pitanja', b.n) order by b.t), '[]') from broj b where b.n >= 10
$$;

create or replace function karijera_pitanja_teme(p_tema text, p_bez uuid[]) returns uuid[]
language sql volatile security definer set search_path = public as $$
  select array(select q.id from questions q where q.is_active and jsonb_array_length(q.options) = 4 and p_tema = any(q.tags)
    and not (q.id = any(p_bez)) order by random() limit 10)
$$;

create or replace function karijera_postavi_duel(p_izazov uuid, p_tema1 text, p_tema3 text) returns void
language plpgsql security definer set search_path = public as $$
declare p1 uuid[]; p2 uuid[]; p3 uuid[]; i karijera_izazovi;
begin
  select * into i from karijera_izazovi where id = p_izazov;
  p1 := karijera_pitanja_teme(p_tema1, '{}');
  p2 := karijera_pitanja_teme(i.tema_izazivac, p1);
  p3 := karijera_pitanja_teme(p_tema3, p1 || p2);
  if coalesce(array_length(p1,1),0) + coalesce(array_length(p2,1),0) + coalesce(array_length(p3,1),0) < 30 then
    raise exception 'Za izabrane teme nema dovoljno pitanja' using errcode = '22023';
  end if;
  update karijera_izazovi set tema1 = p_tema1, tema3 = p_tema3, pitanja = p1 || p2 || p3, stanje = 'u_toku', rok = now() + interval '24 hours'
  where id = p_izazov;
end $$;

create or replace function karijera_posalji_izazov(p_firma uuid, p_tema text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  ja karijera_igraci := karijera_ja(); f karijera_firme; pokusaj int; revans boolean := false; botova int;
  nov uuid; teme jsonb; t1 text; t3 text; mojih int;
begin
  perform karijera_obradi_izazove();
  select * into f from karijera_firme where id = p_firma and not zatvorena and not korporacija;
  if f is null then raise exception 'Ova firma se ne može preuzeti' using errcode = 'P0002'; end if;
  if f.vlasnik = ja.user_id then raise exception 'Ovo je tvoja firma' using errcode = '22023'; end if;
  if not exists (select 1 from jsonb_array_elements(karijera_teme_firme(f.id)) x where x->>'tema' = p_tema) then
    raise exception 'Izaberi temu koju ova firma ima' using errcode = '22023';
  end if;
  select count(*) into mojih from karijera_firme where vlasnik = ja.user_id and not zatvorena;
  if mojih >= karijera_slotova(ja.ugled) then raise exception 'Nemaš slobodno mesto za još jednu firmu' using errcode = '22023'; end if;
  if exists (select 1 from karijera_izazovi where firma_id = f.id and stanje <> 'gotov') then raise exception 'Ova firma već ima izazov u toku' using errcode = '22023'; end if;
  -- Revanš: bivši vlasnik u 14 dana, bez rekorda i bez zaposlenja.
  revans := exists (select 1 from karijera_izazovi z where z.firma_id = f.id and z.vlasnik = ja.user_id and z.stanje = 'gotov'
    and z.pobednik = f.vlasnik and z.zavrsen > now() - interval '14 days')
    and not exists (select 1 from karijera_izazovi z where z.firma_id = f.id and z.izazivac = ja.user_id and z.revans and z.kad > now() - interval '14 days');
  if not revans then
    if f.zastita_do > now() then raise exception 'Firma je zaštićena još %', to_char(f.zastita_do - now(), 'FMDD "dana" FMHH24 "h"') using errcode = '22023'; end if;
    if ja.firma_id is distinct from f.id or ja.zaposlen_od > now() - interval '3 days' then raise exception 'Izazov šalje zaposleni koji je u firmi bar 3 dana' using errcode = '22023'; end if;
    if f.rekord_igrac is distinct from ja.user_id then raise exception 'Prvo obori rekord firme' using errcode = '22023'; end if;
    if exists (select 1 from karijera_izazovi z where z.firma_id = f.id and z.izazivac = ja.user_id and z.kad > now() - interval '5 days') then
      raise exception 'Između dva izazova iste firme čeka se 5 dana' using errcode = '22023';
    end if;
  end if;
  select count(*) + 1 into pokusaj from karijera_izazovi z where z.firma_id = f.id and z.izazivac = ja.user_id
    and z.vlasnik is not distinct from f.vlasnik and z.kad >= f.vlasnik_od;
  if revans then pokusaj := 1; end if;
  botova := case when pokusaj = 1 then 99 when pokusaj = 2 then 1 else 0 end;
  insert into karijera_izazovi (firma_id, vlasnik, izazivac, pokusaj, revans, tema_izazivac, botova)
  values (f.id, f.vlasnik, ja.user_id, pokusaj, revans, p_tema, botova) returning id into nov;

  if f.vlasnik is null then
    -- NPC odmah prihvata: njegove teme su prve dve ključne oblasti (ili nasumične).
    select jsonb_agg(x->>'tema' order by random()) into teme from jsonb_array_elements(karijera_teme_firme(f.id)) x where x->>'tema' <> p_tema;
    t1 := teme->>0; t3 := coalesce(teme->>1, teme->>0);
    perform karijera_postavi_duel(nov, t1, t3);
    -- NPC rezultat zavisi od nivoa firme: oko 50% tačnih na garaži, oko 75% na neboderu.
    update karijera_izazovi set vlasnik_tacnih = least(30, round(30 * (0.43 + 0.065 * f.nivo + random() * 0.08))::int), vlasnik_ms = 30 * 9000 where id = nov;
  else
    perform karijera_dogadjaj(f.vlasnik, 'izazov', karijera_nadimak(ja.user_id) || ' traži preuzimanje firme ' || karijera_ime_firme(f) || '. Imaš 24 h da prihvatiš duel.');
  end if;
  return karijera_izazov(nov);
end $$;

create or replace function karijera_prihvati_izazov(p_izazov uuid, p_tema1 text, p_tema3 text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare i karijera_izazovi;
begin
  perform karijera_obradi_izazove();
  select * into i from karijera_izazovi where id = p_izazov and vlasnik = auth.uid() and stanje = 'ceka' for update;
  if i is null then raise exception 'Izazov više ne čeka odgovor' using errcode = 'P0002'; end if;
  if p_tema1 = i.tema_izazivac or (i.pokusaj < 4 and p_tema3 in (i.tema_izazivac, p_tema1)) then
    raise exception 'Ista tema se ne bira dvaput' using errcode = '22023';
  end if;
  -- Od 4. pokušaja treća tema je nasumična.
  if i.pokusaj >= 4 then
    select x->>'tema' into p_tema3 from jsonb_array_elements(karijera_teme_firme(i.firma_id)) x
    where x->>'tema' not in (i.tema_izazivac, p_tema1) order by random() limit 1;
  end if;
  perform karijera_postavi_duel(p_izazov, p_tema1, p_tema3);
  perform karijera_dogadjaj(i.izazivac, 'izazov', 'Vlasnik je prihvatio duel. Imaš 24 h da ga odigraš.');
  return karijera_izazov(p_izazov);
end $$;

create or replace function karijera_izazov(p_izazov uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', i.id, 'firma', karijera_firma_red(f), 'vlasnik', i.vlasnik,
    'vlasnik_ime', case when i.vlasnik is null then coalesce(f.npc_ime, 'Uprava') else karijera_nadimak(i.vlasnik) end,
    'izazivac', i.izazivac, 'izazivac_ime', karijera_nadimak(i.izazivac), 'pokusaj', i.pokusaj, 'revans', i.revans,
    'tema_izazivac', i.tema_izazivac, 'tema1', i.tema1, 'tema3', i.tema3, 'botova', i.botova, 'stanje', i.stanje, 'rok', i.rok,
    'ja_odigrao', case when auth.uid() = i.izazivac then i.izazivac_tacnih is not null when auth.uid() = i.vlasnik then i.vlasnik_tacnih is not null end,
    'vlasnik_tacnih', case when i.stanje = 'gotov' then i.vlasnik_tacnih end,
    'izazivac_tacnih', case when i.stanje = 'gotov' then i.izazivac_tacnih end,
    'pobednik', i.pobednik, 'ishod', i.ishod, 'kad', i.kad)
  from karijera_izazovi i join karijera_firme f on f.id = i.firma_id where i.id = p_izazov
$$;

create or replace function karijera_duel_pitanja(p_izazov uuid)
returns table (id uuid, question_text text, options jsonb, correct_answer int, tema text, runda int)
language plpgsql security definer set search_path = public as $$
declare i karijera_izazovi;
begin
  select * into i from karijera_izazovi z where z.id = p_izazov and z.stanje = 'u_toku' and auth.uid() in (z.vlasnik, z.izazivac);
  if i is null then raise exception 'Duel nije u toku' using errcode = 'P0002'; end if;
  return query select q.id, q.question_text, q.options, q.correct_answer::int,
    case when x.n <= 10 then i.tema1 when x.n <= 20 then i.tema_izazivac else i.tema3 end,
    ((x.n - 1) / 10 + 1)::int
  from unnest(i.pitanja) with ordinality x(pid, n) join questions q on q.id = x.pid order by x.n;
end $$;

-- p_odgovori: [{"id": uuid, "izbor": int, "ms": int}] za svih 30.
create or replace function karijera_duel_predaj(p_izazov uuid, p_odgovori jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare i karijera_izazovi; tacnih int; ms int;
begin
  select * into i from karijera_izazovi z where z.id = p_izazov and z.stanje = 'u_toku' and auth.uid() in (z.vlasnik, z.izazivac) for update;
  if i is null then raise exception 'Duel nije u toku' using errcode = 'P0002'; end if;
  select count(*) filter (where (o->>'izbor')::int = q.correct_answer), coalesce(sum(least(20000, greatest(0, (o->>'ms')::int))), 0)
    into tacnih, ms
  from jsonb_array_elements(p_odgovori) o join questions q on q.id = (o->>'id')::uuid and q.id = any(i.pitanja);
  if auth.uid() = i.izazivac then
    if i.izazivac_tacnih is not null then raise exception 'Duel je već odigran' using errcode = '22023'; end if;
    update karijera_izazovi set izazivac_tacnih = tacnih, izazivac_ms = ms where id = i.id returning * into i;
  else
    if i.vlasnik_tacnih is not null then raise exception 'Duel je već odigran' using errcode = '22023'; end if;
    update karijera_izazovi set vlasnik_tacnih = tacnih, vlasnik_ms = ms where id = i.id returning * into i;
  end if;
  if i.izazivac_tacnih is not null and i.vlasnik_tacnih is not null then perform karijera_resi_duel(i.id); end if;
  return karijera_izazov(p_izazov) || jsonb_build_object('moji_tacni', tacnih);
end $$;

-- ============ Pregled firme, stanje, CV, rang ============

create or replace function karijera_firma(p_firma uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare f karijera_firme; vlasnik boolean;
begin
  select * into f from karijera_firme where id = p_firma;
  if f is null then raise exception 'Firma ne postoji' using errcode = 'P0002'; end if;
  vlasnik := f.vlasnik = auth.uid();
  return karijera_firma_red(f) || jsonb_build_object(
    'ja_vlasnik', vlasnik,
    'kasa', case when vlasnik then f.kasa end,
    'odrzavanje', 40 * f.nivo + 25 * (select count(*) from karijera_botovi where firma_id = f.id),
    'dividenda_danas', f.dividenda_dan = karijera_danas(),
    'udeo_menjan', f.udeo_menjan,
    'cena_nadogradnje', case when f.nivo < 5 then karijera_cena_nivoa(f.nivo + 1) end,
    'treba_zaposlenih', case when f.nivo < 5 then karijera_min_zaposlenih(f.nivo + 1) end,
    'aktivnih', (select count(distinct r.user_id) from karijera_runde r where r.firma_id = f.id and r.user_id is distinct from f.vlasnik and r.dan > karijera_danas() - 7),
    'poslednji_ulazak', f.poslednji_ulazak,
    'zatvorena', f.zatvorena,
    'botovi', (select coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'ime', b.ime, 'tema', b.tema, 'nivo', b.nivo,
        'pomoci_ostalo', 5 - case when b.pomoci_dan = karijera_danas() then b.pomoci_iskorisceno else 0 end) order by b.zaposlen), '[]')
      from karijera_botovi b where b.firma_id = f.id),
    'zaposleni', (select coalesce(jsonb_agg(jsonb_build_object('id', i.user_id, 'ime', karijera_nadimak(i.user_id),
        'titula', karijera_titula(i.ugled), 'od', i.zaposlen_od) order by i.zaposlen_od), '[]')
      from karijera_igraci i where i.firma_id = f.id and not f.korporacija),
    'izazovi', (select coalesce(jsonb_agg(karijera_izazov(z.id) order by z.kad desc), '[]')
      from (select id, kad from karijera_izazovi where firma_id = f.id order by kad desc limit 10) z),
    'teme', karijera_teme_firme(f.id));
end $$;

create or replace function karijera_stanje() returns jsonb
language plpgsql security definer set search_path = public as $$
declare ja karijera_igraci := karijera_ja(); fid uuid; placenih int; danas date := karijera_danas(); korp_dana int;
begin
  for fid in select id from karijera_firme where vlasnik = ja.user_id and not zatvorena loop perform karijera_odrzi(fid); end loop;
  perform karijera_obradi_izazove();
  select * into ja from karijera_igraci where user_id = ja.user_id;
  select count(*) into placenih from karijera_runde where user_id = ja.user_id and dan = danas and placeno;
  select count(distinct dan) into korp_dana from karijera_runde where user_id = ja.user_id and firma_id = karijera_korporacija() and dan > coalesce(ja.probni_kraj, '1900-01-01');
  return jsonb_build_object(
    'pozicija', ja.pozicija, 'kapital', ja.kapital, 'ugled', ja.ugled, 'titula', karijera_titula(ja.ugled),
    'nivo_ugleda', ja.ugled / 1000 + 1, 'slotova', karijera_slotova(ja.ugled),
    'placenih_danas', placenih, 'placenih_max', 10,
    'probni', jsonb_build_object('runde', ja.probni_runde, 'cilj', ja.probni_cilj, 'tacnih', ja.probni_tacnih, 'ishod', ja.probni_ishod,
      'danas', (select count(*) from karijera_runde r where r.user_id = ja.user_id and r.dan = danas and r.firma_id = karijera_korporacija()),
      'korporacija_dana', korp_dana, 'bivsi_vlasnik', ja.bivsi_vlasnik),
    'office_pravo', ja.office_pravo,
    'odmor_do', ja.odmor_do, 'odmor_ostalo', 3 - case when ja.odmor_mesec = to_char(danas, 'YYYY-MM') then ja.odmor_iskorisceno else 0 end,
    'posao', case when ja.firma_id is not null then (select karijera_firma_red(f) from karijera_firme f where f.id = ja.firma_id) end,
    'zaposlen_od', ja.zaposlen_od,
    'firme', (select coalesce(jsonb_agg(karijera_firma(f.id) order by f.osnovana), '[]') from karijera_firme f where f.vlasnik = ja.user_id and not f.zatvorena),
    'moji_izazovi', (select coalesce(jsonb_agg(karijera_izazov(z.id) order by z.kad desc), '[]')
      from (select id, kad from karijera_izazovi where izazivac = ja.user_id and (stanje <> 'gotov' or zavrsen > now() - interval '3 days') order by kad desc limit 10) z),
    'korporacija', karijera_korporacija(),
    'prefiksi', to_jsonb(karijera_prefiksi()), 'oblici', to_jsonb(array_remove(karijera_oblici(), 'holding')),
    'pozicije', (select jsonb_agg(jsonb_build_object('id', p.id, 'naziv', p.naziv, 'opis', p.opis, 'oblast', p.oblast, 'ikonica', p.ikonica, 'teme', p.teme) order by p.redosled) from karijera_pozicije p));
end $$;

create or replace function karijera_cv(p_igrac uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare k uuid := coalesce(p_igrac, auth.uid()); ja karijera_igraci;
begin
  select * into ja from karijera_igraci where user_id = k;
  if ja is null then raise exception 'Igrač još nije počeo karijeru' using errcode = 'P0002'; end if;
  return jsonb_build_object('id', k, 'ime', karijera_nadimak(k),
    'avatar', (select avatar from public_profiles where id = k),
    'pozicija', (select naziv from karijera_pozicije where id = ja.pozicija),
    'titula', karijera_titula(ja.ugled), 'ugled', ja.ugled, 'kapital', ja.kapital,
    'neto', ja.kapital + coalesce((select sum(f.kasa + karijera_vrednost_zgrade(f.nivo)) from karijera_firme f where f.vlasnik = k and not f.zatvorena), 0),
    'posao', (select karijera_firma_red(f) from karijera_firme f where f.id = ja.firma_id),
    'firme', (select coalesce(jsonb_agg(karijera_firma_red(f) order by f.nivo desc), '[]') from karijera_firme f where f.vlasnik = k and not f.zatvorena),
    'ekspertiza', (select coalesce(jsonb_agg(jsonb_build_object('tema', e.tema, 'ocena', e.ocena) order by e.ocena desc), '[]')
      from (select * from karijera_ekspertiza where user_id = k and ocena > 0 order by ocena desc limit 8) e),
    'odbrana', (select count(*) from karijera_izazovi where vlasnik = k and stanje = 'gotov' and pobednik = k),
    'preuzimanja', (select count(*) from karijera_izazovi where izazivac = k and stanje = 'gotov' and pobednik = k),
    'tacnih', (select coalesce(sum(tacnih), 0) from karijera_runde where user_id = k),
    'rundi', (select count(*) from karijera_runde where user_id = k),
    'dogadjaji', (select coalesce(jsonb_agg(jsonb_build_object('vrsta', d.vrsta, 'tekst', d.tekst, 'kad', d.kad) order by d.kad desc), '[]')
      from (select * from karijera_dogadjaji where user_id = k order by kad desc limit 30) d));
end $$;

-- p_vrsta: neto | firme | sezona (poeni u tekućem tromesečju).
create or replace function karijera_rang(p_vrsta text default 'neto') returns jsonb
language sql stable security definer set search_path = public as $$
  with redovi as (
    select i.user_id, karijera_nadimak(i.user_id) as ime,
      case p_vrsta
        when 'firme' then coalesce((select sum((select count(*) from karijera_igraci z where z.firma_id = f.id)) from karijera_firme f where f.vlasnik = i.user_id and not f.zatvorena), 0)
        when 'sezona' then coalesce((select sum(r.poeni) from karijera_runde r where r.user_id = i.user_id and r.dan >= date_trunc('quarter', karijera_danas())::date), 0)
        else i.kapital + coalesce((select sum(f.kasa + karijera_vrednost_zgrade(f.nivo)) from karijera_firme f where f.vlasnik = i.user_id and not f.zatvorena), 0)
      end as vrednost,
      (select naziv from karijera_pozicije where id = i.pozicija) as pozicija
    from karijera_igraci i where i.pozicija is not null
  )
  select coalesce(jsonb_agg(jsonb_build_object('id', user_id, 'ime', ime, 'vrednost', vrednost, 'pozicija', pozicija) order by vrednost desc), '[]')
  from (select * from redovi where vrednost > 0 order by vrednost desc limit 50) x
$$;

-- ============ Korporacija i NPC firme ============

insert into karijera_firme (korporacija, pozicija, ime_prefiks, ime_oblik, nivo, stil, npc_ime, zastita_do)
select true, 'marketing', 'Korporacija', 'd.o.o.', 5, 1, 'Šef', 'infinity'
where not exists (select 1 from karijera_firme where korporacija);

-- Po dve NPC firme za svaku poziciju, različitih nivoa, sa botovima i rekordom koji se može oboriti.
insert into karijera_firme (pozicija, ime_prefiks, ime_oblik, nivo, stil, npc_ime, kasa, kljucne, rekord, rekord_ime, zastita_do)
select p.id,
  (karijera_prefiksi())[1 + ((p.redosled * 7 + kk.k * 31) % array_length(karijera_prefiksi(), 1))],
  (array['d.o.o.','grupa','studio','biro'])[1 + ((p.redosled + kk.k) % 4)],
  n.nivo, 1 + ((p.redosled + kk.k) % 3),
  (array['Dragan Pešić','Milica Ranković','Zoran Lukić','Jelena Stanković','Nenad Ilić','Vesna Marić','Goran Simić','Tamara Jović',
         'Bojan Pavić','Ivana Krstić','Saša Đurić','Marija Tomić','Dejan Vasić','Snežana Kovač','Aleksandar Rajić','Gordana Lazić',
         'Miloš Petrović','Danijela Nikolić','Vladimir Savić','Katarina Ristić'])[1 + ((p.redosled * 2 + kk.k) % 20)],
  n.nivo * 1500, (select array(select unnest(p.teme) limit 3)), 300 + n.nivo * 250, 'Uprava', now()
from karijera_pozicije p cross join (values (0), (1)) as kk(k)
cross join lateral (select case when kk.k = 0 then 1 + (p.redosled % 2) else 2 + (p.redosled % 3) end as nivo) n
where not exists (select 1 from karijera_firme where vlasnik is null and not korporacija);

insert into karijera_botovi (firma_id, ime, tema, nivo)
select f.id, (karijera_imena_botova())[1 + (abs(hashtext(f.id::text || s.i::text)) % 20)], (select p.teme[1 + s.i] from karijera_pozicije p where p.id = f.pozicija),
  (array[60, 75, 90])[least(3, 1 + f.nivo / 2)]
from karijera_firme f cross join generate_series(0, 4) s(i)
where f.vlasnik is null and not f.korporacija and s.i < f.nivo
  and not exists (select 1 from karijera_botovi b where b.firma_id = f.id);
