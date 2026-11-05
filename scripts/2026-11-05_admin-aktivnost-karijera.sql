-- karijera_40_admin (05.11.2026): admin /majmun dobija aktivnost svih igara, Karijeru, pitanja struka,
-- Osvajanje i padove aplikacije. Sve admin funkcije su SECURITY DEFINER i počinju proverom is_admin_user().

-- Indeksi za keyset po vremenu (lista aktivnosti i soba ide od najnovijeg).
create index if not exists rezultati_igara_vreme on rezultati_igara (created_at desc);
create index if not exists karijera_runde_kad on karijera_runde (kad desc);
create index if not exists kafana_sessions_created_idx on kafana_sessions (created_at desc);
create index if not exists osvajanje_sobe_napravljena on osvajanje_sobe (napravljena desc);
create index if not exists karijera_pitanja_tekst_trgm on karijera_pitanja using gin (question_text gin_trgm_ops);

create or replace function admin_provera() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin_user() then raise exception 'Samo za urednike' using errcode = '42501'; end if;
end $$;

-- Jedna lista partija iz aplikacije (rezultati_igara), Karijere (karijera_runde) i starih veb igara.
-- Keyset: p_pre = vreme poslednjeg reda sa prethodne strane.
create or replace function admin_aktivnost(p_igra text default null, p_korisnik uuid default null,
  p_pre timestamptz default null, p_broj int default 50)
returns table (kad timestamptz, user_id uuid, nadimak text, igra text, poeni int, tacnih int, netacnih int, opis text)
language plpgsql stable security definer set search_path = public as $$
declare n int := least(greatest(coalesce(p_broj, 50), 1), 200);
begin
  perform admin_provera();
  return query
  with sve as (
    (select r.created_at, r.user_id, r.igra, r.poeni, r.tacnih, r.netacnih,
            concat_ws(' · ', r.nacin, nullif(r.pomoc, ''), case when r.izdaja > 0 then 'izdaja ' || r.izdaja end) as opis
       from rezultati_igara r
      where (p_igra is null or r.igra = p_igra) and (p_korisnik is null or r.user_id = p_korisnik)
        and (p_pre is null or r.created_at < p_pre)
      order by r.created_at desc limit n)
    union all
    (select k.kad, k.user_id, 'karijera', k.poeni, k.tacnih, greatest(10 - k.tacnih, 0),
            concat_ws(' · ', karijera_ime_firme(f), case when k.plata > 0 then 'plata ' || round(k.plata) end, case when not k.placeno then 'probni' end)
       from karijera_runde k left join karijera_firme f on f.id = k.firma_id
      where (p_igra is null or p_igra = 'karijera') and (p_korisnik is null or k.user_id = p_korisnik)
        and (p_pre is null or k.kad < p_pre)
      order by k.kad desc limit n)
    union all
    (select s.created_at, s.user_id, 'pro-veb', s.score, s.correct_answers, s.wrong_answers, s.questions_reached || ' pitanja'
       from survivor_sessions s
      where (p_igra is null or p_igra = 'pro-veb') and (p_korisnik is null or s.user_id = p_korisnik)
        and (p_pre is null or s.created_at < p_pre)
      order by s.created_at desc limit n)
    union all
    (select b.created_at, b.user_id, 'book-veb', b.score, b.correct_answers, b.wrong_answers, b.top_genre
       from book_sessions b
      where (p_igra is null or p_igra = 'book-veb') and (p_korisnik is null or b.user_id = p_korisnik)
        and (p_pre is null or b.created_at < p_pre)
      order by b.created_at desc limit n)
    union all
    (select q.created_at, q.user_id, 'kafanski-veb', q.score, q.correct_answers, q.wrong_answers, null
       from kafana_sessions q
      where (p_igra is null or p_igra = 'kafanski-veb') and (p_korisnik is null or q.user_id = p_korisnik)
        and (p_pre is null or q.created_at < p_pre)
      order by q.created_at desc limit n)
    union all
    (select h.created_at, h.user_id, 'vesanje-veb', h.score, case when h.won then 1 else 0 end, h.wrong_guesses,
            concat_ws(' · ', h.word, h.category)
       from hangman_sessions h
      where (p_igra is null or p_igra = 'vesanje-veb') and (p_korisnik is null or h.user_id = p_korisnik)
        and (p_pre is null or h.created_at < p_pre)
      order by h.created_at desc limit n)
    union all
    (select q.created_at, q.user_id, 'brzi-veb', q.score, q.correct_count, q.wrong_count, null
       from quick_sessions q
      where (p_igra is null or p_igra = 'brzi-veb') and (p_korisnik is null or q.user_id = p_korisnik)
        and (p_pre is null or q.created_at < p_pre)
      order by q.created_at desc limit n)
  )
  select sve.created_at, sve.user_id, coalesce(nullif(p.nickname, ''), p.first_name, 'Igrač'),
         sve.igra, sve.poeni, sve.tacnih, sve.netacnih, nullif(sve.opis, '')
    from sve left join profiles p on p.id = sve.user_id
   order by sve.created_at desc limit n;
