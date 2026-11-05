-- „Moj rezultat” iz stvarnih partija — 05.11.2026, migracija karijera_55.
-- Ranije je objava rezultata primala bilo koji broj poena sa telefona (lažni rekordi u zajednici).
-- Sada telefon nudi poslednje rezultate (moji_poslednji_rezultati), a objava nosi njihov id; server sam upisuje igru i poene.

/**
 * Poslednji rezultati prijavljenog igrača iz svih igara aplikacije i Karijeriste.
 * Primer: select * from moji_poslednji_rezultati(15);
 */
create or replace function public.moji_poslednji_rezultati(p_broj int default 15)
returns table (izvor text, igra text, poeni int, tacnih int, kad timestamptz)
language sql stable security definer set search_path = 'public' as $$
  select * from (
    select 'r:' || r.id, r.igra, r.poeni, r.tacnih, r.created_at
    from rezultati_igara r where r.user_id = auth.uid()
    union all
    select 'k:' || k.id, 'karijera', k.poeni, k.tacnih, k.kad
    from karijera_runde k where k.user_id = auth.uid()
  ) svi
  order by 5 desc
  limit least(greatest(p_broj, 1), 50)
$$;
revoke all on function public.moji_poslednji_rezultati(int) from public, anon;
grant execute on function public.moji_poslednji_rezultati(int) to authenticated;

/**
 * Nova objava. Za vrstu 'rezultat' igra i poeni dolaze iz izvora (p_rezultat = 'r:<id>' ili 'k:<id>') koji pripada igraču;
 * starije verzije aplikacije bez izvora mogu da objave samo rezultat koji zaista postoji u poslednjih 30 dana.
 * Primer: select nova_objava('rezultat', 'Novi rekord!', p_rezultat => 'k:812');
 */
create or replace function public.nova_objava(p_vrsta text, p_tekst text default '', p_igra text default null,
  p_poeni int default null, p_kod_sobe text default null, p_rezultat text default null)
returns bigint
language plpgsql security definer set search_path = 'public' as $$
declare
  novi bigint;
  igra text := p_igra;
  poeni int := p_poeni;
  broj bigint;
begin
  if auth.uid() is null then raise exception 'prijava je obavezna'; end if;
  if exists (select 1 from profiles where id = auth.uid() and is_blocked) then raise exception 'nalog je blokiran'; end if;
  if (select count(*) from objave where ko = auth.uid() and created_at > now() - interval '1 day') >= 20 then
    raise exception 'danas si objavio 20 puta, nastavi sutra';
  end if;

  if p_vrsta = 'rezultat' then
    if p_rezultat ~ '^r:\d+$' then
      broj := substring(p_rezultat from 3)::bigint;
      select r.igra, r.poeni into igra, poeni from rezultati_igara r where r.id = broj and r.user_id = auth.uid();
    elsif p_rezultat ~ '^k:\d+$' then
      broj := substring(p_rezultat from 3)::bigint;
      select 'karijera', k.poeni into igra, poeni from karijera_runde k where k.id = broj and k.user_id = auth.uid();
    elsif not exists (select 1 from rezultati_igara r where r.user_id = auth.uid() and r.igra = p_igra and r.poeni = p_poeni
                        and r.created_at > now() - interval '30 days') then
      igra := null;
    end if;
    if igra is null then raise exception 'taj rezultat nije pronađen među tvojim partijama'; end if;
  end if;

  insert into objave (ko, vrsta, igra, tekst, poeni, kod_sobe)
  values (auth.uid(), p_vrsta, igra, btrim(coalesce(p_tekst, '')), case when p_vrsta = 'rezultat' then poeni else p_poeni end, p_kod_sobe)
  returning id into novi;
  return novi;
end $$;
