-- Probni igrači i aktivnost u Igračima (vlasnik 03.11.2026: „ubaci mokapove korisnike i aktivnosti kod igrača”).
-- Nalozi su označeni `raw_app_meta_data.demo = true`, bez lozinke (ne mogu da se prijave), sa adresom
-- na demo.kviz.librum.club (ne postoji, ništa se ne šalje). Objave, komentari, srca, praćenja i rezultati
-- vise o nalogu (ON DELETE CASCADE), pa se sve uklanja jednim redom:
--   delete from auth.users where raw_app_meta_data->>'demo' = 'true';

do $$
declare
  igraci jsonb := '[
    ["mila.kviz", "Mila", "Novi Sad", "animal_04.png", "Knjige, kafa i PRO kviz pre posla."],
    ["dzoni_bg", "Nikola", "Beograd", "animal_30.png", "Duel u bilo koje doba. Ne štedim pomoći."],
    ["sara.cita", "Sara", "Niš", "animal_37.png", "Klasici i Book kviz. Tražim tim za Osvajanje."],
    ["marko_osvajac", "Marko", "Kragujevac", "animal_40.png", "Evropa je moja. Afrika uskoro."],
    ["jelena.znalac", "Jelena", "Subotica", "animal_21.png", "Profesorka istorije, rado izazivam."],
    ["luka_brzi", "Luka", "Čačak", "animal_08.png", "Brzi kviz rekorder (zasad)."],
    ["ana.slikarka", "Ana", "Zrenjanin", "animal_20.png", "Slikari su moj teren."],
    ["stefan.pro", "Stefan", "Beograd", "animal_34.png", "PRO kviz niz 23. Ko više?"],
    ["teodora.v", "Teodora", "Kraljevo", "animal_12.png", "Vešanje i ukrštenice."],
    ["vuk_mudrac", "Vuk", "Valjevo", "animal_15.png", "Nivo 20, Mudrac. Pitaj šta hoćeš."],
    ["ivana.reci", "Ivana", "Pančevo", "animal_26.png", "Reči, reči, reči."],
    ["petar_duel", "Petar", "Šabac", "animal_45.png", "Duel 3 od 3. Prihvatam sve izazove."]
  ]';
  ids uuid[] := '{}';
  i int;
  novi uuid;
  o bigint;
  objave_ids bigint[] := '{}';
