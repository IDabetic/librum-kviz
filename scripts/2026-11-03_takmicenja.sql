-- Takmičenja (vlasnik 03.11.2026): PRO, Book, Slikari, Brzi kviz i Vešanje za 2–8 igrača, svako za sebe ili timovi po dvoje,
-- protiv računara, pravih igrača ili mešano. Svi igraju ISTI sadržaj (iste ID-jeve pitanja/reči/dela) svako na svom telefonu,
-- a rezultati se upisuju posle svakog odgovora, pa svi vide tabelu uživo. Botovi se računaju na telefonu iz semena (isto svima).
-- Poziv igraču = red u `izazovi` (igra 'soba:<igra>', kod_sobe = kod), pa ga vidi u sandučetu i dobija push (funkcija obavesti).

-- Poziv u sobu ide kroz postojeće sanduče izazova.
alter table public.izazovi drop constraint if exists izazovi_igra_check;
alter table public.izazovi add constraint izazovi_igra_check check (igra in ('duel', 'osvajanje') or igra like 'soba:%');
alter table public.izazovi drop constraint if exists izazovi_status_check;
alter table public.izazovi add constraint izazovi_status_check check (status in ('ceka', 'prihvacen', 'odbijen', 'istekao', 'otkazan'));

create table if not exists public.takmicenja (
  id uuid primary key default gen_random_uuid(),
  kod text unique not null,
  igra text not null check (igra in ('pro', 'book', 'slikari', 'brzi', 'vesanje')),
  domacin uuid not null references auth.users(id) on delete cascade,
  velicina int not null check (velicina between 2 and 8),
  nacin text not null check (nacin in ('svako', 'timovi')),
  protivnici text not null check (protivnici in ('racunar', 'pravi', 'mesano')),
  tezina text not null default 'normalno' check (tezina in ('lako', 'normalno', 'tesko')),
  seme bigint not null,
  sadrzaj jsonb not null default '[]',
  status text not null default 'ceka' check (status in ('ceka', 'igra', 'kraj', 'otkazano')),
  napravljeno timestamptz not null default now(),
  pocelo timestamptz
);
create index if not exists takmicenja_status_idx on public.takmicenja (status, napravljeno);
create index if not exists takmicenja_domacin_idx on public.takmicenja (domacin, status);

create table if not exists public.takmicenje_mesta (
  takmicenje uuid not null references public.takmicenja(id) on delete cascade,
  mesto int not null,
  user_id uuid references auth.users(id) on delete set null,
  bot text,
  pozvan boolean not null default false,
  tim int not null default 0,
  poeni int not null default 0,
  tacnih int not null default 0,
  odigrano int not null default 0,
  ms int not null default 0,
  gotov boolean not null default false,
  primary key (takmicenje, mesto)
);
create index if not exists takmicenje_mesta_user_idx on public.takmicenje_mesta (user_id);

alter table public.takmicenja enable row level security;
alter table public.takmicenje_mesta enable row level security;
-- Bez direktnog pristupa: sve ide kroz funkcije ispod (security definer).

create or replace function public.takmicenje_stanje(p_id uuid)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id', t.id, 'kod', t.kod, 'igra', t.igra, 'domacin', t.domacin, 'velicina', t.velicina, 'nacin', t.nacin,
    'protivnici', t.protivnici, 'tezina', t.tezina, 'seme', t.seme, 'broj', jsonb_array_length(t.sadrzaj), 'status', t.status,
    'pocelo', t.pocelo,
    'mesta', coalesce((select json_agg(json_build_object(
        'mesto', m.mesto, 'user_id', m.user_id, 'bot', m.bot, 'pozvan', m.pozvan, 'tim', m.tim,
        'nadimak', coalesce(m.bot, nullif(p.nickname, ''), nullif(p.first_name, ''), case when m.user_id is null then null else 'Igrač' end),
        'avatar', p.avatar, 'poeni', m.poeni, 'tacnih', m.tacnih, 'odigrano', m.odigrano, 'ms', m.ms, 'gotov', m.gotov) order by m.mesto)
      from takmicenje_mesta m left join public_profiles p on p.id = m.user_id where m.takmicenje = t.id), '[]'::json))
  from takmicenja t
  where t.id = p_id and exists (select 1 from takmicenje_mesta m where m.takmicenje = t.id and m.user_id = auth.uid());
