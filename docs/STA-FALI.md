# Librum kviz: šta fali (spisak za odluku)

Ažurirano: 03.11.2026. · verzija 1 · posle prolaska kroz iOS i Android aplikaciju i bazu

Oznake: **[T]** treba tvoj ključ ili nalog · **[P]** predlog funkcije, čeka tvoje „da” · bez oznake = greška ili rupa koju zatvaram sam.

## A. Pred objavu u prodavnicama (obavezno)

1. **[T] Prijava preko Apple naloga.** Apple traži da je ima svaka aplikacija koja nudi Google prijavu. Treba Services ID i ključ (.p8) iz Apple Developer naloga, pa uključivanje u Supabase → Auth → Providers.
2. **[T] Prijava preko Google naloga.** Treba OAuth Client ID za iOS, Android i veb iz Google Cloud konzole.
3. **[T] Firebase obaveštenja.** Fajlovi `GoogleService-Info.plist` i `google-services.json` trenutno pokazuju na projekat Librum eBook (`librum-ebook-c0f24`). Treba odlučiti: poseban Firebase projekat za kviz ili deljeni. Treba i APNs ključ (.p8).
4. **[T] Objava funkcije `obavesti`** (izazov, pratilac, komentar, poruka) sa Firebase servisnim ključem.
5. **Ikonica aplikacije.** Sada je jedna slika od 1024 px; treba lepša, sa slojem za tamni režim (iOS 18+) i adaptivnom ikonom na Androidu.
6. **Ekran za pokretanje (splash)** u boji brenda na oba telefona, bez belog bljeska.
7. **[T] App Store Connect i Google Play** zapisi: opis, ključne reči, slike ekrana (6,9" i 6,5"), kategorija, ocena uzrasta, upitnik o privatnosti.
8. **Brisanje naloga iz aplikacije** postoji; proveriti da briše i objave, poruke i viđena pitanja (Apple pravilo 5.1.1).
9. **Univerzalni linkovi** (`kviz.librum.club/duel/KOD`) traže `apple-app-site-association` i `assetlinks.json` na sajtu.
10. **Pravila zajednice za UGC (Apple 1.2)**: prijava, blokada i pravila postoje; fali vidljiv kontakt i obaveza odgovora u roku od 24 h u uslovima (dodato u uslove v2).

## B. Igre i bodovanje

11. **Osvajanje:** nastavak partije posle zatvaranja aplikacije (stanje je već na serveru, fali „Nastavi partiju” na početnoj).
12. **Osvajanje:** chat ili brze poruke u partiji („Napadam te!”, „Savez?”).
13. **[P] Osvajanje: savezi** između igrača u režimu „Svako za sebe” (privremeni, do kraja kruga).
14. **Osvajanje:** kraj partije sa tabelom (države, vojske, tačni odgovori) i XP po mestu, ne samo poruka.
15. **Osvajanje:** rang lista ne razlikuje pobedu nad botovima i nad ljudima; predlog da pobeda nad ljudima nosi više.
16. **PRO kviz:** prikaz kombo niza i sledećeg bonusa tokom igre (pravila postoje, prikaz je slab).
17. **Duel:** brzi meč sa nasumičnim rivalom („Nađi rivala”) postoji na iOS-u; na Androidu samo soba kodom i izazov.
18. **Duel:** ELO ili rejting, da jači igraju sa jačim.
19. **Vešanje:** igra za dvoje uživo postoji na vebu, fali u aplikaciji.
20. **Brzi kviz:** zvuk i vibracija na tačno i netačno (prekidač za vibraciju fali u podešavanjima).
21. **Kafanski kviz (muzika)** postoji na vebu, fali u aplikaciji.
22. **Kviz po kategoriji** iz novih pitanja: 14 kategorija iz uvoza (sport, muzika, film…) i 9 iz srbija-kviz još nemaju svoje kartice.
23. **Težina pitanja:** 99% pitanja je „medium“; treba automatski računati težinu iz procenta tačnih odgovora.
24. **Dnevni izazov:** niz dana (streak) i obaveštenje „Novi izazov je stigao” u 9 h.
25. **[P] Nedeljni turnir:** isti set od 20 pitanja za sve, nagrada bedž.

## C. Profil, zajednica i napredak

26. **Bedževi:** 16 postoji, većina se ne vidi kako se dobija; dodati opis uslova na zaključanom bedžu.
27. **Nivoi:** XP raste, ali nivo ništa ne otključava osim „Nemoguća pitanja”; predlog: okviri avatara, teme, nove igre.
28. **Izmena profila na Androidu** (ime, grad, opis, avatar) fali; postoji samo na iOS-u.
29. **Spisak blokiranih na Androidu** fali (iOS ga ima).
30. **Pratioci i praćeni** (spisak) na Androidu fali.
31. **Pretraga u porukama** i brisanje razgovora.
32. **Objava sa slikom rezultata** (deljenje kartice rezultata na Instagram, WhatsApp).
33. **Pozovi prijatelje** iz imenika ili linkom, sa nagradom (npr. +3 pomoći).
34. **Obaveštenje u aplikaciji** kad neko prihvati izazov ili ti preuzme državu.

## D. Sadržaj i admin

35. **51.284 otvorena pitanja** (samo tačan odgovor) čekaju: ili netačni odgovori, ili nova igra „Upiši odgovor”.
36. **621 pitanje za pregled** u `~/Downloads/kviz-srpski-pregled.csv` (prevod, skoro duplikati).
37. **Admin: pregled pitanja po kategoriji** i masovno isključivanje (sada samo jedno po jedno).
38. **Admin: statistika** po igri (koliko partija dnevno, aktivni igrači, prosečna tačnost).
39. **Admin: poruka svima** i verzija aplikacije („obavezno ažuriranje”).
40. **Admin: moderacija poruka** kada je poruka prijavljena (sada samo objave i komentari).

## E. Tehnika i bezbednost

41. **Nadzor grešaka** (pad aplikacije) na oba telefona; sada se ništa ne beleži.
42. **Rok odgovora servera:** spora mreža na Osvajanju; dodati „Nema mreže” traku i ponovni pokušaj.
43. **Rad bez mreže:** keš od 60 pitanja postoji; proširiti na 300 za PRO.
44. **Pristupačnost:** VoiceOver i TalkBack natpisi na mapi Osvajanja (države nemaju glasovni opis pri dodiru).
45. **Testovi:** UI test za tok prijave i duel; sada su testovi samo za pravila.
46. **Ograničenje zahteva** za poruke i objave (zaštita od spama) na serveru.
47. **Bekap baze** na Supabase Free nema automatske kopije; predlog: noćni `pg_dump` na NAS.
