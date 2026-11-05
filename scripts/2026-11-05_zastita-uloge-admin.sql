-- Zaštita admin uloge — 05.11.2026, migracija karijera_52.
-- RUPA: politika profiles_update_own + UPDATE pravo na kolonu `role` značili su da svaki prijavljeni
-- korisnik preko javnog API-ja (PATCH /rest/v1/profiles?id=eq.<svoj id>) sebi upiše role='super_admin'
-- i uđe u /majmun. Isto za is_blocked (blokirani bi se sam odblokirao).
-- Sada: ulogu i blokadu menja samo super_admin (ili server/servisni ključ); nov profil uvek kreće kao 'user'.

create or replace function public.profiles_zastita_uloge() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  je_super boolean;
begin
  -- Server (service_role) i SQL konzola nemaju ulogu authenticated/anon: njima je dozvoljeno.
  if coalesce(auth.role(), '') not in ('authenticated', 'anon') then return new; end if;
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'super_admin') into je_super;
  if tg_op = 'INSERT' then
    if not je_super then new.role := 'user'; new.is_blocked := false; end if;
    return new;
  end if;
  if (new.role is distinct from old.role or new.is_blocked is distinct from old.is_blocked) and not je_super then
    raise exception 'Ulogu i blokadu menja samo glavni administrator.' using errcode = '42501';
  end if;
  return new;
end $$;
revoke all on function public.profiles_zastita_uloge() from public, anon, authenticated;

drop trigger if exists profiles_zastita_uloge on public.profiles;
create trigger profiles_zastita_uloge before insert or update on public.profiles
  for each row execute function public.profiles_zastita_uloge();

-- karijera_53: admin prava u bazi važe samo uz drugi korak prijave (aal2 u JWT-u), kao i panel /majmun.
-- Ukradena lozinka admina bez telefona = običan korisnik.
create or replace function public.is_admin_user() returns boolean
language sql stable security definer set search_path to 'public', 'auth' as $$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2' and exists (
    select 1 from public.profiles where id = auth.uid() and role in ('urednik', 'moderator', 'super_admin'))
$$;
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path to 'public' as $$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2' and exists (
    select 1 from public.profiles where id = auth.uid() and role in ('admin', 'super_admin'))
$$;
