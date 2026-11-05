-- Osvajanje sveta: partija na poziv (vlasnik 03.11.2026). Domaćin pravi privatnu sobu sa kodom (4–6 prijatelja,
-- timovi po dvoje ili svako za sebe), prijatelji ulaze kodom ili linkom librumkviz://osvajanje/KOD, a partija kreće
-- kad domaćin pritisne „Počni” (prazna mesta preuzimaju botovi). Javno traženje (osvajanje_trazi_sobu) ne ulazi u privatne sobe.

alter table public.osvajanje_sobe add column if not exists kod text unique;
alter table public.osvajanje_sobe add column if not exists privatna boolean not null default false;

create or replace function public.osvajanje_soba(p_soba uuid)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id', s.id, 'nacin', s.nacin, 'velicina', s.velicina, 'teren', s.teren, 'status', s.status, 'napravljena', s.napravljena,
    'kod', s.kod, 'privatna', s.privatna,
    'mesta', coalesce((select json_agg(json_build_object('user_id', m.user_id, 'mesto', m.mesto,
                                                         'nadimak', coalesce(p.nickname, p.first_name, 'Igrač'), 'avatar', p.avatar) order by m.mesto)
                       from osvajanje_mesta m left join public_profiles p on p.id = m.user_id where m.soba = s.id), '[]'::json))
  from osvajanje_sobe s
  where s.id = p_soba and exists (select 1 from osvajanje_mesta m where m.soba = s.id and m.user_id = auth.uid());
$$;

-- Javno traženje preskače privatne sobe (ostalo isto kao 2026-11-02_osvajanje-sobe.sql).
create or replace function public.osvajanje_trazi_sobu(p_nacin text, p_velicina int, p_teren text default null)
returns json language plpgsql security definer set search_path = public as $$
declare
  ja uuid := auth.uid();
  v_soba uuid;
  v_broj int;
begin
  if ja is null then raise exception 'prijava je obavezna'; end if;
  if p_nacin = 'jedanNaJedan' and p_velicina <> 2 then raise exception 'jedan na jedan je za dva igrača'; end if;
  if p_nacin = 'timovi' and p_velicina % 2 <> 0 then raise exception 'timovi traže paran broj igrača'; end if;
  delete from osvajanje_mesta m using osvajanje_sobe s where m.soba = s.id and s.status = 'ceka' and m.user_id = ja;
  delete from osvajanje_sobe s where s.status = 'ceka' and not exists (select 1 from osvajanje_mesta m where m.soba = s.id);

  select s.id into v_soba from osvajanje_sobe s
  where s.status = 'ceka' and not s.privatna and s.nacin = p_nacin and s.velicina = p_velicina and s.teren is not distinct from p_teren
    and (select count(*) from osvajanje_mesta m where m.soba = s.id) < s.velicina
  order by s.napravljena
  limit 1
  for update skip locked;

  if v_soba is null then
    insert into osvajanje_sobe (nacin, velicina, teren) values (p_nacin, p_velicina, p_teren) returning id into v_soba;
  end if;

  select count(*) into v_broj from osvajanje_mesta where soba = v_soba;
  insert into osvajanje_mesta (soba, user_id, mesto) values (v_soba, ja, v_broj);
  if v_broj + 1 >= p_velicina then
    update osvajanje_sobe set status = 'pocela', pocela = now() where id = v_soba;
  end if;
  return osvajanje_soba(v_soba);
end;
$$;

