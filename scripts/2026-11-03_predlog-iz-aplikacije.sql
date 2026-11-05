-- Predlog pitanja ili reči za vešanje iz aplikacije (03.11.2026). Ista pravila kao veb (src/lib/submit-pitanja.ts):
-- pitanje + tačan + tačno 3 različita netačna; za vešanje pojam 4–18 slova, opis bez pojma, jedna od 6 kategorija.
-- Autor je uvek auth.uid(); duplikat (normalizovan tekst) u fondu ili među predlozima se odbija; 100 dnevno, 500 na čekanju.

create or replace function public.posalji_predlog(p_segment text, p_pitanje text, p_tacan text, p_netacni text[] default '{}', p_zanr text default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  ja uuid := auth.uid();
  pitanje text := btrim(coalesce(p_pitanje, ''));
  tacan text := btrim(coalesce(p_tacan, ''));
  netacni text[] := array(select btrim(x) from unnest(coalesce(p_netacni, '{}')) x where btrim(x) <> '');
  kljuc text := lower(regexp_replace(btrim(coalesce(p_pitanje, '')), '\s+', ' ', 'g'));
  slova int;
begin
  if ja is null then return jsonb_build_object('ok', false, 'greska', 'Prijavi se da bi poslao predlog.'); end if;
  if p_segment not in ('pro', 'book', 'vesanje') then return jsonb_build_object('ok', false, 'greska', 'Nepoznata vrsta predloga.'); end if;
  if exists (select 1 from profiles where id = ja and is_blocked) then return jsonb_build_object('ok', false, 'greska', 'Nalog ne može da šalje predloge.'); end if;
  if pitanje = '' or tacan = '' then return jsonb_build_object('ok', false, 'greska', 'Popuni pitanje i tačan odgovor.'); end if;
  if length(pitanje) > 1000 or length(tacan) > 500 then return jsonb_build_object('ok', false, 'greska', 'Predlog je predugačak.'); end if;

  if p_segment = 'vesanje' then
    slova := length(regexp_replace(pitanje, '[^[:alpha:]]', '', 'g'));
    if slova < 4 or slova > 18 then return jsonb_build_object('ok', false, 'greska', 'Pojam mora da ima od 4 do 18 slova.'); end if;
    if position(lower(pitanje) in lower(tacan)) > 0 then return jsonb_build_object('ok', false, 'greska', 'Opis ne sme da sadrži sam pojam.'); end if;
    if coalesce(p_zanr, '') not in ('Sport', 'Geografija', 'Istorija', 'Kultura', 'Priroda', 'Predmeti') then
      return jsonb_build_object('ok', false, 'greska', 'Izaberi kategoriju.');
    end if;
    netacni := '{}';
  else
    if cardinality(netacni) <> 3 then return jsonb_build_object('ok', false, 'greska', 'Upiši tačno tri netačna odgovora.'); end if;
    if (select count(distinct lower(x)) from unnest(array[tacan] || netacni) x) <> 4 then
      return jsonb_build_object('ok', false, 'greska', 'Svi odgovori moraju da budu različiti.');
    end if;
    if p_segment = 'book' and coalesce(btrim(p_zanr), '') = '' then return jsonb_build_object('ok', false, 'greska', 'Izaberi žanr.'); end if;
  end if;

  if (select count(*) from question_submissions where submitted_by = ja and created_at > now() - interval '1 day') >= 100 then
    return jsonb_build_object('ok', false, 'greska', 'Danas si poslao 100 predloga. Nastavi sutra.');
  end if;
  if (select count(*) from question_submissions where submitted_by = ja and status = 'pending') >= 500 then
    return jsonb_build_object('ok', false, 'greska', 'Imaš 500 predloga koji čekaju pregled.');
  end if;
  if exists (select 1 from question_submissions where segment = p_segment and lower(regexp_replace(btrim(question_text), '\s+', ' ', 'g')) = kljuc)
     or (p_segment = 'pro' and exists (select 1 from questions where lower(regexp_replace(btrim(question_text), '\s+', ' ', 'g')) = kljuc))
     or (p_segment = 'book' and exists (select 1 from book_questions where lower(regexp_replace(btrim(question_text), '\s+', ' ', 'g')) = kljuc))
     or (p_segment = 'vesanje' and exists (select 1 from hangman_words where lower(btrim(word)) = kljuc)) then
    return jsonb_build_object('ok', false, 'greska', 'Ovo pitanje već postoji ili čeka pregled.');
  end if;

  insert into question_submissions (question_text, correct_answer, wrong_answers, segment, genre, source, status, submitted_by)
  values (pitanje, tacan, netacni, p_segment, nullif(btrim(coalesce(p_zanr, '')), ''), 'aplikacija', 'pending', ja);
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.posalji_predlog(text, text, text, text[], text) from public, anon;
grant execute on function public.posalji_predlog(text, text, text, text[], text) to authenticated;

-- Izvor „aplikacija” (admin vidi odakle je predlog stigao).
alter table public.question_submissions drop constraint question_submissions_source_chk;
alter table public.question_submissions add constraint question_submissions_source_chk check (source = any (array['form', 'xml', 'xlsx', 'aplikacija']));

-- profil_igraca dobija i 'poslao_pitanja' (svi predlozi) i 'u_igri_pitanja' (prihvaćeni), vidljivo svima;
-- primenjeno kroz replace u postojećoj definiciji (vidi 2026-11-03_profil-kao-ig.sql):
--   'poslao_pitanja', (select count(*) from question_submissions where submitted_by = p.id),
--   'u_igri_pitanja', (select count(*) from question_submissions where submitted_by = p.id and status = 'accepted'),
