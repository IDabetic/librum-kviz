-- Osvajanje sveta: vojska svakog igrača i timovi po izboru domaćina (vlasnik 04.11.2026).
-- Bag: gost u partiji na poziv nije mogao da bira vojsku; domaćinov telefon pravi početno stanje i nije znao gostov izbor.
-- Sada svako bira vojsku u čekaonici (osvajanje_izaberi_vojsku), a domaćin raspoređuje mesta po timovima
-- (osvajanje_postavi_timove: npr. ["A","A","B","B"] = ja i prijatelj protiv dva bota). Aditivno: stari klijenti rade kao pre.

alter table public.osvajanje_mesta add column if not exists vojska text
  check (vojska is null or vojska in ('legija', 'garda', 'graditelji', 'izvidnica', 'konjica', 'mudraci'));
-- Tim po mestu za stolom (dužina = velicina); null = podrazumevani raspored po načinu igre.
alter table public.osvajanje_sobe add column if not exists timovi jsonb;

create or replace function public.osvajanje_soba(p_soba uuid)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id', s.id, 'nacin', s.nacin, 'velicina', s.velicina, 'teren', s.teren, 'status', s.status, 'napravljena', s.napravljena,
    'kod', s.kod, 'privatna', s.privatna, 'timovi', s.timovi,
    'mesta', coalesce((select json_agg(json_build_object('user_id', m.user_id, 'mesto', m.mesto, 'vojska', m.vojska,
                                                         'nadimak', coalesce(p.nickname, p.first_name, 'Igrač'), 'avatar', p.avatar) order by m.mesto)
                       from osvajanje_mesta m left join public_profiles p on p.id = m.user_id where m.soba = s.id), '[]'::json))
  from osvajanje_sobe s
  where s.id = p_soba and exists (select 1 from osvajanje_mesta m where m.soba = s.id and m.user_id = auth.uid());
$$;

-- Svaki igrač bira svoju vojsku dok soba čeka.
create or replace function public.osvajanje_izaberi_vojsku(p_soba uuid, p_vojska text)
returns json language plpgsql security definer set search_path = public as $$
begin
  update osvajanje_mesta m set vojska = p_vojska
  from osvajanje_sobe s
  where m.soba = p_soba and m.user_id = auth.uid() and s.id = m.soba and s.status = 'ceka';
  return osvajanje_soba(p_soba);
end;
$$;

-- Domaćin (mesto 0) raspoređuje mesta po timovima: niz slova A–F, jedno po mestu.
create or replace function public.osvajanje_postavi_timove(p_soba uuid, p_timovi jsonb)
returns json language plpgsql security definer set search_path = public as $$
declare v_velicina int;
begin
  select s.velicina into v_velicina from osvajanje_sobe s
  where s.id = p_soba and s.status = 'ceka'
    and exists (select 1 from osvajanje_mesta m where m.soba = s.id and m.user_id = auth.uid() and m.mesto = 0);
  if v_velicina is null then raise exception 'Timove raspoređuje domaćin dok soba čeka'; end if;
  if jsonb_typeof(p_timovi) <> 'array' or jsonb_array_length(p_timovi) <> v_velicina
     or exists (select 1 from jsonb_array_elements(p_timovi) t where jsonb_typeof(t) <> 'string' or t #>> '{}' !~ '^[A-F]$') then
    raise exception 'Neispravan raspored timova';
  end if;
  update osvajanje_sobe set timovi = p_timovi where id = p_soba;
  return osvajanje_soba(p_soba);
end;
$$;

revoke all on function public.osvajanje_izaberi_vojsku(uuid, text), public.osvajanje_postavi_timove(uuid, jsonb) from public, anon;
grant execute on function public.osvajanje_izaberi_vojsku(uuid, text), public.osvajanje_postavi_timove(uuid, jsonb) to authenticated;

-- Dopuna 04.11.2026 (vlasnik): isti tim može da igra ZAJEDNO (jedna boja, jedna vojska, deljene države)
-- ili u SAVEZU (svako svoja boja i vojska, stalni savez). Domaćin bira; podrazumevano zajedno.
alter table public.osvajanje_sobe add column if not exists savez boolean not null default false;

create or replace function public.osvajanje_soba(p_soba uuid)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id', s.id, 'nacin', s.nacin, 'velicina', s.velicina, 'teren', s.teren, 'status', s.status, 'napravljena', s.napravljena,
    'kod', s.kod, 'privatna', s.privatna, 'timovi', s.timovi, 'savez', s.savez,
    'mesta', coalesce((select json_agg(json_build_object('user_id', m.user_id, 'mesto', m.mesto, 'vojska', m.vojska,
                                                         'nadimak', coalesce(p.nickname, p.first_name, 'Igrač'), 'avatar', p.avatar) order by m.mesto)
                       from osvajanje_mesta m left join public_profiles p on p.id = m.user_id where m.soba = s.id), '[]'::json))
  from osvajanje_sobe s
  where s.id = p_soba and exists (select 1 from osvajanje_mesta m where m.soba = s.id and m.user_id = auth.uid());
$$;

create or replace function public.osvajanje_postavi_savez(p_soba uuid, p_savez boolean)
returns json language plpgsql security definer set search_path = public as $$
begin
  update osvajanje_sobe s set savez = p_savez
  where s.id = p_soba and s.status = 'ceka'
    and exists (select 1 from osvajanje_mesta m where m.soba = s.id and m.user_id = auth.uid() and m.mesto = 0);
  return osvajanje_soba(p_soba);
end;
$$;
revoke all on function public.osvajanje_postavi_savez(uuid, boolean) from public, anon;
grant execute on function public.osvajanje_postavi_savez(uuid, boolean) to authenticated;
