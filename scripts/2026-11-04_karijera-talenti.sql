-- Karijera: pol, 20 talenata (bira se 3), zamena talenta na svakih 200 tačnih (vlasnik 04.11). PRIMENJENO 04.11.
-- Serverski talenti se primenjuju u karijera_zavrsi_rundu, karijera_odrzi i karijera_bot_pomoc; ostale primenjuje aplikacija.
-- Napomena: u plpgsql „if x < case … then … end then” puca (čita do prvog then) — case u uslovu ide u zagrade.

alter table karijera_igraci add column if not exists pol text check (pol in ('m','z'));
alter table karijera_igraci add column if not exists talenti text[] not null default '{}';
alter table karijera_igraci add column if not exists zamena_talenta int not null default 0;
alter table karijera_pozicije add column if not exists naziv_z text;

update karijera_pozicije set naziv_z = v.n from (values
 ('marketing','Marketing menadžerka'),('novinar','Novinarka'),('advokat','Advokatica'),('lekar','Lekarka'),('inzenjer','Inženjerka'),
 ('programer','Programerka'),('bankar','Bankarka'),('istoricar','Istoričarka'),('izdavac','Izdavačica'),('kustos','Kustoskinja muzeja'),
 ('muzicki','Muzička producentkinja'),('filmski','Filmska producentkinja'),('turizam','Turistička menadžerka'),('diplomata','Diplomatkinja'),
 ('kuvar','Šefica kuhinje'),('naucnik','Naučnica'),('veterinar','Veterinarka'),('psiholog','Psihološkinja'),('sportski','Sportska menadžerka'),('moda','Modna dizajnerka')
) v(id, n) where karijera_pozicije.id = v.id;

create table if not exists karijera_talenti (
  id text primary key, naziv text not null, opis text not null, ikonica text not null, gde text not null check (gde in ('server','aplikacija')), redosled int not null
);
alter table karijera_talenti enable row level security;
insert into karijera_talenti (id, naziv, opis, ikonica, gde, redosled) values
 ('pregovarac','Pregovarač','+10% na svaku platu.','banknote','server',1),
 ('stedisa','Štediša','Održavanje tvoje firme je 25% jeftinije.','dollarsign.arrow.circlepath','server',2),
 ('lider','Lider','Tvoje firme dobijaju +10% prometa od svih zaposlenih.','person.3.sequence','server',3),
 ('maratonac','Maratonac','Bonus niza kreće od 3. tačnog zaredom, ne od 5.','figure.run','server',4),
 ('brzinac','Brzinac','Bonus brzine važi do 8 sekundi, ne do 5.','hare','server',5),
 ('strucnjak','Stručnjak','Ključne oblasti firme vrede ×2,5 umesto ×2.','star.circle','server',6),
 ('svestran','Svestran','Pitanja van struke vrede +25%.','circle.hexagongrid','server',7),
 ('upornost','Upornost','+25% ugleda iz svake runde.','rosette','server',8),
 ('druga_sansa','Druga šansa','Jedna greška po rundi ne prekida niz.','arrow.uturn.backward','server',9),
 ('mentor','Mentor','Tvoji asistenti su 10% tačniji.','graduationcap','server',10),
 ('neumorni','Neumorni tim','Svaki tvoj asistent pomaže 3 puta više dnevno.','bolt.horizontal','server',11),
 ('ekspert','Ekspert','Ekspertiza raste 50% brže.','brain','server',12),
 ('probni_as','Rođeni talenat','Probni rad: 5% niži pragovi (55/70/85%).','sparkles','server',13),
 ('branilac','Branilac','U odbrani firme svaki asistent pomaže 3 puta, ne 2.','shield','server',14),
 ('brz_um','Brz um','+5 sekundi na svako pitanje.','timer','aplikacija',15),
 ('kolega_plus','Dobar kolega','Pomoć kolege dvaput po rundi.','person.2','aplikacija',16),
 ('istrazivac','Istraživač','Guglanje traje 3 s i uvek nađe tačan odgovor.','magnifyingglass','aplikacija',17),
 ('intuicija','Intuicija','Asistent iz aplikacije pogađa u 85% slučajeva.','wand.and.stars','aplikacija',18),
 ('prvi_utisak','Prvi utisak','Prvo pitanje svake runde dobija besplatno pola-pola.','hand.thumbsup','aplikacija',19),
 ('duelista','Duelista','U duelu za firmu imaš i asistenta iz aplikacije.','figure.fencing','aplikacija',20)
