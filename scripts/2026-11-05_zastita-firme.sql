-- Vlasnik bira zaštitu firme od napada: 3, 5, 7 ili 10 dana (vlasnik 05.11.2026), migracija karijera_60.
-- Bira se jednom po vlasništvu (od vlasnik_od), da bi se firma izgradila pre prvog duela. Novi vlasnik (preuzimanje) bira ponovo.

alter table public.karijera_firme add column if not exists zastita_izabrana boolean not null default false;

/**
 * Primer: select karijera_zastita('cd2dc0f5-...'::uuid, 10);  -- zaštita do vlasnik_od + 10 dana
 */
create or replace function public.karijera_zastita(p_firma uuid, p_dana int) returns timestamptz
language plpgsql security definer set search_path = 'public' as $$
declare
  f karijera_firme;
  do_kad timestamptz;
begin
  if p_dana not in (3, 5, 7, 10) then raise exception 'Zaštita je 3, 5, 7 ili 10 dana' using errcode = '22023'; end if;
  select * into f from karijera_firme where id = p_firma for update;
  if not found or f.vlasnik is distinct from auth.uid() then raise exception 'Samo vlasnik bira zaštitu firme' using errcode = '42501'; end if;
  if f.zastita_izabrana then raise exception 'Zaštita je već izabrana za ovo vlasništvo' using errcode = '22023'; end if;
  do_kad := f.vlasnik_od + make_interval(days => p_dana);
  if do_kad <= now() then raise exception 'Taj rok je već prošao, izaberi duži' using errcode = '22023'; end if;
  update karijera_firme set zastita_do = greatest(coalesce(zastita_do, now()), do_kad), zastita_izabrana = true where id = p_firma;
  return greatest(coalesce(f.zastita_do, now()), do_kad);
end $$;
revoke all on function public.karijera_zastita(uuid, int) from public, anon;
grant execute on function public.karijera_zastita(uuid, int) to authenticated;

-- karijera_60 (nastavak) i 61: karijera_prenesi vraća zastita_izabrana = false; karijera_firma_red vraća zastita_izabrana i vlasnik_od
-- (izmena postojećih funkcija zamenom teksta u pg_get_functiondef, vidi istoriju migracija u Supabase-u).
