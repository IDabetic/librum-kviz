-- Karijera: slobodni dani i prekovremeno (vlasnik 05.11.2026). Primenjeno kao migracija karijera_24_slobodni_dani
-- (+ sređen dupli upis u karijera_podesi_slobodne). Skripta ispod je stanje posle obe izmene.
alter table karijera_firme add column if not exists slobodni int[] not null default '{}'
  check (coalesce(array_length(slobodni, 1), 0) <= 3 and slobodni <@ array[1,2,3,4,5,6,7]);
alter table karijera_firme add column if not exists slobodni_menjan date;
update karijera_firme set slobodni = '{6,7}' where korporacija;

create or replace function karijera_slobodan(f karijera_firme, p_dan date) returns boolean
language sql immutable set search_path = public as $$ select extract(isodow from p_dan)::int = any(f.slobodni) $$;
revoke execute on function karijera_slobodan(karijera_firme, date) from public, anon, authenticated;

create or replace function karijera_podesi_slobodne(p_firma uuid, p_dani int[]) returns jsonb
language plpgsql security definer set search_path = public as $$
declare f karijera_firme := karijera_moja_firma(p_firma); d int[] := array(select distinct x from unnest(coalesce(p_dani, '{}')) x order by 1);
begin
  if coalesce(array_length(d, 1), 0) > 3 or not d <@ array[1,2,3,4,5,6,7] then raise exception 'Najviše 3 slobodna dana u nedelji' using errcode = '22023'; end if;
  -- Promena jednom u 7 dana, da vlasnik ne pomera slobodan dan kad mu stigne izazov; prvo podešavanje je slobodno.
  if f.slobodni_menjan is not null and f.slobodni_menjan > karijera_danas() - 7 and d is distinct from f.slobodni then
    raise exception 'Slobodni dani se menjaju jednom u 7 dana (sledeća promena %)', to_char(f.slobodni_menjan + 7, 'DD.MM.') using errcode = '22023';
  end if;
  update karijera_firme set slobodni = d, slobodni_menjan = case when f.slobodni_menjan is null and f.slobodni = '{}' then null else karijera_danas() end where id = f.id;
  return karijera_firma(p_firma);
end $$;
revoke execute on function karijera_podesi_slobodne(uuid, int[]) from public, anon;
grant execute on function karijera_podesi_slobodne(uuid, int[]) to authenticated, service_role;

-- Izmene postojećih funkcija (pg_get_functiondef + replace), vidi migraciju karijera_24_slobodni_dani:
-- karijera_odrzi: propušteni dani vlasnika ne računaju slobodne dane firme.
-- karijera_obradi_izazove: rok izazova + 1 dan za svaki slobodan dan firme od slanja do danas.
-- karijera_posalji_izazov: na slobodan dan firme izazov se ne šalje.
-- karijera_zavrsi_rundu: na slobodan dan firme plata i kasa ×1,1; u rezultatu 'prekovremeno'.
-- karijera_firma_red: 'slobodni', 'slobodan_danas'.