on conflict (id) do update set naziv = excluded.naziv, opis = excluded.opis, ikonica = excluded.ikonica, gde = excluded.gde, redosled = excluded.redosled;

create or replace function karijera_ima(p_user uuid, p_talenat text) returns boolean language sql stable security definer set search_path = public
as $$ select coalesce((select p_talenat = any(talenti) from karijera_igraci where user_id = p_user), false) $$;

-- Ostatak (karijera_izaberi_poziciju sa p_pol/p_talenti, karijera_zavrsi_rundu sa talentima, zamene u karijera_odrzi,
-- karijera_bot_pomoc, karijera_stanje, karijera_cv, karijera_zamene_talenta, karijera_promeni_talenat) primenjen je
-- migracijama `karijera_14_pol_i_talenti` i `karijera_15_promena_talenta` (supabase_migrations.schema_migrations
-- čuva tačan tekst). Tekuće definicije: select pg_get_functiondef('karijera_zavrsi_rundu'::regproc);

-- Reset karijere iz podešavanja (vlasnik 04.11): briše igrača, runde, ekspertizu, CV i izazove;
-- njegove firme postaju NPC firme pod upravom (u njima rade drugi igrači).
create or replace function karijera_resetuj() returns jsonb
language plpgsql security definer set search_path = public as $$
declare ja uuid := auth.uid(); firmi int;
begin
  if ja is null then raise exception 'Prijavi se' using errcode = '42501'; end if;
  update karijera_izazovi set stanje = 'gotov', zavrsen = now(), ishod = 'igrač je resetovao karijeru'
    where stanje <> 'gotov' and (vlasnik = ja or izazivac = ja);
  update karijera_firme set vlasnik = null, npc_ime = 'Uprava', vlasnik_od = now(), zastita_do = now() + interval '3 days'
    where vlasnik = ja and not zatvorena;
  get diagnostics firmi = row_count;
  update karijera_firme set rekord_igrac = null where rekord_igrac = ja;
  delete from karijera_izazovi where izazivac = ja;
  delete from karijera_prijave_imena where prijavio = ja;
  delete from karijera_runde where user_id = ja;
  delete from karijera_ekspertiza where user_id = ja;
  delete from karijera_dogadjaji where user_id = ja;
  delete from karijera_igraci where user_id = ja;
  return jsonb_build_object('ok', true, 'firmi_predato', firmi);
end $$;

-- Karijera: isto pitanje igraču najviše DVAPUT u 7 dana (vlasnik 04.11). Primenjeno kao migracija karijera_17;
-- svako prikazivanje je red u karijera_vidjena, izvlačenje preskače pitanja sa 2 prikaza u poslednjih 7 dana.
create table if not exists karijera_vidjena (
  user_id uuid not null references auth.users(id) on delete cascade,
  pitanje uuid not null,
  kad timestamptz not null default now()
);
create index if not exists karijera_vidjena_igrac on karijera_vidjena (user_id, kad desc);
alter table karijera_vidjena enable row level security;
-- karijera_izvuci: vidjena = count(*) iz karijera_vidjena za 7 dana, uslov coalesce(v.n, 0) < 2 (tekst: pg_get_functiondef).

-- Pomoći (migracija karijera_18): karijera_igraci.pomoci text[], 4 od 18 (karijera_pomoci_spisak), izbor u
-- karijera_izaberi_poziciju(p_pozicija, p_pol, p_talenti, p_pomoci); odgovor sa pomoći ×0,7, Insajder ×0,4;
-- opisi talenata kolega_plus/istrazivac/intuicija/duelista prilagođeni novim pomoćima.
-- karijera_19: probni u odgovoru runde nosi i 'danas' (broj današnjih rundi u Korporaciji).
alter table karijera_igraci add column if not exists pomoci text[] not null default '{}';
create or replace function karijera_pomoci_spisak() returns text[] language sql immutable as $$
  select array['pola_stola','crvena_olovka','insajder','mentor','prvo_slovo','produzen_rok','pauza_kafa','prekovremeno','ekspres',
    'hodnik','caskanje','mreza','ceo_tim','zamrznut_sat','sigurna_odluka','brainstorming','dvostruka_provera','sabotaza']
$$;
