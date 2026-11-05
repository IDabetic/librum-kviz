-- Karijera: pitanja struka samo za Karijeru (vlasnik 05.11.2026). Migracije karijera_27_pitanja_struke i karijera_28_fond_u_funkcijama.
-- 24.911 pitanja iz „novo kviz-pozicije.xlsx” (alati/karijera_pitanja_iz_xlsx.py). Ne ulaze u `questions`, pa ih druge igre ne vide.
create table if not exists karijera_pitanja (
  id uuid primary key default gen_random_uuid(),
  pozicija text not null references karijera_pozicije(id),
  question_text text not null,
  options jsonb not null check (jsonb_array_length(options) = 4),
  correct_answer int not null check (correct_answer between 0 and 3),
  difficulty text not null check (difficulty in ('easy','medium','hard','impossible')),
  tags text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (pozicija, question_text)
);
alter table karijera_pitanja enable row level security;
create index if not exists karijera_pitanja_tags_gin on karijera_pitanja using gin (tags);
revoke all on karijera_pitanja from anon, authenticated;

create or replace view karijera_fond as
  select q.id, q.question_text, q.options, q.correct_answer::int as correct_answer, q.difficulty, q.tags, q.is_active from questions q
  union all
  select k.id, k.question_text, k.options, k.correct_answer, k.difficulty, k.tags, k.is_active from karijera_pitanja k;
revoke all on karijera_fond from anon, authenticated;

-- Teme iz fajla dodate temama struke.
update karijera_pozicije p set teme = p.teme || array(
  select distinct t from karijera_pitanja k, unnest(k.tags) t where k.pozicija = p.id and not (t = any(p.teme)) order by 1);

-- U funkcijama bot_pomoc, duel_pitanja, duel_predaj, izvuci_deo, pitanja_teme, runda_pitanja, teme_firme, teme_pozicije,
-- zavrsi_rundu: `questions` → `karijera_fond` (regexp_replace nad pg_get_functiondef). Opšti deo runde (izvuci_opste),
-- teme fokusa i podesi_pitanja ostaju na `questions`.
-- Uvoz je išao kroz privremenu funkciju karijera_uvoz_pitanja sa jednokratnom tajnom; obrisana odmah posle uvoza.
