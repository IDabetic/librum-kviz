-- Mejl kampanje (poziv da instaliraju aplikaciju) i odjava — 05.11.2026, migracija karijera_54.
-- Primaoci se upisuju jednom po kampanji; ruta /api/v1/kampanje/posalji šalje sledeću turu preko Resend-a
-- i upisuje `poslato` + Resend id. Odjava: link /odjava/<token> iz svakog mejla, važi za sve buduće kampanje.

create table if not exists public.mejl_odjave (
  user_id uuid primary key references auth.users on delete cascade,
  kad timestamptz not null default now()
);

create table if not exists public.mejl_kampanje_primaoci (
  kampanja text not null,
  user_id uuid not null references auth.users on delete cascade,
  token uuid not null default gen_random_uuid() unique,
  poslato timestamptz,
  resend_id text,
  greska text,
  primary key (kampanja, user_id)
);
create index if not exists mejl_kampanje_neposlati on public.mejl_kampanje_primaoci (kampanja) where poslato is null;

-- Samo server (service_role) čita i piše; javno nema pristupa.
alter table public.mejl_odjave enable row level security;
alter table public.mejl_kampanje_primaoci enable row level security;

/**
 * Odjava iz mejla bez prijave: token je nasumičan i stoji samo u mejlu tog korisnika.
 * Primer: select mejl_odjavi('5b1c...'::uuid);  -- true ako je token postojao
 */
create or replace function public.mejl_odjavi(p_token uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  korisnik uuid;
begin
  select user_id into korisnik from public.mejl_kampanje_primaoci where token = p_token;
  if korisnik is null then return false; end if;
  insert into public.mejl_odjave (user_id) values (korisnik) on conflict do nothing;
  return true;
end $$;
revoke all on function public.mejl_odjavi(uuid) from public;
grant execute on function public.mejl_odjavi(uuid) to anon, authenticated;

/**
 * Sledeća tura za slanje (samo service_role): potvrđen mejl, nije odjavljen, nije blokiran, nije probni nalog.
 * Primer: select * from mejl_kampanja_tura('aplikacija-2026-11', 100);
 */
create or replace function public.mejl_kampanja_tura(p_kampanja text, p_broj int)
returns table (user_id uuid, email text, nadimak text, token uuid)
language sql security definer set search_path = '' as $$
  select p.user_id, u.email::text, coalesce(nullif(trim(pr.nickname), ''), nullif(trim(pr.first_name), '')), p.token
  from public.mejl_kampanje_primaoci p
  join auth.users u on u.id = p.user_id
  left join public.profiles pr on pr.id = p.user_id
  where p.kampanja = p_kampanja and p.poslato is null
    and not exists (select 1 from public.mejl_odjave o where o.user_id = p.user_id)
  order by u.created_at
  limit least(greatest(p_broj, 1), 100)
$$;
revoke all on function public.mejl_kampanja_tura(text, int) from public, anon, authenticated;
grant execute on function public.mejl_kampanja_tura(text, int) to service_role;

-- Primaoci kampanje „aplikacija-2026-11”: potvrđeni mejlovi, bez blokiranih i probnih naloga.
insert into public.mejl_kampanje_primaoci (kampanja, user_id)
select 'aplikacija-2026-11', u.id
from auth.users u
left join public.profiles pr on pr.id = u.id
where u.email_confirmed_at is not null
  and u.email is not null
  and coalesce(pr.is_blocked, false) = false
  and (u.banned_until is null or u.banned_until < now())
  and u.deleted_at is null
  and u.email !~* '(@demo\.kviz\.librum\.club|\.test|@example\.)$'
on conflict do nothing;
