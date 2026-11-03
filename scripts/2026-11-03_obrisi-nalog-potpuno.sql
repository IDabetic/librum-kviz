-- Brisanje naloga (Apple 5.1.1, GDPR), PRIMENJENO 03.11.2026: pored kaskada iz auth.users (objave, komentari,
-- poruke, praćenja, viđena pitanja, rezultati, sobe Osvajanja) briše email iz predloga i brojač doprinosa;
-- dnevnici odgovora ostaju bez korisnika (anonimna statistika pitanja).
create or replace function public.obrisi_moj_nalog()
returns void language plpgsql security definer set search_path to 'public', 'auth' as $$
declare ja uuid := auth.uid();
begin
  if ja is null then raise exception 'Nisi prijavljen' using errcode = '42501'; end if;
  update public.game_rooms set reset_requested_by = null where reset_requested_by = ja;
  update public.question_submissions set submitter_email = null where submitted_by = ja;
  delete from public.contributor_counts where user_id = ja;
  delete from auth.users where id = ja;
end;
$$;
