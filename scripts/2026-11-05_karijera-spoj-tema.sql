-- Spajanje tema struke u šire teme sa najmanje 1.000 pitanja (vlasnik 05.11: „Spoji, pa dopiši”).
-- Oznaka šire teme se DODAJE na kraj tags (prva oznaka, po kojoj ostale igre biraju kategoriju, ostaje ista).
-- Svaka dodata oznaka je zapisana u karijera_oznake_dodate, pa se spajanje može vratiti.
create table if not exists public.karijera_teme_spoj (grupa text not null, tag text not null, primary key (grupa, tag));
alter table public.karijera_teme_spoj enable row level security;
revoke all on public.karijera_teme_spoj from public, anon, authenticated;
insert into public.karijera_teme_spoj (grupa, tag) values ('pravo','pravo i ustav'),('pravo','pravo'),('pravo','ustav'),('pravo','ljudska prava'),('pravo','istorija prava'),('pravo','rimsko pravo'),('pravo','poznata suđenja'),('pravo','međunarodne institucije'),('pravo','EU i UN institucije'),
('ekonomija','ekonomija'),('ekonomija','finansije'),('ekonomija','berza'),('ekonomija','valute'),('ekonomija','kompanije'),('ekonomija','istorija ekonomije'),('ekonomija','novac i valute'),('ekonomija','poznate kompanije'),('ekonomija','procenti i računica'),
('opšte znanje','opšte znanje'),('opšte znanje','društvo i kultura'),
('politika','politika'),('politika','međunarodni odnosi'),('politika','međunarodne organizacije'),('politika','svetska politika'),('politika','savremena istorija'),('politika','EU i UN institucije'),('politika','međunarodne institucije'),
('film i tv','film i tv'),('film i tv','Film'),('film i tv','pozorište'),('film i tv','glumci'),('film i tv','serije'),
('tehnologija','tehnologija'),('tehnologija','izumi'),('tehnologija','izumi i izumitelji'),('tehnologija','arhitektura'),('tehnologija','poznate građevine'),('tehnologija','saobraćaj i vozila'),('tehnologija','fizika'),('tehnologija','matematika'),
('istorija','istorija'),('istorija','vladari'),('istorija','Vladari'),('istorija','vladari i dinastije'),('istorija','ratovi'),('istorija','antika'),('istorija','arheologija'),('istorija','Godine događaja'),('istorija','Srbija i Balkan'),('istorija','svetska istorija'),('istorija','savremena istorija'),
('književnost','književnost'),('književnost','Klasici'),('književnost','Književna dela'),('književnost','Pisci i dela'),('književnost','Književni pravci'),('književnost','knjige i izdavaštvo'),('književnost','književne nagrade'),('književnost','umetnost i književnost'),
('religija i mitologija','religija i mitologija'),('religija i mitologija','mitologija'),('religija i mitologija','religije i verovanja'),
('umetnost','umetnost'),('umetnost','slikari'),('umetnost','skulptura'),('umetnost','muzeji'),('umetnost','likovna umetnost'),('umetnost','muzeji sveta'),('umetnost','umetnički pravci'),('umetnost','umetnost i književnost'),('umetnost','arhitektura'),
('hrana i piće','hrana i piće'),('hrana i piće','gastronomija'),('hrana i piće','vino'),('hrana i piće','začini'),('hrana i piće','hrana'),('hrana i piće','nacionalna jela'),('hrana i piće','namirnice'),('hrana i piće','poznati kuvari'),('hrana i piće','vino i pića'),
('medicina','medicina'),('medicina','anatomija'),('medicina','biologija čoveka'),('medicina','bolesti'),('medicina','istorija medicine'),('medicina','ishrana'),
('mediji i marketing','marketing'),('mediji i marketing','brendovi'),('mediji i marketing','reklame'),('mediji i marketing','društvene mreže'),('mediji i marketing','mediji'),('mediji i marketing','brendovi i logotipi'),('mediji i marketing','marketing i reklame'),('mediji i marketing','psihologija kupca'),('mediji i marketing','slogani'),('mediji i marketing','mediji i novine'),
('moda','moda'),('moda','dizajn'),('moda','istorija odevanja'),('moda','moda i modni brendovi'),
('muzika','muzika'),('muzika','kompozitori'),('muzika','opera'),('muzika','evrovizija'),('muzika','instrumenti'),('muzika','opera i klasika'),
('nauka','nauka'),('nauka','hemija'),('nauka','biologija'),('nauka','astronomija'),('nauka','astronomija i svemir'),('nauka','fizika'),('nauka','geologija'),('nauka','matematika'),('nauka','otkrića'),('nauka','logika'),
('ličnosti','ličnosti'),('ličnosti','poznate ličnosti'),('ličnosti','poznati sportisti'),
('računari','računari'),('računari','internet'),('računari','it kompanije'),('računari','video-igre'),('računari','video igre'),('računari','istorija IT-a'),('računari','tehnološke kompanije'),
('društvo','društvo'),('društvo','filozofija'),('društvo','sociologija'),('društvo','ljudsko ponašanje'),('društvo','psihologija'),('društvo','ljudska prava'),
('sport','sport'),('sport','Sportisti'),('sport','Sportisti po godinama'),('sport','fudbal'),('sport','košarka'),('sport','olimpijske igre'),('sport','atletika'),('sport','auto-moto sport'),('sport','bejzbol'),('sport','biciklizam'),('sport','boks'),('sport','borilački sportovi'),('sport','društvene igre'),('sport','formula 1'),('sport','golf'),('sport','hokej'),('sport','kartaške igre'),('sport','klizanje'),('sport','konjske trke'),('sport','kriket'),('sport','poznati sportisti'),('sport','ragbi'),('sport','rekordi'),('sport','snuker'),('sport','sportovi na ledu'),('sport','surfovanje'),('sport','tenis'),
('geografija','geografija'),('geografija','Znamenitosti'),('geografija','znamenitosti'),('geografija','Gradovi i reke'),('geografija','glavni gradovi'),('geografija','zastave'),('geografija','valute'),('geografija','jezici'),('geografija','turizam'),
('priroda','priroda'),('priroda','životinje'),('priroda','biljke'),('priroda','ekologija'),('priroda','klima'),('priroda','okeani'),('priroda','priroda i klima'),('priroda','veterina'),
('kultura','kultura'),('tehnika','tehnika'),('jezik','jezik') on conflict do nothing;

