-- karijera_47_nadzor (05.11.2026, vlasnik: „cepaj full sve, samo ne diraj app dok ne odobre”).
-- 1) Mreža igrača: IP i uređaj (user-agent) iz zaglavlja zahteva, pri svakoj partiji; čuva se 90 dana.
-- 2) Karijera: server pamti izdata pitanja i vreme, meri pravo trajanje runde; prebrza runda gubi dodatak za brzinu;
--    sumnje se upisuju u karijera_runde.sumnja. Pošten igrač ništa ne oseća (nema odbijanja ni kazne bez dokaza).
-- 3) Admin: admin_sumnjivo (spisak sa razlogom) i admin_igrac_detalji (praćenja, blokade, vreme po igri, mreža, povezani).
-- Ostaje rupa koja traži izmenu aplikacija: tačan odgovor stiže na telefon zajedno sa pitanjem (karijera_runda_pitanja).

-- 1) Mreža ---------------------------------------------------------------------------------------------------------
create table if not exists igraci_mreza (
  user_id uuid not null references auth.users(id) on delete cascade,
  ip text not null,
  uredjaj text,
  prvi timestamptz not null default now(),
  poslednji timestamptz not null default now(),
  broj int not null default 1,
  primary key (user_id, ip)
);
create index if not exists igraci_mreza_ip on igraci_mreza (ip, poslednji desc);
create index if not exists igraci_mreza_poslednji on igraci_mreza (poslednji);
alter table igraci_mreza enable row level security;
-- Bez politika: čita se samo kroz admin_* funkcije.

create or replace function zabelezi_mrezu(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare z jsonb; v_ip text; v_ua text;
begin
  if p_user is null then return; end if;
  z := nullif(current_setting('request.headers', true), '')::jsonb;
  if z is null then return; end if;
  v_ip := coalesce(nullif(z->>'cf-connecting-ip', ''), nullif(btrim(split_part(z->>'x-forwarded-for', ',', 1)), ''), nullif(z->>'x-real-ip', ''));
  if v_ip is null then return; end if;
  v_ua := left(z->>'user-agent', 200);
  insert into igraci_mreza (user_id, ip, uredjaj) values (p_user, v_ip, v_ua)
  on conflict (user_id, ip) do update set poslednji = now(), broj = igraci_mreza.broj + 1, uredjaj = coalesce(excluded.uredjaj, igraci_mreza.uredjaj);
  -- Čuvanje 90 dana (politika privatnosti): stari zapisi ovog igrača brišu se usput.
  delete from igraci_mreza where user_id = p_user and poslednji < now() - interval '90 days';
exception when others then
  -- Beleženje mreže nikad ne sme da obori partiju; greška ide u log baze.
  raise warning 'zabelezi_mrezu: %', sqlerrm;
end $$;
revoke all on function zabelezi_mrezu(uuid) from public, anon, authenticated;

create or replace function zabelezi_mrezu_okidac() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform zabelezi_mrezu(nullif(to_jsonb(new)->>tg_argv[0], '')::uuid);
  return null;
end $$;

drop trigger if exists mreza_rezultati on rezultati_igara;
create trigger mreza_rezultati after insert on rezultati_igara for each row execute function zabelezi_mrezu_okidac('user_id');
drop trigger if exists mreza_karijera on karijera_runde;
create trigger mreza_karijera after insert on karijera_runde for each row execute function zabelezi_mrezu_okidac('user_id');
drop trigger if exists mreza_osvajanje on osvajanje_potezi;
create trigger mreza_osvajanje after insert on osvajanje_potezi for each row execute function zabelezi_mrezu_okidac('ko');
drop trigger if exists mreza_veb on question_answer_log;
create trigger mreza_veb after insert on question_answer_log for each row execute function zabelezi_mrezu_okidac('user_id');

-- 2) Karijera: izdate runde i trajanje ---------------------------------------------------------------------------
create table if not exists karijera_izdate (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  firma_id uuid not null,
  ids uuid[] not null,
  izdato timestamptz not null default now(),
  iskoriscena boolean not null default false
);
create index if not exists karijera_izdate_igrac on karijera_izdate (user_id, izdato desc) where not iskoriscena;
alter table karijera_izdate enable row level security;