$$;

-- Domaćin pravi sobu: mesto 0 je on, pozvani dobijaju mesta (pozvan = true) i izazov u sandučetu.
-- Timovi: mesto i ide u tim (i % (velicina / 2)), pa 2v2 = 2 tima, 8 igrača = 4 tima po dvoje.
create or replace function public.takmicenje_napravi(p_igra text, p_velicina int, p_nacin text, p_protivnici text, p_tezina text,
                                                     p_sadrzaj jsonb, p_pozovi uuid[] default '{}')
returns json language plpgsql security definer set search_path = public as $$
declare
  ja uuid := auth.uid();
  v_id uuid;
  v_kod text;
  v_timova int;
  v_pozvani uuid[];
  znaci constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if ja is null then raise exception 'prijava je obavezna'; end if;
  if p_nacin = 'timovi' and (p_velicina % 2 <> 0 or p_velicina < 4) then raise exception 'timovi traže 4, 6 ili 8 igrača'; end if;
  v_pozvani := (select coalesce(array_agg(distinct x), '{}') from unnest(p_pozovi) x where x <> ja and not blokirani(ja, x));
  if cardinality(v_pozvani) > p_velicina - 1 then raise exception 'previše pozvanih za ovu sobu'; end if;
  -- Moje stare sobe koje još čekaju se otkazuju (jedna soba u isto vreme).
  update takmicenja set status = 'otkazano' where domacin = ja and status = 'ceka';
  loop
    v_kod := (select string_agg(substr(znaci, 1 + floor(random() * length(znaci))::int, 1), '') from generate_series(1, 6));
    exit when not exists (select 1 from takmicenja where kod = v_kod);
  end loop;
  v_timova := case when p_nacin = 'timovi' then p_velicina / 2 else p_velicina end;
  insert into takmicenja (kod, igra, domacin, velicina, nacin, protivnici, tezina, seme, sadrzaj)
  values (v_kod, p_igra, ja, p_velicina, p_nacin, p_protivnici, p_tezina, floor(random() * 2147483647)::bigint, coalesce(p_sadrzaj, '[]'))
  returning id into v_id;
  insert into takmicenje_mesta (takmicenje, mesto, user_id, pozvan, tim)
  select v_id, g, case when g = 0 then ja when g <= cardinality(v_pozvani) then v_pozvani[g] end, g between 1 and cardinality(v_pozvani), g % v_timova
  from generate_series(0, p_velicina - 1) g;
  insert into izazovi (od, za, igra, kod_sobe, status)
  select ja, x, 'soba:' || p_igra, v_kod, 'ceka' from unnest(v_pozvani) x;
  return takmicenje_stanje(v_id);
end;
$$;

-- Ulazak kodom ili prihvatanje poziva: pozvani zauzima svoje mesto, ostali prvo slobodno.
create or replace function public.takmicenje_udji(p_kod text)
returns json language plpgsql security definer set search_path = public as $$
declare
  ja uuid := auth.uid();
  v_id uuid;
  v_mesto int;
begin
  if ja is null then raise exception 'prijava je obavezna'; end if;
  select id into v_id from takmicenja where kod = upper(trim(p_kod)) and status in ('ceka', 'igra');
  if v_id is null then raise exception 'soba ne postoji ili je završena'; end if;
  if exists (select 1 from takmicenje_mesta where takmicenje = v_id and user_id = ja) then
    update takmicenje_mesta set pozvan = false where takmicenje = v_id and user_id = ja;
  else
    if (select status from takmicenja where id = v_id) <> 'ceka' then raise exception 'igra je već počela'; end if;
    select mesto into v_mesto from takmicenje_mesta where takmicenje = v_id and user_id is null and bot is null and not pozvan
      order by mesto limit 1 for update skip locked;
    if v_mesto is null then raise exception 'soba je puna'; end if;
    update takmicenje_mesta set user_id = ja where takmicenje = v_id and mesto = v_mesto;
  end if;
  update izazovi set status = 'prihvacen' where za = ja and kod_sobe = upper(trim(p_kod)) and status = 'ceka';
  return takmicenje_stanje(v_id);
