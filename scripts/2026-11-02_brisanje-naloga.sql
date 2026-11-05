-- Pravo brisanje naloga (do 02.11.2026 „Obriši nalog” je samo odjavljivao).
-- Briše isključivo nalog onoga ko poziva (auth.uid()). auth.users kaskadno
-- briše profil i sve sesije igara; logovi odgovora, prijave i predlozi pitanja
-- ostaju sa user_id = null (on delete set null), pa prihvaćena pitanja ne nestaju.
-- game_rooms.reset_requested_by nema on delete pravilo, zato se prvo prazni.

create or replace function public.obrisi_moj_nalog()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  ja uuid := auth.uid();
begin
  if ja is null then
    raise exception 'Nisi prijavljen' using errcode = '42501';
  end if;
  update public.game_rooms set reset_requested_by = null where reset_requested_by = ja;
  delete from auth.users where id = ja;
end;
$$;

revoke execute on function public.obrisi_moj_nalog() from public, anon;
grant execute on function public.obrisi_moj_nalog() to authenticated;
