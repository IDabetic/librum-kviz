-- Osvajanje sveta: sobe za igru više igrača (02.11.2026).
-- Server deli igrače u sobe iste vrste: ko traži „svako za sebe, 6 igrača” ulazi u prvu
-- nepopunjenu takvu sobu, a kad je puna, sledeći otvaraju novu. Sto igrača = više soba istovremeno.
-- Upis ide samo kroz funkcije ispod (security definer); tabele se direktno samo čitaju.

create table if not exists public.osvajanje_sobe (
  id uuid primary key default gen_random_uuid(),
  nacin text not null check (nacin in ('jedanNaJedan', 'timovi', 'svakoZaSebe')),
  velicina int not null check (velicina between 2 and 12),
  -- null = ceo svet, inače id kontinenta (sam, jam, evr, afr, azi, oke)
  teren text check (teren in ('sam', 'jam', 'evr', 'afr', 'azi', 'oke')),
  status text not null default 'ceka' check (status in ('ceka', 'pocela')),
  napravljena timestamptz not null default now(),
  pocela timestamptz
);

create table if not exists public.osvajanje_mesta (
  soba uuid not null references public.osvajanje_sobe (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  mesto int not null,
  usao timestamptz not null default now(),
  primary key (soba, user_id),
  unique (soba, mesto)
);

-- Traženje slobodne sobe filtrira po statusu i vrsti, najstarija prva.
create index if not exists osvajanje_sobe_slobodne on public.osvajanje_sobe (nacin, velicina, teren, napravljena) where status = 'ceka';
create index if not exists osvajanje_mesta_korisnik on public.osvajanje_mesta (user_id);

alter table public.osvajanje_sobe enable row level security;
alter table public.osvajanje_mesta enable row level security;

-- Sobe korisnika; security definer da politika nad osvajanje_mesta ne poziva samu sebe (rekurzija RLS).
create or replace function public.osvajanje_moje_sobe()
returns setof uuid language sql stable security definer set search_path = public as $$
  select soba from osvajanje_mesta where user_id = auth.uid();
$$;

drop policy if exists "clan vidi svoju sobu" on public.osvajanje_sobe;
create policy "clan vidi svoju sobu" on public.osvajanje_sobe for select to authenticated
  using (id in (select public.osvajanje_moje_sobe()));

drop policy if exists "clan vidi saigrace" on public.osvajanje_mesta;
create policy "clan vidi saigrace" on public.osvajanje_mesta for select to authenticated
  using (soba in (select public.osvajanje_moje_sobe()));

-- Stanje sobe za člana: status, veličina i ko je za stolom (nadimak i avatar iz javnog profila).
create or replace function public.osvajanje_soba(p_soba uuid)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id', s.id, 'nacin', s.nacin, 'velicina', s.velicina, 'teren', s.teren, 'status', s.status, 'napravljena', s.napravljena,
    'mesta', coalesce((select json_agg(json_build_object('user_id', m.user_id, 'mesto', m.mesto,
                                                         'nadimak', coalesce(p.nickname, p.first_name, 'Igrač'), 'avatar', p.avatar) order by m.mesto)
                       from osvajanje_mesta m left join public_profiles p on p.id = m.user_id where m.soba = s.id), '[]'::json))
  from osvajanje_sobe s
  where s.id = p_soba and exists (select 1 from osvajanje_mesta m where m.soba = s.id and m.user_id = auth.uid());
$$;

-- Ulazak u prvu slobodnu sobu iste vrste ili nova soba. Skip locked: dva igrača u istom trenutku
-- ne zauzimaju isto mesto, a puna soba odmah počinje.
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
  -- Igrač čeka samo u jednoj sobi.
  delete from osvajanje_mesta m using osvajanje_sobe s where m.soba = s.id and s.status = 'ceka' and m.user_id = ja;
  delete from osvajanje_sobe s where s.status = 'ceka' and not exists (select 1 from osvajanje_mesta m where m.soba = s.id);

  select s.id into v_soba from osvajanje_sobe s
  where s.status = 'ceka' and s.nacin = p_nacin and s.velicina = p_velicina and s.teren is not distinct from p_teren
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

-- Posle kratkog čekanja (10 s) član pokreće sobu, a prazna mesta popunjavaju botovi.
create or replace function public.osvajanje_pokreni(p_soba uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  update osvajanje_sobe s set status = 'pocela', pocela = now()
  where s.id = p_soba and s.status = 'ceka' and s.napravljena < now() - interval '10 seconds'
    and exists (select 1 from osvajanje_mesta m where m.soba = s.id and m.user_id = auth.uid());
  return osvajanje_soba(p_soba);
end;
$$;

-- Izlazak iz sobe koja još čeka; prazna soba se briše.
create or replace function public.osvajanje_napusti(p_soba uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from osvajanje_mesta m using osvajanje_sobe s
  where m.soba = s.id and s.id = p_soba and s.status = 'ceka' and m.user_id = auth.uid();
  delete from osvajanje_sobe s where s.id = p_soba and s.status = 'ceka' and not exists (select 1 from osvajanje_mesta m where m.soba = s.id);
end;
$$;

revoke all on function public.osvajanje_moje_sobe(), public.osvajanje_soba(uuid), public.osvajanje_trazi_sobu(text, int, text),
  public.osvajanje_pokreni(uuid), public.osvajanje_napusti(uuid) from public, anon;
grant execute on function public.osvajanje_moje_sobe(), public.osvajanje_soba(uuid), public.osvajanje_trazi_sobu(text, int, text),
  public.osvajanje_pokreni(uuid), public.osvajanje_napusti(uuid) to authenticated;