create table if not exists public.karijera_oznake_dodate (question_id uuid not null, izvor text not null, grupa text not null, kad timestamptz default now(), primary key (question_id, grupa));
alter table public.karijera_oznake_dodate enable row level security;
revoke all on public.karijera_oznake_dodate from public, anon, authenticated;

-- 1) Po užim oznakama: pitanja struke i opšti fond.
with m as (select k.id, s.grupa from public.karijera_pitanja k join public.karijera_teme_spoj s on s.tag = any(k.tags) where not s.grupa = any(k.tags) group by k.id, s.grupa),
     ins as (insert into public.karijera_oznake_dodate (question_id, izvor, grupa) select id, 'karijera', grupa from m on conflict do nothing returning question_id, grupa)
update public.karijera_pitanja k set tags = k.tags || g.grupe from (select question_id, array_agg(grupa) grupe from ins group by question_id) g where k.id = g.question_id;

with m as (select q.id, s.grupa from public.questions q join public.karijera_teme_spoj s on s.tag = any(q.tags) where not s.grupa = any(q.tags) group by q.id, s.grupa),
     ins as (insert into public.karijera_oznake_dodate (question_id, izvor, grupa) select id, 'questions', grupa from m on conflict do nothing returning question_id, grupa)
update public.questions q set tags = q.tags || g.grupe from (select question_id, array_agg(grupa) grupe from ins group by question_id) g where q.id = g.question_id;