end;
$$;

-- Odbijen poziv: mesto se oslobađa, domaćin to vidi u lobiju.
create or replace function public.takmicenje_odbij(p_kod text)
returns void language sql security definer set search_path = public as $$
  update takmicenje_mesta m set user_id = null, pozvan = false
  from takmicenja t where t.id = m.takmicenje and t.kod = upper(trim(p_kod)) and t.status = 'ceka' and m.user_id = auth.uid() and m.pozvan;
  update izazovi set status = 'odbijen' where za = auth.uid() and kod_sobe = upper(trim(p_kod)) and status = 'ceka';
$$;

-- Izlazak: u čekanju oslobađa mesto (domaćin otkazuje sobu), u igri je predaja (gotov sa trenutnim rezultatom).
create or replace function public.takmicenje_izadji(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare ja uuid := auth.uid(); v_status text; v_domacin uuid;
begin
  select status, domacin into v_status, v_domacin from takmicenja where id = p_id;
  if v_status = 'ceka' then
    if v_domacin = ja then
      update takmicenja set status = 'otkazano' where id = p_id;
      update izazovi set status = 'otkazan' where kod_sobe = (select kod from takmicenja where id = p_id) and status = 'ceka';
    else
      update takmicenje_mesta set user_id = null, pozvan = false where takmicenje = p_id and user_id = ja;
    end if;
  elsif v_status = 'igra' then
    update takmicenje_mesta set gotov = true where takmicenje = p_id and user_id = ja;
    perform takmicenje_proveri_kraj(p_id);
  end if;
end;
$$;

-- Domaćin pokreće: poziv bez odgovora se gasi; prazna mesta preuzimaju botovi (svaki drugo ime), osim kad je soba
-- „samo pravi igrači” bez timova, tada se prazna mesta brišu (bar dvoje pravih).
create or replace function public.takmicenje_pokreni(p_id uuid, p_sadrzaj jsonb default null)
returns json language plpgsql security definer set search_path = public as $$
declare
  t takmicenja;
  imena text[] := (select array_agg(x order by random()) from unnest(array['Mimi', 'Zig', 'Bloop', 'Lumi', 'Luna', 'Max', 'Sara', 'Đole', 'Ana', 'Pera', 'Mila']) x);
begin
  select * into t from takmicenja where id = p_id for update;
  if t.domacin is distinct from auth.uid() then raise exception 'samo domaćin pokreće'; end if;
  if t.status <> 'ceka' then return takmicenje_stanje(p_id); end if;
  update izazovi set status = 'istekao' where kod_sobe = t.kod and status = 'ceka';
  update takmicenje_mesta set user_id = null, pozvan = false where takmicenje = p_id and pozvan;
  if t.protivnici = 'pravi' and t.nacin = 'svako' then
    if (select count(*) from takmicenje_mesta where takmicenje = p_id and user_id is not null) < 2 then
      raise exception 'još niko nije ušao u sobu';
    end if;
    delete from takmicenje_mesta where takmicenje = p_id and user_id is null;
  else
    update takmicenje_mesta m set bot = imena[x.r]
    from (select mesto, row_number() over (order by mesto) r from takmicenje_mesta where takmicenje = p_id and user_id is null) x
    where m.takmicenje = p_id and m.mesto = x.mesto;
  end if;
  update takmicenja set status = 'igra', pocelo = now(), sadrzaj = coalesce(p_sadrzaj, sadrzaj) where id = p_id;
  return takmicenje_stanje(p_id);
end;
$$;

-- Kraj kad su svi pravi igrači gotovi, ili posle 30 minuta (neko je zatvorio aplikaciju usred igre).
create or replace function public.takmicenje_proveri_kraj(p_id uuid)
returns void language sql security definer set search_path = public as $$
  update takmicenja set status = 'kraj'
  where id = p_id and status = 'igra'
    and (pocelo < now() - interval '30 minutes'
         or not exists (select 1 from takmicenje_mesta where takmicenje = p_id and user_id is not null and not gotov));
$$;

-- Rezultat posle svakog odgovora (zbirno), i „gotov” kad igrač završi.
create or replace function public.takmicenje_rezultat(p_id uuid, p_poeni int, p_tacnih int, p_odigrano int, p_ms int, p_gotov boolean)
returns json language plpgsql security definer set search_path = public as $$
begin
  update takmicenje_mesta set poeni = p_poeni, tacnih = p_tacnih, odigrano = p_odigrano, ms = p_ms, gotov = gotov or p_gotov
  where takmicenje = p_id and user_id = auth.uid()
    and (select status from takmicenja where id = p_id) = 'igra';
  perform takmicenje_proveri_kraj(p_id);
  return takmicenje_stanje(p_id);
end;
$$;

-- Isti sadržaj za sve: domaćin šalje cela pitanja/reči/dela (javni sadržaj koji aplikacija i inače dobija), ostali ih čitaju
-- jednom na početku; stanje ga ne nosi, jer se osvežava svake sekunde.
create or replace function public.takmicenje_sadrzaj(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select t.sadrzaj from takmicenja t
  where t.id = p_id and exists (select 1 from takmicenje_mesta m where m.takmicenje = t.id and m.user_id = auth.uid());
$$;

-- Ko me je pozvao: soba, igra i domaćin, za sanduče i ekran „Prihvatam / Odbijam”.
create or replace function public.takmicenje_pozivi()
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object('kod', t.kod, 'igra', t.igra, 'velicina', t.velicina, 'nacin', t.nacin,
           'od', coalesce(nullif(p.nickname, ''), nullif(p.first_name, ''), 'Igrač'), 'avatar', p.avatar, 'napravljeno', t.napravljeno)
           order by t.napravljeno desc), '[]'::json)
  from takmicenje_mesta m join takmicenja t on t.id = m.takmicenje left join public_profiles p on p.id = t.domacin
  where m.user_id = auth.uid() and m.pozvan and t.status = 'ceka' and t.napravljeno > now() - interval '30 minutes';