begin
  for i in 0 .. jsonb_array_length(igraci) - 1 loop
    novi := gen_random_uuid();
    -- Prazni stringovi umesto NULL u token kolonama: GoTrue (spisak korisnika u panelu) pada na NULL.
    insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
                            confirmation_token, recovery_token, email_change_token_new, email_change, email_change_token_current,
                            phone_change, phone_change_token, reauthentication_token)
    values ('00000000-0000-0000-0000-000000000000', novi, 'authenticated', 'authenticated',
            'demo-' || replace(igraci->i->>0, '_', '-') || '@demo.kviz.librum.club', now(), now() - (20 - i) * interval '1 day', now(),
            '{"provider":"email","providers":["email"],"demo":true}',
            jsonb_build_object('nickname', igraci->i->>0, 'first_name', igraci->i->>1, 'city', igraci->i->>2),
            '', '', '', '', '', '', '', '');
    update profiles set avatar = igraci->i->>3, bio = igraci->i->>4 where id = novi;
    ids := ids || novi;
  end loop;

  -- Objave: [ko (indeks), vrsta, igra, tekst, poeni, pre koliko sati]
  for i in 0 .. 15 loop
    insert into objave (ko, vrsta, igra, tekst, poeni, created_at)
    select ids[(x->>0)::int + 1], x->>1, nullif(x->>2, ''), x->>3, nullif(x->>4, '')::int, now() - (x->>5)::numeric * interval '1 hour'
    from (select ('[
      [7, "rezultat", "pro", "Niz 23 u PRO kvizu! Pitanje o Andriću me skoro oborilo.", "4120", 0.4],
      [1, "poziv_duel", "duel", "Ko sme na duel iz istorije? Tri runde, bez pomoći.", "", 0.9],
      [3, "poziv_tim", "osvajanje", "Treba mi saveznik za Evropu večeras u 21h. Ja držim Balkan.", "", 1.5],
      [6, "rezultat", "slikari", "10 od 10 u Slikarima! Vermer i Rembrant su lako, ali Kandinski...", "980", 2.2],
      [0, "tekst", "", "Ko još čita Majstora i Margaritu treći put? Book kviz me naterao.", "", 3],
      [5, "rezultat", "brzi", "Brzi kviz: 18 tačnih za minut. Ruka mi se trese.", "1840", 4.5],
      [4, "tekst", "", "Pitanje dana: koje godine je potpisan Berlinski ugovor? Bez guglanja!", "", 6],
      [8, "rezultat", "vesanje", "Pogodila sam reč „lastavica” sa jednim životom.", "320", 8],
      [9, "poziv_duel", "duel", "Mudrac traži dostojnog protivnika. Opšte znanje, 10 pitanja.", "", 10],
      [2, "rezultat", "book", "Book kviz, žanr Klasici: 14 pitanja zaredom.", "2260", 13],
      [11, "rezultat", "duel", "Treći duel zaredom dobijen. Sledeći?", "1500", 16],
      [10, "tekst", "", "Predlog za novu temu: srpski jezik i pravopis. Ko je za?", "", 20],
      [3, "rezultat", "osvajanje", "Osvojio celu Evropu za 14 krugova! Bot Lukavi je pao poslednji.", "3400", 26],
      [6, "poziv_tim", "osvajanje", "Tražim tim od troje za Osvajanje sveta, ozbiljni igrači.", "", 31],
      [7, "tekst", "", "Savet: 50/50 čuvaj za pitanja iz geografije, tu najviše grešim.", "", 40],
      [0, "rezultat", "dnevni", "Dnevni izazov 9/10. Fudbal me opet izdao.", "870", 50]
    ]'::jsonb)->i x) q
    returning id into o;
    objave_ids := objave_ids || o;
  end loop;

  -- Komentari: [objava (indeks), ko (indeks), tekst]
  insert into komentari (objava, ko, tekst, created_at)
  select objave_ids[(x->>0)::int + 1], ids[(x->>1)::int + 1], x->>2, now() - (random() * 3) * interval '1 hour'
  from jsonb_array_elements('[
    [0, 9, "Bravo! Ja sam stao na 19."], [0, 4, "Andrić je uvek zamka."], [0, 1, "Hajde duel pa da vidimo."],
    [1, 11, "Prihvatam! Šaljem izazov."], [1, 5, "Ja posle tebe."],
    [2, 2, "Ja sam tu! Uzimam Skandinaviju."], [2, 9, "Računajte i na mene."],
    [3, 0, "Kandinski je i mene prevario."], [3, 7, "Kako? Ja jedva 6."],
    [4, 2, "Ja! Svaki put nešto novo."], [4, 10, "Najbolja knjiga ikad."],
    [5, 7, "Ruka se trese, a 18 tačnih. Svaka čast."],
    [6, 9, "1878."], [6, 1, "Vuk opet prvi."], [6, 4, "Tačno! Bravo Vuče."],
    [8, 11, "Ja ću. Večeras u 20h?"], [8, 3, "I ja hoću posle."],
    [11, 2, "Za! I latinica i ćirilica."], [11, 8, "Može i ukrštenice."],
    [12, 6, "Lukavi je težak, svaka čast."], [12, 5, "14 krugova je brzo."]
  ]'::jsonb) x;

  -- Srca na objavama: svaka objava dobija nasumično od 2 do 9.
  insert into objave_srca (objava, ko, created_at)
  select o, ids[k], now() - random() * interval '20 hours'
  from unnest(objave_ids) o cross join generate_series(1, 12) k
  where random() < 0.5 on conflict do nothing;

  -- Praćenja: svako prati 3–6 drugih.
  insert into pracenja (ko, koga, created_at)
  select ids[a], ids[b], now() - random() * interval '10 days'
  from generate_series(1, 12) a cross join generate_series(1, 12) b
  where a <> b and random() < 0.4 on conflict do nothing;

  -- Rezultati igara (lobi i rang liste): po 3–8 partija u igrama iz aplikacije.
  insert into rezultati_igara (user_id, igra, poeni, tacnih, netacnih, prosek_ms, created_at)
  select ids[k], g, (300 + random() * 3500)::int, t, 10 - least(t, 10), (2500 + random() * 6000)::int, now() - random() * interval '7 days'
  from generate_series(1, 12) k
  cross join unnest(array['osvajanje', 'pro', 'book', 'duel', 'slikari', 'brzi', 'vesanje', 'tema']) g
  cross join lateral generate_series(1, 3 + (random() * 5)::int) n
  cross join lateral (select (4 + random() * 6)::int t) tt;

  -- „Igra sada” u lobiju (važi 5 minuta posle ubacivanja).
  insert into u_igri (user_id, igra, kad)
  select ids[k], (array['osvajanje', 'pro', 'duel', 'slikari', 'brzi'])[1 + (k % 5)], now() from generate_series(1, 6) k
  on conflict (user_id) do update set igra = excluded.igra, kad = excluded.kad;
end $$;
