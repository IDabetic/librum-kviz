-- Nov nalog preko Google ili Apple prijave (vlasnik 03.11.2026): ime i prezime iz naloga provajdera.
-- Google šalje given_name/family_name (i full_name), registracija mejlom first_name/last_name.
-- Nadimak ostaje prazan: app posle prve prijave traži da ga korisnik izabere (jedinstven je).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare
  avatar_name text;
  m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  avatar_name := 'animal_' || lpad((1 + floor(random() * 50))::int::text, 2, '0') || '.png';

  insert into public.profiles (id, email, first_name, last_name, phone, nickname, city, avatar)
  values (
    new.id,
    new.email,
    coalesce(nullif(m->>'first_name', ''), nullif(m->>'given_name', ''), split_part(coalesce(m->>'full_name', m->>'name', ''), ' ', 1)),
    coalesce(nullif(m->>'last_name', ''), nullif(m->>'family_name', ''),
             nullif(btrim(substr(coalesce(m->>'full_name', m->>'name', ''), length(split_part(coalesce(m->>'full_name', m->>'name', ''), ' ', 1)) + 1)), ''), ''),
    coalesce(m->>'phone', ''),
    nullif(m->>'nickname', ''),
    nullif(m->>'city', ''),
    avatar_name
  );
  return new;
end;
$$;
