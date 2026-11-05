# Apple App Review: odgovor na zahtev za dodatne informacije

Ažurirano: 04.11.2026. · verzija 1 · app „Librum kviz” (club.librum.kviz, 6830091653), verzija 1.0

Apple je 04.11.2026. vratio verziju 1.0 (REJECTED, „We need additional information”) i traži:
snimak ekrana sa pravog telefona, opis namene, uputstvo, spisak spoljnih servisa, regionalne razlike i prava na sadržaj.

## Šta vlasnik radi (ne može sa računara)

1. **Snimak ekrana na pravom iPhonu** (iOS 26/27, Control Center → Screen Recording), 3–5 min, redom:
   1. pokretanje aplikacije (od ikonice);
   2. „Napravi nalog” (registracija), pa odjava i „Već imam nalog” (prijava demo nalogom ispod);
   3. jedna partija (Brzi kviz ili Osvajanje sveta: biranje država, karta misije, jedna bitka);
   4. Igrači → objava → tri tačke → „Prijavi objavu”, pa profil igrača → „Blokiraj”;
   5. Profil → zupčanik (Podešavanja) → „Obriši nalog” → potvrda (snimati na probnom nalogu, ne na demo nalogu!).
2. Snimak postaviti na link koji Apple može da otvori (iCloud link ili kviz.librum.club/pregled.mp4), pa link upisati
   na početak polja Notes. Snimak se može i priložiti u App Review Information → Attachment.

## Tekst za polje „Notes” (App Review Information), engleski

```
SCREEN RECORDING (physical iPhone, latest iOS): <LINK DO SNIMKA>
It starts with launching the app and shows: account registration, login, a full game, reporting and blocking user content, and account deletion (Profile > gear icon > Settings > "Obriši nalog" = Delete account).

1. PURPOSE AND AUDIENCE
Librum kviz is a Serbian-language trivia game for adults and teenagers (17+ because the "Slikari" art quiz shows classical paintings, including nudes). It helps players learn general knowledge, geography, literature and art through short games: quick quizzes, PRO quiz, Book quiz (questions from classic Serbian and world literature), Hangman, Painters (art), Duel with a friend, and the main game "Osvajanje sveta" (World Conquest), a strategy map game in which every battle is decided by quiz questions. Value: free, ad-free learning through play, in the players' own language, alone or with friends.

2. HOW TO ACCESS THE MAIN FEATURES
- All games can be played without an account ("Igraj bez naloga" on the welcome screen).
- An account is needed only for online features (duels, rooms with friends, community, leaderboard).
- Demo account: demo-stefan.pro@demo.kviz.librum.club / password: <LOZINKA IZ .env.pregled>
- Main game: Games tab > "Osvajanje sveta" > "Protiv računara" > "Igraj". Choose 6 countries, draw a secret mission card, then tap your country and a neighbour to attack; answer the questions.
- Community: Igrači (Players) tab > posts; each post and comment has "Prijavi" (Report) and each profile has "Blokiraj" (Block). Reports are reviewed by moderators within 24 hours.
- Account deletion: Profil > gear icon > "Obriši nalog" > "Obriši zauvek". It deletes the account and all data on the server. Also available on the web: https://kviz.librum.club/brisanje-naloga
- No in-app purchases, no subscriptions, no ads, no paid content.

3. EXTERNAL SERVICES
- Supabase (EU, Frankfurt): authentication, database, real-time game rooms.
- Sign in with Apple and Google Sign-In: optional login.
- Apple Push Notification service: duel invitations and turn reminders.
- kviz.librum.club (our own server, Vercel EU): images for the Painters quiz, privacy policy, terms, account deletion page.
- No AI services, no analytics or advertising SDKs, no payment processors.

4. REGIONAL DIFFERENCES
The app works the same in every region. All content is in Serbian (Latin script). There are no region-specific features.

5. THIRD-PARTY MATERIAL
All quiz questions are written by our editorial team. Paintings in the "Slikari" quiz come from Wikimedia Commons under their stated licences (almost all are public-domain works); the source page of every image is stored with it. The world map is based on Natural Earth (public domain). Sounds and illustrations are our own. The app is not in a regulated industry.
```

## Napomena o slikama (proveriti pre slanja)

U `src/lib/igre/slikari.json` je 10 od 1.167 dela nastalih posle 1955; ta mogu biti pod autorskim pravom
(Wikimedia ih drži pod svojim licencama). Tekst za Apple zato ne tvrdi da je sve javno dobro.

## Tekst odgovora u Resolution Center (engleski)

```
Hello,

Thank you for the review. We have added all requested information to the App Review Information > Notes field:
a screen recording on a physical iPhone running the latest iOS (launch, registration, login, gameplay, reporting/blocking of user content and account deletion), the app's purpose and audience, access instructions with a demo account, the list of external services, regional behaviour, and the source of third-party material.

We also uploaded a new build with bug fixes from our own testing on physical devices.

Kind regards,
Ivan Dabetić, Librum kviz
```
