-- Moderacija društvene mreže iz admina /majmun (03.11.2026): prijavljene i sakrivene objave i komentari.
-- Tabele nemaju RLS politike, pa admin čita i menja samo kroz ove funkcije, koje traže is_admin_user().

-- Prijavljen ili sakriven sadržaj, najnovija prijava prva.
create or replace function public.admin_prijave_sadrzaja()
returns table (vrsta text, id bigint, objava bigint, tekst text, autor uuid, nadimak text, prijava bigint, razlozi text, sakriveno boolean, poslednja timestamptz)
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
  order by 10 desc nulls last
  limit 300;
end;
$$;

-- „vrati”: sadržaj je u redu, prijave se brišu i vidi se ponovo; „obrisi”: sadržaj se briše (sa prijavama, kaskadno).
create or replace function public.admin_moderisi(p_vrsta text, p_id bigint, p_radnja text)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not is_admin_user() then raise exception 'samo urednik'; end if;
  if p_radnja not in ('vrati', 'obrisi') or p_vrsta not in ('objava', 'komentar') then raise exception 'nepoznata radnja'; end if;
  if p_vrsta = 'objava' then
    if p_radnja = 'obrisi' then delete from objave where id = p_id;
    else update objave set sakrivena = false where id = p_id; delete from prijave_sadrzaja where objava = p_id and komentar is null; end if;
  else
    if p_radnja = 'obrisi' then delete from komentari where id = p_id;
    else update komentari set sakriven = false where id = p_id; delete from prijave_sadrzaja where komentar = p_id; end if;
  end if;
end;
$$;

revoke all on function public.admin_prijave_sadrzaja(), public.admin_moderisi(text, bigint, text) from public, anon;
grant execute on function public.admin_prijave_sadrzaja(), public.admin_moderisi(text, bigint, text) to authenticated;