$$;

revoke all on function public.takmicenje_stanje(uuid), public.takmicenje_napravi(text, int, text, text, text, jsonb, uuid[]),
  public.takmicenje_udji(text), public.takmicenje_odbij(text), public.takmicenje_izadji(uuid), public.takmicenje_pokreni(uuid, jsonb),
  public.takmicenje_proveri_kraj(uuid), public.takmicenje_rezultat(uuid, int, int, int, int, boolean), public.takmicenje_sadrzaj(uuid),
  public.takmicenje_pozivi() from public, anon;
grant execute on function public.takmicenje_stanje(uuid), public.takmicenje_napravi(text, int, text, text, text, jsonb, uuid[]),
  public.takmicenje_udji(text), public.takmicenje_odbij(text), public.takmicenje_izadji(uuid), public.takmicenje_pokreni(uuid, jsonb),
  public.takmicenje_rezultat(uuid, int, int, int, int, boolean), public.takmicenje_sadrzaj(uuid), public.takmicenje_pozivi() to authenticated;
notify pgrst, 'reload schema';

-- Sanduče (moja_obavestenja): poziv u sobu je vrsta 'soba' sa igrom u tekstu (primenjeno kao migracija obavestenja_poziv_u_sobu;
-- cela funkcija je ista kao ranije, menja se samo prvi deo unije):
--   select case when i.igra like 'soba:%' then 'soba' else 'izazov' end::text v, i.od k,
--          case when i.igra like 'soba:%' then substr(i.igra, 6) end::text t, null::bigint o, i.kod_sobe ks, i.created_at c from izazovi i