alter table karijera_runde add column if not exists trajanje_ms int, add column if not exists prosek_ms int, add column if not exists sumnja text[];
create index if not exists karijera_runde_sumnja on karijera_runde (kad desc) where sumnja is not null;

-- Izdavanje runde: isto kao pre, plus zapis izdatih pitanja (NADZOR).
CREATE OR REPLACE FUNCTION public.karijera_runda_pitanja(p_firma uuid)
 RETURNS TABLE(id uuid, question_text text, options jsonb, correct_answer integer, tema text)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
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
    -- NADZOR: koja pitanja su izdata i kada (predaja meri pravo trajanje i proverava pitanja).
    delete from karijera_izdate where user_id = auth.uid() and izdato < now() - interval '1 day';
    insert into karijera_izdate (user_id, firma_id, ids) values (auth.uid(), f.id, ids);
  end if;
  return query select q.id, q.question_text, q.options, q.correct_answer::int,
    coalesce(karijera_tema(q.tags, teme || f.fokus), 'opšte')
  from unnest(ids) x(pid) join karijera_fond q on q.id = x.pid order by random();
end $function$;

-- Predaja runde: isto kao pre, plus NADZOR (pravo trajanje, izdata pitanja, sumnje; prebrza runda bez dodatka za brzinu).
CREATE OR REPLACE FUNCTION public.karijera_zavrsi_rundu(p_firma uuid, p_odgovori jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
#variable_conflict use_column
declare
  ja karijera_igraci := karijera_ja(); f karijera_firme; danas date := karijera_danas();
  o jsonb; q record; tacan boolean; niz int := 0; tacnih int := 0; promet numeric := 0; vrednost numeric;
  kurs numeric; tezina numeric; brzina numeric; mnozilac_niza numeric; pomoc numeric; titula_mn numeric;
  placenih int; placeno boolean; udeo numeric; plata numeric := 0; kasi numeric := 0; ugled_plus int := 20;
  poeni int; danas_u_firmi int; nov_rekord boolean := false; probni jsonb := null; ishod int; procenat numeric;
  v_tema text; korp uuid := karijera_korporacija(); u_probnom boolean; struka text[]; t text[];
  sansa_iskoriscena boolean := false; eksp int; prag numeric; ms int; brz_granica int; niz_prag int;
  -- NADZOR
  predato uuid[]; izd_id bigint; izd_kad timestamptz; trajanje int; prebrzo boolean := false; zbir_ms int := 0; sumnja text[] := '{}';
begin
  if ja.pozicija is null then raise exception 'Prvo izaberi poziciju' using errcode = '22023'; end if;
  if jsonb_typeof(p_odgovori) <> 'array' or jsonb_array_length(p_odgovori) <> 10 then
    raise exception 'Runda ima tačno 10 odgovora' using errcode = '22023';
  end if;
  f := karijera_pristup(p_firma, ja);

  -- NADZOR: izdata runda koja sadrži sva predata pitanja (poslednja neiskorišćena, do 2 h).
  select array_agg((x->>'id')::uuid) into predato from jsonb_array_elements(p_odgovori) x where (x->>'id') ~ '^[0-9a-fA-F-]{36}$';
  select k.id, k.izdato into izd_id, izd_kad from karijera_izdate k
   where k.user_id = ja.user_id and k.firma_id = f.id and not k.iskoriscena and k.izdato > now() - interval '2 hours'
     and k.ids @> coalesce(predato, '{}')
   order by k.izdato desc limit 1;
  if izd_id is null then
    sumnja := sumnja || 'pitanja nisu iz izdate runde'::text;
  else
    update karijera_izdate set iskoriscena = true where id = izd_id;
    trajanje := (extract(epoch from now() - izd_kad) * 1000)::int;
    -- 10 pitanja ne može pošteno za manje od 15 s (priprema 4 s + čitanje + komentar posle odgovora).
    prebrzo := trajanje < 15000;
    if prebrzo then sumnja := sumnja || ('runda za ' || round(trajanje / 1000.0, 1) || ' s')::text; end if;
  end if;

  t := ja.talenti;
  brz_granica := case when 'brzinac' = any(t) then 8000 else 5000 end;
  niz_prag := case when 'maratonac' = any(t) then 3 else 5 end;
  titula_mn := (array[1, 1.3, 1.6, 2])[karijera_titula(ja.ugled) + 1];
  u_probnom := ja.probni_ishod is null and f.korporacija;
  select p.teme into struka from karijera_pozicije p where p.id = ja.pozicija;
  if u_probnom and ja.probni_runde < ja.probni_cilj
     and (select count(*) from karijera_runde r where r.user_id = ja.user_id and r.dan = danas and r.firma_id = korp) >= 10 then
    raise exception 'Probni rad: najviše 10 rundi dnevno. Nastavi sutra.' using errcode = '22023';
  end if;

  for o in select * from jsonb_array_elements(p_odgovori) loop
    select qq.correct_answer, qq.difficulty, qq.tags into q from karijera_fond qq where qq.id = (o->>'id')::uuid;
    if not found then continue; end if;
    tacan := (o->>'izbor')::int = q.correct_answer;
    v_tema := karijera_tema(q.tags);
    ms := (o->>'ms')::int;
    zbir_ms := zbir_ms + greatest(coalesce(ms, 0), 0);
    if tacan then
      tacnih := tacnih + 1; niz := niz + 1;
      kurs := 1;
      if not f.korporacija and q.tags && f.kljucne then kurs := (case when 'strucnjak' = any(t) then 2.5 else 2 end); end if;
      if 'svestran' = any(t) and not (q.tags && struka) then kurs := kurs * 1.25; end if;
      tezina := case q.difficulty when 'easy' then 1 when 'medium' then 2 else 4 end;
      -- NADZOR: vreme šalje telefon; kad je runda prebrza, dodatka za brzinu nema.
      brzina := case when prebrzo then 1 when ms <= brz_granica then 1.5 when ms <= 10000 then 1.2 else 1 end;
      mnozilac_niza := case when niz >= 10 then 1.5 when niz >= niz_prag then 1.2 else 1 end;
      pomoc := case when coalesce(o->>'pomoc', '') = '' then 1 when o->>'pomoc' = 'insajder' then 0.4 when o->>'pomoc' = 'bot' then 0.6 else 0.7 end;
      vrednost := 10 * kurs * tezina * brzina * mnozilac_niza * titula_mn * pomoc;
      promet := promet + vrednost;
    elsif 'druga_sansa' = any(t) and not sansa_iskoriscena then
      sansa_iskoriscena := true;
    else
      niz := 0;
    end if;
    if coalesce(o->>'pomoc', '') = '' and v_tema is not null then
      if tacan then ugled_plus := ugled_plus + 10; end if;
      eksp := case when tacan then (5 * case q.difficulty when 'easy' then 1 when 'medium' then 2 else 4 end) else -2 end;
      if tacan and 'ekspert' = any(t) then eksp := ceil(eksp * 1.5); end if;
      insert into karijera_ekspertiza (user_id, tema, ocena) values (ja.user_id, v_tema, greatest(0, eksp))
      on conflict (user_id, tema) do update set ocena = greatest(0, karijera_ekspertiza.ocena + eksp), poslednje = now();
    end if;
  end loop;

  -- NADZOR: telefon tvrdi prosek ispod 0,8 s uz 9+ tačnih (čovek to ne može u nizu).
  if tacnih >= 9 and zbir_ms > 0 and zbir_ms < 8000 then sumnja := sumnja || ('prosek ' || round(zbir_ms / 10000.0, 2) || ' s uz ' || tacnih || ' tačnih')::text; end if;

  if 'upornost' = any(t) then ugled_plus := ceil(ugled_plus * 1.25); end if;
  if not f.korporacija and f.vlasnik is not null and karijera_ima(f.vlasnik, 'lider') then promet := promet * 1.1; end if;
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
    if 'pregovarac' = any(t) then plata := round(plata * 1.1, 2); end if;
    if karijera_slobodan(f, danas) then
      plata := round(plata * 1.1, 2);
      kasi := round(kasi * 1.1, 2);
    end if;
    if udeo > 0 and not ja.mirni and karijera_stres(f) > 0 then
      kasi := greatest(0, kasi - round(plata * karijera_stres(f), 2));
      plata := round(plata * (1 + karijera_stres(f)), 2);
    end if;
  end if;

  insert into karijera_runde (user_id, firma_id, dan, tacnih, poeni, placeno, plata, kasi, trajanje_ms, prosek_ms, sumnja)
  values (ja.user_id, f.id, danas, tacnih, poeni, placeno, plata, kasi, trajanje, nullif(zbir_ms / 10, 0), nullif(sumnja, '{}'));
  update karijera_igraci set kapital = kapital + plata, ugled = ugled + ugled_plus where user_id = ja.user_id;
  update karijera_firme set kasa = kasa + kasi where id = f.id;

  if f.vlasnik = ja.user_id then
    update karijera_firme set poslednji_ulazak = danas, otkaza_od_ulaska = 0 where id = f.id;
  end if;

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

  if u_probnom and ja.probni_runde < ja.probni_cilj then
    update karijera_igraci set probni_runde = probni_runde + 1, probni_tacnih = probni_tacnih + tacnih where user_id = ja.user_id
      returning * into ja;
    if ja.probni_runde >= ja.probni_cilj then
      procenat := ja.probni_tacnih::numeric / (ja.probni_cilj * 10);
      prag := case when 'probni_as' = any(t) then 0.05 else 0 end;
      ishod := case when procenat >= 0.9 - prag then 2 when procenat >= 0.75 - prag then 1 when procenat >= 0.6 - prag then 0 else -1 end;
      update karijera_igraci set probni_ishod = ishod, probni_kraj = danas,
        office_pravo = case when ishod >= 0 then ishod end where user_id = ja.user_id;
      perform karijera_dogadjaj(ja.user_id, 'probni', case when ishod >= 0
        then 'Probni rad položen sa ' || round(procenat * 100) || '% tačnih. Pravo na svoj office.'
        else 'Probni rad: ' || round(procenat * 100) || '% tačnih. Ostaje se u Korporaciji.' end);
    end if;
    probni := jsonb_build_object('runde', ja.probni_runde, 'cilj', ja.probni_cilj, 'tacnih', ja.probni_tacnih, 'ishod', ishod,
      'danas', (select count(*) from karijera_runde r where r.user_id = ja.user_id and r.dan = danas and r.firma_id = korp));
  end if;

  return jsonb_build_object('tacnih', tacnih, 'poeni', poeni, 'placeno', placeno, 'plata', plata, 'kasi', kasi,
    'ugled', ugled_plus, 'rekord', nov_rekord, 'probni', probni,
    'placenih_danas', placenih + case when placeno then 1 else 0 end, 'prekovremeno', placeno and karijera_slobodan(f, danas));
end $function$;

-- 3) Admin -----------------------------------------------------------------------------------------------------------
create index if not exists pracenja_koga on pracenja (koga);
create index if not exists game_rooms_kraj on game_rooms (created_at desc) where status = 'finished';

