-- Disk IO (Supabase upozorenje 08.11.2026). Dva najveća potrošača:
-- 1) zabelezi_mrezu (nadzor varanja, 05.11) prepisivala je red u igraci_mreza na SVAKI odgovor (111 hiljada upisa,
--    ~1 GB WAL-a): sad osvežava najviše jednom u 10 minuta po (igrač, IP), a stare redove briše ~1 u 50 poziva.
--    Kolona `broj` od sada broji 10-minutne prozore, ne svaki odgovor.
-- 2) aplikacija_pitanja je za opšti fond nasumično sortirala svih ~157 hiljada pitanja (sort na disk, ~1 MB temp po pozivu):
--    sad bira iz uzorka od ~3 % blokova (tablesample, ~4.500 pitanja), pa top-N sort ostaje u memoriji.
--    EXPLAIN ANALYZE: 8.869 → 741 bafera, bez temp fajlova, ~56 ms.

create or replace function public.zabelezi_mrezu(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare z jsonb; v_ip text; v_ua text;
begin
  if p_user is null then return; end if;
  z := nullif(current_setting('request.headers', true), '')::jsonb;
  if z is null then return; end if;
  v_ip := coalesce(nullif(z->>'cf-connecting-ip', ''), nullif(btrim(split_part(z->>'x-forwarded-for', ',', 1)), ''), nullif(z->>'x-real-ip', ''));
  if v_ip is null then return; end if;
  v_ua := left(z->>'user-agent', 200);
  insert into igraci_mreza (user_id, ip, uredjaj) values (p_user, v_ip, v_ua)
  on conflict (user_id, ip) do update set poslednji = now(), broj = igraci_mreza.broj + 1, uredjaj = coalesce(excluded.uredjaj, igraci_mreza.uredjaj)
    where igraci_mreza.poslednji < now() - interval '10 minutes';
  if random() < 0.02 then
    delete from igraci_mreza where user_id = p_user and poslednji < now() - interval '90 days';
  end if;
exception when others then
  raise warning 'zabelezi_mrezu: %', sqlerrm;
end $$;

create or replace function public.aplikacija_pitanja(p_igra text, p_broj integer default 60)
returns table(id uuid, question_text text, options jsonb, correct_answer integer, genre text)
language sql security definer set search_path to 'public' as $$
  with kandidati as (
    -- opšti fond je velik: uzorak blokova umesto sortiranja celog fonda
    select q.id, 'opste'::text as izvor from questions q tablesample system (3)
    where p_igra = 'opste' and q.is_active and jsonb_array_length(q.options) = 4
    union all
    select b.id, 'book' from book_questions b where p_igra = 'book' and b.is_active and jsonb_array_length(b.options) = 4
    union all
    select k.id, 'kafana' from kafana_questions k where p_igra = 'kafana' and k.is_active and array_length(k.options, 1) = 4
  ),
  izbor as (
    select c.id, c.izvor from kandidati c left join moja_vidjena() v on v.pitanje = c.id
    order by v.kad asc nulls first, random()
    limit least(greatest(p_broj, 1), 80)
  ),
  upis as (
    insert into vidjena_pitanja (user_id, pitanje, kad)
    select auth.uid(), i.id, now() from izbor i where auth.uid() is not null
    on conflict (user_id, pitanje) do update set kad = excluded.kad
  ),
  redovi as (
    select q.id, q.question_text, q.options, q.correct_answer::int as correct_answer, null::text as genre, q.tags
    from izbor i join questions q on q.id = i.id where i.izvor = 'opste'
    union all
    select b.id, b.question_text, b.options, b.correct_answer::int, b.genre, null::text[]
    from izbor i join book_questions b on b.id = i.id where i.izvor = 'book'
    union all
    select k.id, k.question_text, to_jsonb(k.options), k.correct_answer, null::text, null::text[]
    from izbor i join kafana_questions k on k.id = i.id where i.izvor = 'kafana'
  )
  select r.id, r.question_text, r.options, r.correct_answer,
         coalesce(r.genre, (select case t when 'film i tv' then 'Film i TV' else upper(left(t, 1)) || substr(t, 2) end
            from unnest(r.tags) with ordinality as x(t, n)
            where t in ('film i tv', 'muzika', 'geografija', 'jezik', 'sport', 'istorija', 'književnost', 'ličnosti', 'kultura',
                        'nauka', 'priroda', 'umetnost', 'religija i mitologija', 'hrana i piće', 'tehnika', 'tradicija')
            order by n limit 1))
  from redovi r;
$$;
