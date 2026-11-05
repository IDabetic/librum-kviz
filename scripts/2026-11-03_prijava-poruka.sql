-- Prijava privatne poruke (Apple 1.2 / Google UGC: svaki sadržaj korisnika mora moći da se prijavi).
-- Prijavljuje samo primalac; urednik je vidi u /majmun/zajednica i može da je obriše ili vrati.
-- Ažurirano: 3. novembar 2026. · v1

create table if not exists prijave_poruka (
  id bigint generated always as identity primary key,
  poruka bigint not null references poruke(id) on delete cascade,
  ko uuid not null references auth.users(id) on delete cascade,
  razlog text not null default 'uvreda' check (char_length(razlog) <= 40),
  created_at timestamptz not null default now(),
  unique (poruka, ko)
);
create index if not exists prijave_poruka_poruka_idx on prijave_poruka (poruka);
create index if not exists prijave_poruka_ko_idx on prijave_poruka (ko);
-- Samo kroz RPC (security definer); direktan pristup nikome.
alter table prijave_poruka enable row level security;

create or replace function prijavi_poruku(p_poruka bigint, p_razlog text default 'uvreda')
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null then raise exception 'prijava je obavezna'; end if;
  if not exists (select 1 from poruke where id = p_poruka and za = auth.uid()) then
    raise exception 'poruku može da prijavi samo primalac';
  end if;
  insert into prijave_poruka (poruka, ko, razlog) values (p_poruka, auth.uid(), left(coalesce(p_razlog, 'uvreda'), 40))
  on conflict do nothing;
end;
$$;
revoke all on function prijavi_poruku(bigint, text) from public, anon;
grant execute on function prijavi_poruku(bigint, text) to authenticated;

-- Urednički spisak: objave, komentari i prijavljene poruke (poruka nema „sakriveno”; objava = null).
drop function if exists admin_prijave_sadrzaja();
create function admin_prijave_sadrzaja()
returns table(vrsta text, id bigint, objava bigint, tekst text, autor uuid, nadimak text, prijava bigint, razlozi text, sakriveno boolean, poslednja timestamptz)
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not is_admin_user() then raise exception 'samo urednik'; end if;
  return query
  select 'objava'::text, o.id, o.id, o.tekst, o.ko, coalesce(p.nickname, p.first_name, 'Igrač'),
         count(ps.id), string_agg(distinct ps.razlog, ', '), o.sakrivena, max(ps.created_at)
  from objave o
  left join prijave_sadrzaja ps on ps.objava = o.id and ps.komentar is null
  left join profiles p on p.id = o.ko
  group by o.id, p.nickname, p.first_name
  having count(ps.id) > 0 or o.sakrivena
  union all
  select 'komentar'::text, k.id, k.objava, k.tekst, k.ko, coalesce(p.nickname, p.first_name, 'Igrač'),
         count(ps.id), string_agg(distinct ps.razlog, ', '), k.sakriven, max(ps.created_at)
  from komentari k
  left join prijave_sadrzaja ps on ps.komentar = k.id
  left join profiles p on p.id = k.ko
  group by k.id, p.nickname, p.first_name
  having count(ps.id) > 0 or k.sakriven
  union all
  select 'poruka'::text, m.id, null::bigint, m.tekst, m.od, coalesce(p.nickname, p.first_name, 'Igrač'),
         count(pp.id), string_agg(distinct pp.razlog, ', '), false, max(pp.created_at)
  from prijave_poruka pp
  join poruke m on m.id = pp.poruka
  left join profiles p on p.id = m.od
  group by m.id, p.nickname, p.first_name
  order by 10 desc nulls last
  limit 300;
end;
$$;
revoke all on function admin_prijave_sadrzaja() from public, anon;
grant execute on function admin_prijave_sadrzaja() to authenticated;

create or replace function admin_moderisi(p_vrsta text, p_id bigint, p_radnja text)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not is_admin_user() then raise exception 'samo urednik'; end if;
  if p_radnja not in ('vrati', 'obrisi') or p_vrsta not in ('objava', 'komentar', 'poruka') then raise exception 'nepoznata radnja'; end if;
  if p_vrsta = 'objava' then
    if p_radnja = 'obrisi' then delete from objave where id = p_id;
    else update objave set sakrivena = false where id = p_id; delete from prijave_sadrzaja where objava = p_id and komentar is null; end if;
  elsif p_vrsta = 'komentar' then
    if p_radnja = 'obrisi' then delete from komentari where id = p_id;
    else update komentari set sakriven = false where id = p_id; delete from prijave_sadrzaja where komentar = p_id; end if;
  else
    if p_radnja = 'obrisi' then delete from poruke where id = p_id;
    else delete from prijave_poruka where poruka = p_id; end if;
  end if;
end;
$$;
