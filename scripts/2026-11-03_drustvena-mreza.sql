-- Društvena mreža kviza (03.11.2026), po uzoru na Librum eBook: objave (poziv na duel, poziv u tim,
-- podeljen rezultat, tekst), srca, komentari sa odgovorima i srcima, blokiranje, prijave i privatne poruke.
-- Tabele se ne čitaju direktno (RLS bez politika): sve ide kroz funkcije ispod, koje znaju za blokade.

create table if not exists public.objave (
  id bigint generated always as identity primary key,
  ko uuid not null references auth.users (id) on delete cascade,
  vrsta text not null check (vrsta in ('tekst', 'rezultat', 'poziv_duel', 'poziv_tim')),
  igra text,
  tekst text not null default '' check (char_length(tekst) <= 500),
  poeni int,
  kod_sobe text,
  sakrivena boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists objave_tok on public.objave (id desc) where not sakrivena;
create index if not exists objave_ko on public.objave (ko, id desc);

create table if not exists public.objave_srca (
  objava bigint not null references public.objave (id) on delete cascade,
  ko uuid not null references auth.users (id) on delete cascade,
  primary key (objava, ko)
);

create table if not exists public.komentari (
  id bigint generated always as identity primary key,
  objava bigint not null references public.objave (id) on delete cascade,
  roditelj bigint references public.komentari (id) on delete cascade,
  ko uuid not null references auth.users (id) on delete cascade,
  tekst text not null check (char_length(tekst) between 1 and 500),
  sakriven boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists komentari_objava on public.komentari (objava, id);

create table if not exists public.komentari_srca (
  komentar bigint not null references public.komentari (id) on delete cascade,
  ko uuid not null references auth.users (id) on delete cascade,
  primary key (komentar, ko)
);

create table if not exists public.blokade (
  ko uuid not null references auth.users (id) on delete cascade,
  koga uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (ko, koga)
);
create index if not exists blokade_koga on public.blokade (koga);

create table if not exists public.prijave_sadrzaja (
  id bigint generated always as identity primary key,
  objava bigint references public.objave (id) on delete cascade,
  komentar bigint references public.komentari (id) on delete cascade,
  ko uuid not null references auth.users (id) on delete cascade,
  razlog text not null check (razlog in ('uvreda', 'spam', 'prevara', 'neprikladno', 'drugo')),
  created_at timestamptz not null default now(),
  unique (objava, komentar, ko)
);

create table if not exists public.poruke (
  id bigint generated always as identity primary key,
  od uuid not null references auth.users (id) on delete cascade,
  za uuid not null references auth.users (id) on delete cascade,
  tekst text not null check (char_length(tekst) between 1 and 1000),
  procitano boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists poruke_par on public.poruke (least(od, za), greatest(od, za), id desc);
create index if not exists poruke_za_neprocitano on public.poruke (za) where not procitano;

alter table public.objave enable row level security;
alter table public.objave_srca enable row level security;
alter table public.komentari enable row level security;
alter table public.komentari_srca enable row level security;
alter table public.blokade enable row level security;
alter table public.prijave_sadrzaja enable row level security;
alter table public.poruke enable row level security;

-- Da li su dva igrača blokirana u bilo kom smeru (tada se ne vide nigde).
create or replace function public.blokirani(a uuid, b uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from blokade where (ko = a and koga = b) or (ko = b and koga = a));
$$;

-- Tok objava: „svi” ili „pratim” (ja i oni koje pratim), keyset po id-u (p_pre = poslednji viđeni id).
create or replace function public.tok_objava(p_vrsta text default 'svi', p_pre bigint default null, p_broj int default 20)
returns table (id bigint, ko uuid, nadimak text, avatar text, vrsta text, igra text, tekst text, poeni int, kod_sobe text,
               created_at timestamptz, srca bigint, moje_srce boolean, komentara bigint, moja boolean)
language sql stable security definer set search_path to 'public' as $$
  select o.id, o.ko, coalesce(nullif(p.nickname, ''), nullif(p.first_name, ''), 'Igrač'), p.avatar, o.vrsta, o.igra, o.tekst, o.poeni, o.kod_sobe,
         o.created_at,
         (select count(*) from objave_srca s where s.objava = o.id),
         exists (select 1 from objave_srca s where s.objava = o.id and s.ko = auth.uid()),
         (select count(*) from komentari k where k.objava = o.id and not k.sakriven),
         o.ko = auth.uid()
  from objave o join public_profiles p on p.id = o.ko
  where not o.sakrivena
    and (p_pre is null or o.id < p_pre)
    and (auth.uid() is null or not blokirani(auth.uid(), o.ko))
    and (p_vrsta <> 'pratim' or o.ko = auth.uid() or exists (select 1 from pracenja f where f.ko = auth.uid() and f.koga = o.ko))
  order by o.id desc
  limit least(greatest(p_broj, 1), 50);
$$;

-- Nova objava (tekst, podeljen rezultat, poziv na duel ili u tim). Do 20 objava dnevno.
create or replace function public.nova_objava(p_vrsta text, p_tekst text default '', p_igra text default null, p_poeni int default null, p_kod_sobe text default null)
returns bigint language plpgsql security definer set search_path to 'public' as $$
declare novi bigint;
begin
  if auth.uid() is null then raise exception 'prijava je obavezna'; end if;
  if exists (select 1 from profiles where id = auth.uid() and is_blocked) then raise exception 'nalog je blokiran'; end if;
  if (select count(*) from objave where ko = auth.uid() and created_at > now() - interval '1 day') >= 20 then
    raise exception 'danas si objavio 20 puta, nastavi sutra';
  end if;
  insert into objave (ko, vrsta, igra, tekst, poeni, kod_sobe)
  values (auth.uid(), p_vrsta, p_igra, btrim(coalesce(p_tekst, '')), p_poeni, p_kod_sobe) returning id into novi;
  return novi;
end;
$$;

create or replace function public.obrisi_objavu(p_id bigint)
returns void language sql security definer set search_path to 'public' as $$
  delete from objave where id = p_id and ko = auth.uid();
$$;

create or replace function public.srce_objavi(p_id bigint)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null then raise exception 'prijava je obavezna'; end if;
  if exists (select 1 from objave_srca where objava = p_id and ko = auth.uid()) then
    delete from objave_srca where objava = p_id and ko = auth.uid();
  else
    insert into objave_srca (objava, ko) values (p_id, auth.uid());
  end if;
  return jsonb_build_object('moje_srce', exists (select 1 from objave_srca where objava = p_id and ko = auth.uid()),
                            'srca', (select count(*) from objave_srca where objava = p_id));
end;
$$;

-- Komentari jedne objave, ravno sa roditeljem (aplikacija gradi grane); blokirani i sakriveni se ne vide.
create or replace function public.komentari_objave(p_objava bigint)
returns table (id bigint, roditelj bigint, ko uuid, nadimak text, avatar text, tekst text, created_at timestamptz, srca bigint, moje_srce boolean, moj boolean)
language sql stable security definer set search_path to 'public' as $$
  select k.id, k.roditelj, k.ko, coalesce(nullif(p.nickname, ''), nullif(p.first_name, ''), 'Igrač'), p.avatar, k.tekst, k.created_at,
         (select count(*) from komentari_srca s where s.komentar = k.id),
         exists (select 1 from komentari_srca s where s.komentar = k.id and s.ko = auth.uid()),
         k.ko = auth.uid()
  from komentari k join public_profiles p on p.id = k.ko
  where k.objava = p_objava and not k.sakriven and (auth.uid() is null or not blokirani(auth.uid(), k.ko))
  order by k.id
  limit 500;
$$;

create or replace function public.novi_komentar(p_objava bigint, p_tekst text, p_roditelj bigint default null)
returns bigint language plpgsql security definer set search_path to 'public' as $$
declare novi bigint; autor uuid;
begin
  if auth.uid() is null then raise exception 'prijava je obavezna'; end if;
  select ko into autor from objave where id = p_objava and not sakrivena;
  if autor is null then raise exception 'objava ne postoji'; end if;
  if blokirani(auth.uid(), autor) then raise exception 'ne možeš da komentarišeš ovu objavu'; end if;
  if p_roditelj is not null and not exists (select 1 from komentari where id = p_roditelj and objava = p_objava) then raise exception 'odgovor na nepostojeći komentar'; end if;
  if (select count(*) from komentari where ko = auth.uid() and created_at > now() - interval '1 hour') >= 60 then raise exception 'previše komentara, sačekaj malo'; end if;
  insert into komentari (objava, roditelj, ko, tekst) values (p_objava, p_roditelj, auth.uid(), btrim(p_tekst)) returning id into novi;
  return novi;
end;
$$;

create or replace function public.obrisi_komentar(p_id bigint)
returns void language sql security definer set search_path to 'public' as $$
  delete from komentari where id = p_id and ko = auth.uid();
$$;

create or replace function public.srce_komentaru(p_id bigint)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null then raise exception 'prijava je obavezna'; end if;
  if exists (select 1 from komentari_srca where komentar = p_id and ko = auth.uid()) then
    delete from komentari_srca where komentar = p_id and ko = auth.uid();
  else
    insert into komentari_srca (komentar, ko) values (p_id, auth.uid());
  end if;
  return jsonb_build_object('moje_srce', exists (select 1 from komentari_srca where komentar = p_id and ko = auth.uid()),
                            'srca', (select count(*) from komentari_srca where komentar = p_id));
end;
$$;

-- Blokada: brišu se praćenja u oba smera; posle toga se ne vide ni objave, ni komentari, ni poruke.
create or replace function public.blokiraj(p_id uuid, p_da boolean default true)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null or p_id = auth.uid() then raise exception 'neispravna blokada'; end if;
  if p_da then
    insert into blokade (ko, koga) values (auth.uid(), p_id) on conflict do nothing;
    delete from pracenja where (ko = auth.uid() and koga = p_id) or (ko = p_id and koga = auth.uid());
  else
    delete from blokade where ko = auth.uid() and koga = p_id;
  end if;
end;
$$;

create or replace function public.moje_blokade()
returns table (id uuid, nadimak text, avatar text)
language sql stable security definer set search_path to 'public' as $$
  select p.id, coalesce(nullif(p.nickname, ''), nullif(p.first_name, ''), 'Igrač'), p.avatar
  from blokade b join public_profiles p on p.id = b.koga where b.ko = auth.uid() order by b.created_at desc;
$$;

-- Prijava objave ili komentara; tri prijave različitih igrača sakrivaju sadržaj do pregleda urednika.
create or replace function public.prijavi_sadrzaj(p_objava bigint, p_komentar bigint, p_razlog text)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null then raise exception 'prijava je obavezna'; end if;
  insert into prijave_sadrzaja (objava, komentar, ko, razlog) values (p_objava, p_komentar, auth.uid(), p_razlog) on conflict do nothing;
  if p_komentar is not null and (select count(*) from prijave_sadrzaja where komentar = p_komentar) >= 3 then
    update komentari set sakriven = true where id = p_komentar;
  elsif p_komentar is null and (select count(*) from prijave_sadrzaja where objava = p_objava and komentar is null) >= 3 then
    update objave set sakrivena = true where id = p_objava;
  end if;
end;
$$;

-- Razgovori: poslednja poruka sa svakim sagovornikom i broj nepročitanih.
create or replace function public.moji_razgovori()
returns table (sa uuid, nadimak text, avatar text, poslednja text, kad timestamptz, moja boolean, neprocitanih bigint)
language sql stable security definer set search_path to 'public' as $$
  with zadnje as (
    select distinct on (case when od = auth.uid() then za else od end)
           case when od = auth.uid() then za else od end as sa, tekst, created_at, od = auth.uid() as moja
    from poruke where od = auth.uid() or za = auth.uid()
    order by case when od = auth.uid() then za else od end, id desc
  )
  select z.sa, coalesce(nullif(p.nickname, ''), nullif(p.first_name, ''), 'Igrač'), p.avatar, z.tekst, z.created_at, z.moja,
         (select count(*) from poruke x where x.od = z.sa and x.za = auth.uid() and not x.procitano)
  from zadnje z join public_profiles p on p.id = z.sa
  where not blokirani(auth.uid(), z.sa)
  order by z.created_at desc;
$$;

-- Poruke sa jednim igračem (poslednjih 200); pročitane se označavaju.
create or replace function public.poruke_sa(p_sa uuid)
returns table (id bigint, moja boolean, tekst text, created_at timestamptz)
language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null then raise exception 'prijava je obavezna'; end if;
  update poruke set procitano = true where od = p_sa and za = auth.uid() and not procitano;
  return query
    select x.id, x.od = auth.uid(), x.tekst, x.created_at from (
      select * from poruke where (od = auth.uid() and za = p_sa) or (od = p_sa and za = auth.uid()) order by id desc limit 200
    ) x order by x.id;
end;
$$;

create or replace function public.posalji_poruku(p_za uuid, p_tekst text)
returns bigint language plpgsql security definer set search_path to 'public' as $$
declare novi bigint;
begin
  if auth.uid() is null or p_za = auth.uid() then raise exception 'neispravna poruka'; end if;
  if blokirani(auth.uid(), p_za) then raise exception 'ne možeš da pišeš ovom igraču'; end if;
  if (select count(*) from poruke where od = auth.uid() and created_at > now() - interval '1 hour') >= 120 then raise exception 'previše poruka, sačekaj malo'; end if;
  insert into poruke (od, za, tekst) values (auth.uid(), p_za, btrim(p_tekst)) returning id into novi;
  return novi;
end;
$$;

-- Ko šta igra: poslednje partije igrača koje pratim (ili svih), za vrh kartice Igrači.
create or replace function public.ko_sta_igra(p_broj int default 20)
returns table (ko uuid, nadimak text, avatar text, igra text, poeni int, kad timestamptz)
language sql stable security definer set search_path to 'public' as $$
  select r.user_id, coalesce(nullif(p.nickname, ''), nullif(p.first_name, ''), 'Igrač'), p.avatar, r.igra, r.poeni, r.created_at
  from rezultati_igara r join public_profiles p on p.id = r.user_id
  where r.created_at > now() - interval '7 days'
    and (auth.uid() is null or not blokirani(auth.uid(), r.user_id))
  order by (exists (select 1 from pracenja f where f.ko = auth.uid() and f.koga = r.user_id)) desc, r.created_at desc
  limit least(greatest(p_broj, 1), 50);
$$;

revoke all on function public.blokirani(uuid, uuid) from public, anon, authenticated;
grant execute on function public.tok_objava(text, bigint, int), public.komentari_objave(bigint), public.ko_sta_igra(int) to anon, authenticated;
revoke all on function public.nova_objava(text, text, text, int, text), public.obrisi_objavu(bigint), public.srce_objavi(bigint),
  public.novi_komentar(bigint, text, bigint), public.obrisi_komentar(bigint), public.srce_komentaru(bigint), public.blokiraj(uuid, boolean),
  public.moje_blokade(), public.prijavi_sadrzaj(bigint, bigint, text), public.moji_razgovori(), public.poruke_sa(uuid), public.posalji_poruku(uuid, text)
  from public, anon;
grant execute on function public.nova_objava(text, text, text, int, text), public.obrisi_objavu(bigint), public.srce_objavi(bigint),
  public.novi_komentar(bigint, text, bigint), public.obrisi_komentar(bigint), public.srce_komentaru(bigint), public.blokiraj(uuid, boolean),
  public.moje_blokade(), public.prijavi_sadrzaj(bigint, bigint, text), public.moji_razgovori(), public.poruke_sa(uuid), public.posalji_poruku(uuid, text)
  to authenticated;