-- 2) Dopuna pet tema iz opšteg fonda po strogim rečima (proveren uzorak; „Premijer liga” isključena).
with kand(grupa, id) as (
  select 'politika', id from public.questions where is_active and question_text ~* '(\mpredsedni(k|ca|ka) (države|vlade|SAD|Srbije|Francuske|Rusije|Jugoslavije|Amerike)|\mpremijer(a|ka|om|u)?\M|\mparlament|Ujedinjen(e|ih) nacij|\mNATO\M|Evropsk(a|e|oj) unij|\mambasad|\mkancelar Nemačke|\mgeneralni sekretar)' and question_text !~* 'premijer lig'
  union all select 'društvo', id from public.questions where is_active and question_text ~* '(\mfilozof|\mpsiholo|\msociolo|\mFrojd|\mPlaton|\mAristotel|\mSokrat|\mNiče\M|\mImanuel Kant)'
  union all select 'tehnologija', id from public.questions where is_active and question_text ~* '(\mizumi(o|la|teljem|telj|telja)|\mizum\M|\mpatentira|\mparn(a|u|e) mašin|\mmotor (sa|na) unutrašnj|\mprvi automobil|\mprvi avion|\msijalic|\mtelegraf)'
  union all select 'mediji i marketing', id from public.questions where is_active and question_text ~* '(\mnovin(e|a|ama|ar)\M|\mtelevizij|\mreklam|\mslogan|\mlogotip|\mbrend|\mčasopis|\mFacebook|\mInstagram|\mTwitter|\mYouTube)'
  union all select 'računari', id from public.questions where is_active and question_text ~* '(\mračunar|\mkompjuter|\minternet|\msoftver|\mMicrosoft|\mGoogle|\mApple\M|\mvideo-?igr|\mWindows|\mLinux|\moperativn)'
), m as (select k.id, k.grupa from kand k join public.questions q on q.id = k.id where not k.grupa = any(q.tags) group by k.id, k.grupa),
   ins as (insert into public.karijera_oznake_dodate (question_id, izvor, grupa) select id, 'questions-reci', grupa from m on conflict do nothing returning question_id, grupa)
update public.questions q set tags = q.tags || g.grupe from (select question_id, array_agg(grupa) grupe from ins group by question_id) g where q.id = g.question_id;

-- 3) Teme struka: samo šire teme (svaka >= 1.000 pitanja).
update public.karijera_pozicije p set teme = v.teme from (values
 ('advokat', array['pravo','istorija','društvo']),
 ('bankar', array['ekonomija','opšte znanje','hrana i piće']),
 ('diplomata', array['politika','geografija','istorija','religija i mitologija','jezik','sport','opšte znanje']),
 ('filmski', array['film i tv','ličnosti','muzika']),
 ('inzenjer', array['tehnologija','tehnika','nauka','opšte znanje']),
 ('istoricar', array['istorija','geografija','opšte znanje']),
 ('izdavac', array['književnost','religija i mitologija','film i tv','geografija','hrana i piće','istorija','jezik','muzika','nauka','sport','umetnost','opšte znanje']),
 ('kustos', array['umetnost','kultura','opšte znanje']),
 ('kuvar', array['hrana i piće','geografija','opšte znanje']),
 ('lekar', array['medicina','nauka','priroda','istorija']),
 ('marketing', array['mediji i marketing','ekonomija','opšte znanje']),
 ('moda', array['moda','umetnost','ličnosti','kultura','nauka','opšte znanje']),
 ('muzicki', array['muzika','film i tv','ličnosti']),
 ('naucnik', array['nauka','medicina','hrana i piće']),
 ('novinar', array['mediji i marketing','politika','ličnosti','istorija','geografija','književnost','opšte znanje']),
 ('programer', array['računari','tehnologija','tehnika','nauka','geografija','istorija','opšte znanje']),
 ('psiholog', array['društvo','religija i mitologija','hrana i piće','istorija','nauka','opšte znanje']),
 ('sportski', array['sport','ličnosti','opšte znanje']),
 ('turizam', array['geografija','istorija','kultura','opšte znanje']),
 ('veterinar', array['priroda','film i tv','geografija','hrana i piće','istorija','nauka','sport','opšte znanje'])
) v(id, teme) where p.id = v.id;

-- 4) Ključne oblasti postojećih firmi: uža tema → šira (bez duplikata, najviše 3).
update public.karijera_firme f set kljucne = x.nove from (
  select f2.id, (select array_agg(g order by prvi) from (select coalesce(s.grupa, k) g, min(ord) prvi from unnest(f2.kljucne) with ordinality u(k, ord)
      left join lateral (select grupa from public.karijera_teme_spoj where tag = u.k order by (grupa = u.k) desc limit 1) s on true group by 1 order by 2 limit 3) t) nove
  from public.karijera_firme f2 where f2.kljucne is not null and cardinality(f2.kljucne) > 0) x
where f.id = x.id and x.nove is not null and x.nove <> f.kljucne;

-- karijera_39_fokus_iz_fonda: Fokus u opštem delu broji ceo fond Karijere, nudi samo teme sa >= 1.000 pitanja.
-- Povratak spajanja: za svaki red u karijera_oznake_dodate skinuti oznaku `grupa` iz tags (questions ili karijera_pitanja).