-- Sumnjivi igrači u poslednjih p_dana dana; jačina 3 = gotovo sigurno, 2 = verovatno, 1 = pogledati (može biti slučajno).
create or replace function admin_sumnjivo(p_dana int default 30)
returns table (user_id uuid, nadimak text, razlog text, detalj text, jacina int, kad timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare od timestamptz := now() - make_interval(days => least(greatest(coalesce(p_dana, 30), 1), 365));
begin
  perform admin_provera();
  return query
  with s as (
    -- Karijera: server je sam izmerio prebrzu rundu ili pitanja koja nije izdao.
    select r.user_id, 'Karijera: sumnjive runde'::text razlog,
           count(*) || ' rundi: ' || string_agg(distinct x, ', ') detalj,
           case when bool_or(x like 'runda za%' or x like 'pitanja nisu%') then 3 else 2 end jacina, max(r.kad) kad
      from karijera_runde r cross join unnest(r.sumnja) x
     where r.kad > od and r.sumnja is not null group by r.user_id
    union all
    -- Brzina: prosek odgovora ispod 1,5 s uz 90%+ tačnih, bar 3 partije iste igre.
    select r.user_id, 'Nemoguća brzina',
           r.igra || ': ' || count(*) || ' partija, prosek ' || round(avg(r.prosek_ms) / 1000.0, 2) || ' s, '
             || round(100.0 * sum(r.tacnih) / nullif(sum(r.tacnih + r.netacnih), 0)) || '% tačnih',
           2, max(r.created_at)
      from rezultati_igara r
     where r.created_at > od and r.prosek_ms > 0 and r.igra not in ('vesanje')
     group by r.user_id, r.igra
    having count(*) >= 3 and avg(r.prosek_ms) < 1500 and sum(r.tacnih)::numeric / nullif(sum(r.tacnih + r.netacnih), 0) >= 0.9
    union all
    -- Rezultat iskače: više od proseka igre + 4 standardne devijacije (igre sa bar 20 partija).
    select r.user_id, 'Rezultat iskače',
           r.igra || ': ' || r.poeni || ' poena (prosek igre ' || round(g.p) || ')', 1, r.created_at
      from rezultati_igara r
      join (select igra, avg(poeni) p, stddev_pop(poeni) d from rezultati_igara group by igra having count(*) >= 20) g on g.igra = r.igra
     where r.created_at > od and g.d > 0 and r.poeni > g.p + 4 * g.d
    union all
    -- Isti par u duelima: 5+ završenih duela za 7 dana, jedan uglavnom pobeđuje.
    select x.u, 'Isti par u duelima',
           x.n || ' duela sa ' || coalesce(nullif(p2.nickname, ''), p2.first_name, 'igračem') || ' za 7 dana, pobeda ' || x.pob, 2, x.kad
      from (
        select d.u, d.drugi, count(*) n, sum(case when d.moj > d.njegov then 1 else 0 end) pob, max(d.created_at) kad from (
          select host_id u, guest_id drugi, host_score moj, guest_score njegov, created_at from game_rooms where status = 'finished' and created_at > now() - interval '7 days' and guest_id is not null
          union all
          select guest_id, host_id, guest_score, host_score, created_at from game_rooms where status = 'finished' and created_at > now() - interval '7 days' and guest_id is not null
        ) d group by d.u, d.drugi having count(*) >= 5
      ) x left join profiles p2 on p2.id = x.drugi
     where x.pob >= x.n * 0.8 or x.pob <= x.n * 0.2
    union all
    -- Isti IP sa drugim nalozima (ista kuća ili mobilna mreža može biti slučajno, zato jačina 1).
    select a.user_id, 'Isti IP kao drugi nalozi',
           count(distinct b.user_id) || ' naloga: ' || string_agg(distinct coalesce(nullif(pb.nickname, ''), pb.first_name, 'igrač'), ', '), 1, max(a.poslednji)
      from igraci_mreza a join igraci_mreza b on b.ip = a.ip and b.user_id <> a.user_id and b.poslednji > od
      left join profiles pb on pb.id = b.user_id
     where a.poslednji > od group by a.user_id
    union all
    -- Novi nalozi (do 60 dana) napravljeni u razmaku do 2 dana koji prate jedan drugog.
    select k1.ko, 'Međusobno praćenje novih naloga',
           'sa ' || coalesce(nullif(p2.nickname, ''), p2.first_name, 'igračem'), 1, greatest(k1.created_at, k2.created_at)
      from pracenja k1 join pracenja k2 on k2.ko = k1.koga and k2.koga = k1.ko
      join profiles p1 on p1.id = k1.ko join profiles p2 on p2.id = k1.koga
     where p1.created_at > now() - interval '60 days' and p2.created_at > now() - interval '60 days'
       and abs(extract(epoch from p1.created_at - p2.created_at)) < 2 * 86400
  )
  select s.user_id, coalesce(nullif(p.nickname, ''), p.first_name, 'Igrač'), s.razlog, s.detalj, s.jacina, s.kad
    from s left join profiles p on p.id = s.user_id
   order by s.jacina desc, s.kad desc nulls last
   limit 500;
end $$;

-- Sve o jednom igraču za nadzor: praćenja, blokade, vreme po igri, Karijera, mreža i povezani nalozi.
create or replace function admin_igrac_detalji(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform admin_provera();
  return jsonb_build_object(
    'prati', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'nadimak', coalesce(nullif(p.nickname, ''), p.first_name, 'Igrač'), 'kad', x.created_at) order by x.created_at desc)
      from pracenja x join profiles p on p.id = x.koga where x.ko = p_id), '[]'),
    'pratioci', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'nadimak', coalesce(nullif(p.nickname, ''), p.first_name, 'Igrač'), 'kad', x.created_at) order by x.created_at desc)
      from pracenja x join profiles p on p.id = x.ko where x.koga = p_id), '[]'),
    'blokirao', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'nadimak', coalesce(nullif(p.nickname, ''), p.first_name, 'Igrač')))
      from blokade x join profiles p on p.id = x.koga where x.ko = p_id), '[]'),
    'blokiran_od', (select count(*) from blokade where koga = p_id),
    'po_igri', coalesce((select jsonb_agg(g order by g.partija desc) from (
      select r.igra, count(*) partija, round(avg(r.prosek_ms)) prosek_ms,
             round(100.0 * sum(r.tacnih) / nullif(sum(r.tacnih + r.netacnih), 0)) tacnost, max(r.poeni) najbolji, max(r.created_at) poslednja
        from rezultati_igara r where r.user_id = p_id group by r.igra) g), '[]'),
    'karijera', (select jsonb_build_object('runde', count(*), 'trajanje_ms', round(avg(trajanje_ms)), 'prosek_ms', round(avg(prosek_ms)),
       'sumnjivih', count(*) filter (where sumnja is not null), 'tacnost', round(10.0 * avg(tacnih)))
      from karijera_runde where user_id = p_id),
    'mreza', coalesce((select jsonb_agg(jsonb_build_object('ip', m.ip, 'uredjaj', m.uredjaj, 'prvi', m.prvi, 'poslednji', m.poslednji, 'broj', m.broj,
       'drugi', (select jsonb_agg(jsonb_build_object('id', p.id, 'nadimak', coalesce(nullif(p.nickname, ''), p.first_name, 'Igrač')))
                   from igraci_mreza o join profiles p on p.id = o.user_id where o.ip = m.ip and o.user_id <> p_id))
       order by m.poslednji desc) from igraci_mreza m where m.user_id = p_id), '[]'),
    'sumnje', coalesce((select jsonb_agg(jsonb_build_object('razlog', s.razlog, 'detalj', s.detalj, 'jacina', s.jacina, 'kad', s.kad))
      from admin_sumnjivo(90) s where s.user_id = p_id), '[]')
  );
