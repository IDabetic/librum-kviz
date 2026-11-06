-- Obaveštenja iz admina u aplikaciju (vlasnik 06.11.2026), migracija karijera_64.
-- Admin piše naslov i tekst, uključuje/isključuje, bira period i platformu; aplikacija prikazuje karticu na početnoj,
-- a „Pošalji i na telefon” šalje isti tekst kao push (funkcija obavesti, table = 'obavestenja_app').

create table if not exists public.obavestenja_app (
  id bigint generated always as identity primary key,
  naslov text not null check (length(btrim(naslov)) between 1 and 80),
  tekst text not null check (length(btrim(tekst)) between 1 and 500),
  ukljuceno boolean not null default false,
  od timestamptz,
  do_kad timestamptz,
  platforma text not null default 'sve' check (platforma in ('sve', 'ios', 'android')),
  poslat_push timestamptz,
  created_at timestamptz not null default now()
);
alter table public.obavestenja_app enable row level security;

/**
 * Aktivna obaveštenja za aplikaciju (bez prijave), najnovije prvo.
 * Primer: select * from aktivna_obavestenja('ios');
 */
create or replace function public.aktivna_obavestenja(p_platforma text default 'sve')
returns table (id bigint, naslov text, tekst text, created_at timestamptz)
language sql stable security definer set search_path = 'public' as $$
  select o.id, o.naslov, o.tekst, o.created_at from obavestenja_app o
  where o.ukljuceno and (o.od is null or o.od <= now()) and (o.do_kad is null or o.do_kad > now())
    and (o.platforma = 'sve' or o.platforma = p_platforma)
  order by o.created_at desc limit 5
$$;
grant execute on function public.aktivna_obavestenja(text) to anon, authenticated;

/** Admin: sva obaveštenja. Primer: select * from admin_obavestenja(); */
create or replace function public.admin_obavestenja()
returns setof public.obavestenja_app
language plpgsql stable security definer set search_path = 'public' as $$
begin
  perform admin_provera();
  return query select * from obavestenja_app order by created_at desc;
end $$;

/**
 * Admin: novo (p_id null) ili izmena obaveštenja; vraća id.
 * Primer: select admin_obavestenje_sacuvaj(null, 'Nova igra', 'Probaj Karijeristu!', true, null, null, 'sve');
 */
create or replace function public.admin_obavestenje_sacuvaj(p_id bigint, p_naslov text, p_tekst text, p_ukljuceno boolean,
  p_od timestamptz, p_do timestamptz, p_platforma text)
returns bigint
language plpgsql security definer set search_path = 'public' as $$
declare novi bigint;
begin
  perform admin_provera();
  if p_id is null then
    insert into obavestenja_app (naslov, tekst, ukljuceno, od, do_kad, platforma)
    values (btrim(p_naslov), btrim(p_tekst), p_ukljuceno, p_od, p_do, p_platforma) returning id into novi;
    return novi;
  end if;
  update obavestenja_app set naslov = btrim(p_naslov), tekst = btrim(p_tekst), ukljuceno = p_ukljuceno, od = p_od, do_kad = p_do,
    platforma = p_platforma where id = p_id;
  return p_id;
end $$;

/** Admin: brisanje. Primer: select admin_obavestenje_obrisi(3); */
create or replace function public.admin_obavestenje_obrisi(p_id bigint) returns void
language plpgsql security definer set search_path = 'public' as $$
begin
  perform admin_provera();
  delete from obavestenja_app where id = p_id;
end $$;

/**
 * Admin: isti tekst kao push svima koji su dozvolili obaveštenja (na izabranoj platformi); jednom po obaveštenju.
 * Primer: select admin_obavestenje_push(3);
 */
create or replace function public.admin_obavestenje_push(p_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare o public.obavestenja_app; tajna text;
begin
  perform public.admin_provera();
  select * into o from public.obavestenja_app where id = p_id for update;
  if not found then raise exception 'Obaveštenje ne postoji' using errcode = '22023'; end if;
  if o.poslat_push is not null then raise exception 'Ovo obaveštenje je već poslato na telefone' using errcode = '22023'; end if;
  select decrypted_secret into tajna from vault.decrypted_secrets where name = 'OBAVESTI_TAJNA';
  perform net.http_post(
    url := 'https://htnfatughrtmbgtekxfs.supabase.co/functions/v1/obavesti',
    body := jsonb_build_object('type', 'INSERT', 'table', 'obavestenja_app', 'record', to_jsonb(o)),
    headers := jsonb_build_object('content-type', 'application/json', 'x-obavesti-tajna', tajna),
    timeout_milliseconds := 30000);
  update public.obavestenja_app set poslat_push = now() where id = p_id;
end $$;

revoke all on function public.admin_obavestenja() from public, anon;
revoke all on function public.admin_obavestenje_sacuvaj(bigint, text, text, boolean, timestamptz, timestamptz, text) from public, anon;
revoke all on function public.admin_obavestenje_obrisi(bigint) from public, anon;
revoke all on function public.admin_obavestenje_push(bigint) from public, anon;
grant execute on function public.admin_obavestenja() to authenticated;
grant execute on function public.admin_obavestenje_sacuvaj(bigint, text, text, boolean, timestamptz, timestamptz, text) to authenticated;
grant execute on function public.admin_obavestenje_obrisi(bigint) to authenticated;
grant execute on function public.admin_obavestenje_push(bigint) to authenticated;
