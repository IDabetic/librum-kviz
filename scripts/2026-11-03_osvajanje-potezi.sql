-- Osvajanje preko servera (03.11.2026): dnevnik poteza po sobi. Domaćin (mesto 0) šalje početno stanje i vodi botove;
-- svaki igrač posle svog poteza šalje stanje mape; bitka protiv pravog igrača ide kao par „bitka” → „odbrana”.
-- Telefoni čitaju nove redove (rb > poslednji viđeni) na svake 1,5 s.

create table if not exists public.osvajanje_potezi (
  soba uuid not null references public.osvajanje_sobe (id) on delete cascade,
  rb int not null,
  ko uuid not null references auth.users (id) on delete cascade,
  akcija jsonb not null,
  created_at timestamptz not null default now(),
  primary key (soba, rb)
);
alter table public.osvajanje_potezi enable row level security;

-- Upis sledećeg poteza; redni broj dodeljuje server pod bravom sobe, pa dva upisa ne dobijaju isti broj.
create or replace function public.osvajanje_upisi(p_soba uuid, p_akcija jsonb)
returns int language plpgsql security definer set search_path to 'public' as $$
declare novi int;
begin
  if not exists (select 1 from osvajanje_mesta where soba = p_soba and user_id = auth.uid()) then
    raise exception 'nisi u ovoj sobi';
  end if;
  if octet_length(p_akcija::text) > 64000 then raise exception 'potez je prevelik'; end if;
  perform pg_advisory_xact_lock(hashtext(p_soba::text));
  select coalesce(max(rb), 0) + 1 into novi from osvajanje_potezi where soba = p_soba;
  insert into osvajanje_potezi (soba, rb, ko, akcija) values (p_soba, novi, auth.uid(), p_akcija);
  return novi;
end;
$$;

-- Potezi posle rednog broja p_od (samo članovima sobe).
create or replace function public.osvajanje_potezi_od(p_soba uuid, p_od int)
returns table (rb int, ko uuid, akcija jsonb)
language sql stable security definer set search_path to 'public' as $$
  select p.rb, p.ko, p.akcija from osvajanje_potezi p
  where p.soba = p_soba and p.rb > p_od
    and exists (select 1 from osvajanje_mesta m where m.soba = p_soba and m.user_id = auth.uid())
  order by p.rb
  limit 200;
$$;

revoke all on function public.osvajanje_upisi(uuid, jsonb), public.osvajanje_potezi_od(uuid, int) from public, anon;
grant execute on function public.osvajanje_upisi(uuid, jsonb), public.osvajanje_potezi_od(uuid, int) to authenticated;