end $$;

-- Firme Karijere (shortcut: bez paginacije jer ih je par desetina; keyset kad pređu ~500).
create or replace function admin_karijera_firme()
returns table (id uuid, ime text, ime_dato text, vlasnik uuid, vlasnik_nadimak text, korporacija boolean, pozicija text,
  nivo int, kasa numeric, zaposlenih int, prijava int, rekord int, osnovana timestamptz, poslednji_ulazak date, zatvorena boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  perform admin_provera();
  return query
  select f.id, karijera_ime_firme(f), f.ime, f.vlasnik, coalesce(nullif(p.nickname, ''), p.first_name),
         f.korporacija, f.pozicija, f.nivo, f.kasa,
         (select count(*)::int from karijera_igraci i where i.firma_id = f.id),
         (select count(*)::int from karijera_prijave_imena x where x.firma_id = f.id),
         f.rekord, f.osnovana, f.poslednji_ulazak, f.zatvorena
    from karijera_firme f left join profiles p on p.id = f.vlasnik
   -- karijera_45: prijavljena imena, pa otvorene firme igrača, pa botovi po nivou; zatvorene na kraju.
   order by (select count(*) from karijera_prijave_imena x where x.firma_id = f.id) desc, f.zatvorena, f.vlasnik is null, f.nivo desc, f.osnovana;
end $$;

-- Moderacija imena: „skini_ime” radi isto što i tri prijave igrača; „odbaci_prijave” briše prijave, ime ostaje.
create or replace function admin_karijera_firma(p_id uuid, p_radnja text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare f karijera_firme;
begin
  perform admin_provera();
  select * into f from karijera_firme where id = p_id;
  if not found then raise exception 'Firma ne postoji' using errcode = 'P0002'; end if;
  if p_radnja = 'skini_ime' then
    update karijera_firme set ime = null where id = p_id;
    delete from karijera_prijave_imena where firma_id = p_id;
    if f.vlasnik is not null then
      perform karijera_dogadjaj(f.vlasnik, 'ime', 'Urednik je skinuo ime firme. Izaberi novo u podešavanjima firme.');
    end if;
  elsif p_radnja = 'odbaci_prijave' then
    delete from karijera_prijave_imena where firma_id = p_id;
  else
    raise exception 'Nepoznata radnja' using errcode = '22023';
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function admin_karijera_igraci()
returns table (user_id uuid, nadimak text, pozicija text, kapital numeric, ugled int, firma text, vlasnik boolean,
  rundi int, poslednja timestamptz, napravljen timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform admin_provera();
  return query
  select i.user_id, coalesce(nullif(p.nickname, ''), p.first_name, 'Igrač'), i.pozicija, i.kapital, i.ugled,
         karijera_ime_firme(f), f.vlasnik = i.user_id,
         (select count(*)::int from karijera_runde r where r.user_id = i.user_id),
         (select max(r.kad) from karijera_runde r where r.user_id = i.user_id),
         i.napravljen
    from karijera_igraci i left join profiles p on p.id = i.user_id left join karijera_firme f on f.id = i.firma_id
   order by 9 desc nulls last, i.napravljen desc;
end $$;

-- Pitanja struka: pretraga (trigram), filter po struci, keyset po id; p_id vraća jedno pitanje za izmenu.
create or replace function admin_karijera_pitanja(p_trazi text default null, p_pozicija text default null,
  p_posle uuid default null, p_broj int default 50, p_id uuid default null)
returns table (id uuid, pozicija text, question_text text, options jsonb, correct_answer int, difficulty text,
  tags text[], is_active boolean, prijava int)
language plpgsql stable security definer set search_path = public as $$
declare n int := least(greatest(coalesce(p_broj, 50), 1), 200); t text := nullif(btrim(p_trazi), '');
begin
  perform admin_provera();
  return query
  select q.id, q.pozicija, q.question_text, q.options, q.correct_answer, q.difficulty, q.tags, q.is_active,
         (select count(*)::int from question_reports r where r.question_id = q.id and r.status = 'pending')
    from karijera_pitanja q
   where (p_id is null or q.id = p_id)
     and (t is null or q.question_text ilike '%' || t || '%')
     and (p_pozicija is null or q.pozicija = p_pozicija)
     and (p_posle is null or q.id > p_posle)
   order by q.id limit n;
end $$;

create or replace function admin_karijera_pitanje_sacuvaj(p_id uuid, p_tekst text, p_opcije jsonb, p_tacan int, p_aktivno boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare broj int;
begin
  perform admin_provera();
  if length(btrim(coalesce(p_tekst, ''))) < 5 then raise exception 'Pitanje je prekratko' using errcode = '22023'; end if;
  if jsonb_typeof(p_opcije) <> 'array' then raise exception 'Odgovori moraju biti spisak' using errcode = '22023'; end if;
  broj := jsonb_array_length(p_opcije);
  -- Tabela traži tačno 4 odgovora (karijera_pitanja_options_check).
  if broj <> 4 then raise exception 'Treba tačno 4 odgovora' using errcode = '22023'; end if;
  if exists (select 1 from jsonb_array_elements(p_opcije) e where jsonb_typeof(e) <> 'string' or length(btrim(e #>> '{}')) = 0) then
    raise exception 'Nijedan odgovor ne sme biti prazan' using errcode = '22023';
  end if;
  if p_tacan is null or p_tacan < 0 or p_tacan >= broj then raise exception 'Izaberi tačan odgovor' using errcode = '22023'; end if;
  update karijera_pitanja
     set question_text = btrim(p_tekst),
         options = (select jsonb_agg(btrim(e #>> '{}')) from jsonb_array_elements(p_opcije) e),
         correct_answer = p_tacan, is_active = coalesce(p_aktivno, true)
   where id = p_id;
  if not found then raise exception 'Pitanje ne postoji' using errcode = 'P0002'; end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function admin_osvajanje_sobe(p_pre timestamptz default null, p_broj int default 50)
returns table (id uuid, nacin text, velicina int, teren text, status text, napravljena timestamptz, pocela timestamptz,
  privatna boolean, savez boolean, igraci text, poteza int)
language plpgsql stable security definer set search_path = public as $$
declare n int := least(greatest(coalesce(p_broj, 50), 1), 200);
begin
  perform admin_provera();
  return query
  select s.id, s.nacin, s.velicina, s.teren, s.status, s.napravljena, s.pocela, s.privatna, s.savez,
         (select string_agg(coalesce(nullif(p.nickname, ''), p.first_name, 'Igrač'), ', ' order by m.mesto)
            from osvajanje_mesta m left join profiles p on p.id = m.user_id where m.soba = s.id),
         (select count(*)::int from osvajanje_potezi z where z.soba = s.id)
    from osvajanje_sobe s
   where p_pre is null or s.napravljena < p_pre
   order by s.napravljena desc limit n;
end $$;

-- karijera_43/44 (44: promenljiva od_danas, jer karijera_runde ima kolonu dan): brojevi za kontrolnu tablu admina (aplikacija, Karijera, Osvajanje, padovi).
create or replace function admin_pregled() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare od_danas timestamptz := date_trunc('day', now() at time zone 'Europe/Belgrade') at time zone 'Europe/Belgrade';
begin
  perform admin_provera();
  return jsonb_build_object(
    'app_partija', (select count(*) from rezultati_igara),
    'app_danas', (select count(*) from rezultati_igara where created_at >= od_danas),
    'karijera_rundi', (select count(*) from karijera_runde),
    'karijera_danas', (select count(*) from karijera_runde where kad >= od_danas),
    'karijera_igraca', (select count(*) from karijera_igraci),
    'firmi_igraca', (select count(*) from karijera_firme where vlasnik is not null and not zatvorena),
    'prijava_imena', (select count(distinct firma_id) from karijera_prijave_imena),
    'osvajanje_soba', (select count(*) from osvajanje_sobe),
    -- karijera_46: sobe nemaju stanje „kraj”, pa je aktivna ona sa potezom u poslednja 24 h.
    'osvajanje_u_toku', (select count(distinct soba) from osvajanje_potezi where created_at > now() - interval '24 hours'),
    'padova_7d', (select count(*) from izvestaji_o_padu where created_at > now() - interval '7 days')
  );
end $$;
revoke all on function admin_pregled() from public, anon;
grant execute on function admin_pregled() to authenticated;

-- karijera_42: urednik čita spisak struka (filter u pitanjima struka).
drop policy if exists "urednik cita pozicije" on karijera_pozicije;
create policy "urednik cita pozicije" on karijera_pozicije for select to authenticated using (is_admin_user());

-- Urednik čita izveštaje o padu aplikacije.
drop policy if exists "urednik cita padove" on izvestaji_o_padu;
create policy "urednik cita padove" on izvestaji_o_padu for select to authenticated using (is_admin_user());

-- Prijava pitanja iz aplikacije sada prepoznaje i Kafanski kviz i pitanja struka (Karijera).
create or replace function public.prijavi_pitanje(p_id uuid, p_razlog text)
 returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare izvor text; tekst text;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'greska', 'Prijavi se da bi prijavio pitanje.'); end if;
  if length(btrim(coalesce(p_razlog, ''))) < 3 then return jsonb_build_object('ok', false, 'greska', 'Napiši razlog.'); end if;
  select 'questions', question_text into izvor, tekst from questions where id = p_id;
  if izvor is null then select 'book_questions', question_text into izvor, tekst from book_questions where id = p_id; end if;
  if izvor is null then select 'kafana_questions', question_text into izvor, tekst from kafana_questions where id = p_id; end if;
  if izvor is null then select 'karijera_pitanja', question_text into izvor, tekst from karijera_pitanja where id = p_id; end if;
  if izvor is null then select 'hangman_words', word into izvor, tekst from hangman_words where id = p_id; end if;
  if izvor is null then return jsonb_build_object('ok', false, 'greska', 'Pitanje nije pronađeno.'); end if;
  if exists (select 1 from question_reports where question_id = p_id and user_id = auth.uid()) then return jsonb_build_object('ok', true, 'vec', true); end if;
  if (select count(*) from question_reports where user_id = auth.uid() and created_at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('ok', false, 'greska', 'Previše prijava, sačekaj malo.');
  end if;
  insert into question_reports (source, question_id, question_text, user_id, reason, status)
  values (izvor, p_id, tekst, auth.uid(), left(btrim(p_razlog), 1000), 'pending');
  -- Dva različita igrača gase pitanje do pregleda urednika (isto kao veb).
  if (select count(distinct user_id) from question_reports where question_id = p_id) >= 2 then
    execute format('update %I set is_active = false where id = $1', izvor) using p_id;
  end if;
  return jsonb_build_object('ok', true);
end;
$function$;

do $$ declare f text; begin
  foreach f in array array['admin_provera()', 'admin_aktivnost(text, uuid, timestamptz, int)', 'admin_karijera_firme()',
    'admin_karijera_firma(uuid, text)', 'admin_karijera_igraci()', 'admin_karijera_pitanja(text, text, uuid, int, uuid)',
    'admin_karijera_pitanje_sacuvaj(uuid, text, jsonb, int, boolean)', 'admin_osvajanje_sobe(timestamptz, int)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
