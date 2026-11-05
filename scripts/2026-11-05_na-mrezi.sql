-- Igrači na mreži (feed u kartici Igrači, levo od Sandučeta) — 05.11.2026, migracija karijera_57.
-- Aplikacija javlja prisustvo na 30 s dok je otvorena (javi_prisustvo); „na mreži” = javio se u poslednjih 90 s.
-- Šta igra: poslednja partija/potez/runda u 15 min, inače „u aplikaciji”.
-- shortcut: igra se izvodi iz poslednje aktivnosti, ne iz ekrana na kome je igrač; kad zatreba tačno, aplikacija šalje p_igra.

create table if not exists public.prisustvo (
  user_id uuid primary key references auth.users on delete cascade,
  poslednje timestamptz not null default now(),
  od timestamptz not null default now(),
  igra text
);
create index if not exists prisustvo_poslednje on public.prisustvo (poslednje desc);
alter table public.prisustvo enable row level security;

/**
 * Otkucaj prisustva iz aplikacije (na 30 s dok je otvorena).
 * Primer: select javi_prisustvo('osvajanje');
 */
create or replace function public.javi_prisustvo(p_igra text default null) returns void
language sql security definer set search_path = 'public' as $$
  insert into prisustvo (user_id, poslednje, od, igra) values (auth.uid(), now(), now(), p_igra)
  on conflict (user_id) do update set
    poslednje = now(),
    od = case when prisustvo.poslednje < now() - interval '90 seconds' then now() else prisustvo.od end,
    igra = coalesce(excluded.igra, prisustvo.igra)
$$;
revoke all on function public.javi_prisustvo(text) from public, anon;
grant execute on function public.javi_prisustvo(text) to authenticated;

/**
 * Ko je sada na mreži (svi, ne samo praćeni): nadimak, avatar, šta igra, od kada; blokirani se ne vide.
 * Primer: select * from na_mrezi(100);
 */
create or replace function public.na_mrezi(p_broj int default 100)
returns table (ko uuid, nadimak text, avatar text, igra text, od timestamptz, pratim boolean)
language sql stable security definer set search_path = 'public' as $$
  select p.user_id,
    coalesce(nullif(pp.nickname, ''), nullif(pp.first_name, ''), 'Igrač'),
    pp.avatar,
    coalesce(
      (select x.igra from (
         select r.igra, r.created_at kad from rezultati_igara r where r.user_id = p.user_id and r.created_at > now() - interval '15 minutes'
         union all select 'karijera', k.kad from karijera_runde k where k.user_id = p.user_id and k.kad > now() - interval '15 minutes'
       ) x order by x.kad desc limit 1),
      p.igra),
    p.od,
    exists (select 1 from pracenja f where f.ko = auth.uid() and f.koga = p.user_id)
  from prisustvo p
  join public_profiles pp on pp.id = p.user_id
  where p.poslednje > now() - interval '90 seconds'
    and (auth.uid() is null or not blokirani(auth.uid(), p.user_id))
  order by (p.user_id = auth.uid()) desc, p.od desc
  limit least(greatest(p_broj, 1), 200)
$$;
revoke all on function public.na_mrezi(int) from public, anon;
grant execute on function public.na_mrezi(int) to authenticated;

-- Tabela ima najviše jedan red po igraču (upsert), pa ne raste i ne treba joj čišćenje.