end $$;

do $$ declare f text; begin
  foreach f in array array['admin_sumnjivo(int)', 'admin_igrac_detalji(uuid)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
revoke all on function zabelezi_mrezu_okidac() from public, anon, authenticated;

-- karijera_50: Aktivnost za Karijeru pokazuje „bez plate” (placeno=false je runda preko 10 plaćenih, ne probni), trajanje i sumnju;
-- tabla broji igrače sa sumnjom jačine 2+.
do $$ declare d text; s text := 'case when not k.placeno then ''probni'' end)'; begin
  d := pg_get_functiondef('public.admin_aktivnost(text, uuid, timestamptz, int)'::regprocedure);
  if position(s in d) = 0 then raise exception 'admin_aktivnost: deo za Karijeru nije pronađen'; end if;
  d := replace(d, s, 'case when not k.placeno then ''bez plate'' end, case when k.trajanje_ms is not null then round(k.trajanje_ms / 1000.0) || '' s'' end, case when k.sumnja is not null then ''SUMNJA: '' || array_to_string(k.sumnja, '', '') end)');
  execute d;
end $$;
-- admin_pregled dobija ključ 'sumnjivih' = (select count(distinct s.user_id) from admin_sumnjivo(30) s where s.jacina >= 2)
-- (cela funkcija je u 2026-11-05_admin-aktivnost-karijera.sql, verzija karijera_46 + ovaj ključ).