-- Privatna soba: domaćin je mesto 0; kod od 6 znakova bez slova koja se mešaju (0/O, 1/I).
create or replace function public.osvajanje_napravi_sobu(p_nacin text, p_velicina int, p_teren text default null)
returns json language plpgsql security definer set search_path = public as $$
declare
  ja uuid := auth.uid();
  v_soba uuid;
  v_kod text;
  znaci constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if ja is null then raise exception 'prijava je obavezna'; end if;
  if p_velicina not between 2 and 12 then raise exception 'od 2 do 12 igrača'; end if;
  if p_nacin = 'timovi' and p_velicina % 2 <> 0 then raise exception 'timovi traže paran broj igrača'; end if;
  delete from osvajanje_mesta m using osvajanje_sobe s where m.soba = s.id and s.status = 'ceka' and m.user_id = ja;
  delete from osvajanje_sobe s where s.status = 'ceka' and not exists (select 1 from osvajanje_mesta m where m.soba = s.id);
  loop
    v_kod := (select string_agg(substr(znaci, 1 + floor(random() * length(znaci))::int, 1), '') from generate_series(1, 6));
    exit when not exists (select 1 from osvajanje_sobe where kod = v_kod);
  end loop;
  insert into osvajanje_sobe (nacin, velicina, teren, kod, privatna) values (p_nacin, p_velicina, p_teren, v_kod, true) returning id into v_soba;
  insert into osvajanje_mesta (soba, user_id, mesto) values (v_soba, ja, 0);
  return osvajanje_soba(v_soba);
end;
$$;

-- Ulazak kodom: prvo slobodno mesto; ko je već u sobi samo dobija njeno stanje.
create or replace function public.osvajanje_udji_kodom(p_kod text)
returns json language plpgsql security definer set search_path = public as $$
declare
  ja uuid := auth.uid();
  v_soba uuid;
  v_velicina int;
  v_mesto int;
begin
  if ja is null then raise exception 'prijava je obavezna'; end if;
  select id, velicina into v_soba, v_velicina from osvajanje_sobe
  where kod = upper(trim(p_kod)) and privatna and status = 'ceka' for update;
  if v_soba is null then raise exception 'soba ne postoji ili je partija već počela'; end if;
  if exists (select 1 from osvajanje_mesta where soba = v_soba and user_id = ja) then return osvajanje_soba(v_soba); end if;
  select min(g) into v_mesto from generate_series(0, v_velicina - 1) g
  where not exists (select 1 from osvajanje_mesta m where m.soba = v_soba and m.mesto = g);
  if v_mesto is null then raise exception 'soba je puna'; end if;
  delete from osvajanje_mesta m using osvajanje_sobe s where m.soba = s.id and s.status = 'ceka' and m.user_id = ja and s.id <> v_soba;
  insert into osvajanje_mesta (soba, user_id, mesto) values (v_soba, ja, v_mesto);
  return osvajanje_soba(v_soba);
end;
$$;

-- Start privatne sobe: samo domaćin (mesto 0), u bilo kom trenutku; prazna mesta su botovi.
create or replace function public.osvajanje_pokreni_privatnu(p_soba uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  update osvajanje_sobe s set status = 'pocela', pocela = now()
  where s.id = p_soba and s.privatna and s.status = 'ceka'
    and exists (select 1 from osvajanje_mesta m where m.soba = s.id and m.user_id = auth.uid() and m.mesto = 0);
  return osvajanje_soba(p_soba);
end;
$$;

-- Koga mogu da pozovem: koje pratim i sa kim sam se dopisivao (najviše 50, najskoriji prvi).
create or replace function public.osvajanje_za_poziv()
returns json language sql stable security definer set search_path = public as $$
  with ljudi as (
    select koga as id, created_at as kad from pracenja where ko = auth.uid()
    union all
    select case when od = auth.uid() then za else od end, created_at from poruke where od = auth.uid() or za = auth.uid()
  ),
  jedinstveni as (select id, max(kad) as kad from ljudi where id <> auth.uid() group by id order by 2 desc limit 50)
  select coalesce(json_agg(json_build_object('id', j.id, 'nadimak', coalesce(nullif(p.nickname, ''), nullif(p.first_name, ''), 'Igrač'),
                                             'avatar', p.avatar) order by j.kad desc), '[]'::json)
  from jedinstveni j join public_profiles p on p.id = j.id;
$$;

revoke all on function public.osvajanje_napravi_sobu(text, int, text), public.osvajanje_udji_kodom(text),
  public.osvajanje_pokreni_privatnu(uuid), public.osvajanje_za_poziv() from public, anon;
grant execute on function public.osvajanje_napravi_sobu(text, int, text), public.osvajanje_udji_kodom(text),
  public.osvajanje_pokreni_privatnu(uuid), public.osvajanje_za_poziv() to authenticated;
