-- Profil u aplikaciji kao Instagram / Librum eBook (03.11.2026): „o meni”, pratioci, praćeni,
-- jedinstvena i ponovljena pitanja, sve statistike sa veba (kviz.librum.club/profil) i iz aplikacije.

-- „O meni” (bio), kratko; javni profil ga nosi da ga vide i drugi.
alter table public.profiles add column if not exists bio text check (char_length(bio) <= 160);
alter table public.public_profiles add column if not exists bio text;

create or replace function public.tg_sync_public_profiles()
returns trigger language plpgsql security definer set search_path to 'public', 'pg_catalog' as $$
begin
  if (tg_op = 'DELETE') then
    delete from public.public_profiles where id = old.id;
    return old;
  end if;
  insert into public.public_profiles (id, first_name, last_name, nickname, avatar, city, bio, created_at)
  values (new.id, new.first_name, new.last_name, new.nickname, new.avatar, new.city, new.bio, new.created_at)
  on conflict (id) do update set
    first_name = excluded.first_name, last_name = excluded.last_name, nickname = excluded.nickname,
    avatar = excluded.avatar, city = excluded.city, bio = excluded.bio, created_at = excluded.created_at;
  return new;
end;
$$;

-- Duel statistika (pobede/porazi) bira sobe po igraču.
create index if not exists game_rooms_host_idx on public.game_rooms (host_id);
create index if not exists game_rooms_guest_idx on public.game_rooms (guest_id);

-- Ceo profil igrača u jednom pozivu; isti za moj i tuđi profil (javni podaci + statistike).
create or replace function public.profil_igraca(p_id uuid)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  with
  odgovori as (
    select 'q' || question_id::text as pitanje, was_correct, time_ms from question_answer_log where user_id = p_id
    union all select 'b' || question_id::text, was_correct, time_ms from book_answer_log where user_id = p_id
    union all select 's' || statement_id::text, was_correct, time_ms from quick_answer_log where user_id = p_id
  ),
  duel as (
    select case when (case when host_id = p_id then host_score else guest_score end) > (case when host_id = p_id then guest_score else host_score end) then 'p'
                when (case when host_id = p_id then host_score else guest_score end) < (case when host_id = p_id then guest_score else host_score end) then 'z'
                else 'n' end as ishod
    from game_rooms where (host_id = p_id or guest_id = p_id) and (status = 'finished' or (host_finished and guest_finished))
  ),
  aktivnost as (
    select igra, poeni, created_at from rezultati_igara where user_id = p_id
    union all select 'pro', score, created_at from survivor_sessions where user_id = p_id
    union all select 'book', score, created_at from book_sessions where user_id = p_id
    union all select 'vesanje', score, created_at from hangman_sessions where user_id = p_id
    union all select 'brzi', score, created_at from quick_sessions where user_id = p_id
  )
  select jsonb_build_object(
    'id', p.id, 'nadimak', coalesce(nullif(p.nickname, ''), nullif(p.first_name, ''), 'Igrač'), 'avatar', p.avatar, 'od', p.created_at,
    'ime', nullif(trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), ''),
    'grad', p.city, 'bio', p.bio,
    'pratilaca', (select count(*) from pracenja where koga = p.id),
    'prati', (select count(*) from pracenja where ko = p.id),
    'ja_pratim', exists (select 1 from pracenja where ko = auth.uid() and koga = p.id),
    'autor_pitanja', coalesce((select accepted from contributor_counts where user_id = p.id), 0),
    'pitanja', (select jsonb_build_object(
        'odgovora', count(*), 'jedinstvenih', count(distinct pitanje), 'ponovljenih', count(*) - count(distinct pitanje),
        'tacnost', case when count(*) > 0 then round(100.0 * count(*) filter (where was_correct) / count(*)) end,
        'prosek_ms', avg(time_ms)::int) from odgovori),
    'partija', (select count(*) from aktivnost),
    'veb', jsonb_build_object(
      'pro', (select jsonb_build_object('partija', count(*), 'rekord', max(score), 'max_pitanja', max(questions_reached), 'niz', max(best_combo))
              from survivor_sessions where user_id = p.id),
      'book', (select jsonb_build_object('partija', count(*), 'rekord', max(score), 'max_pitanja', max(questions_reached),
                      'zanr', (select top_genre from book_sessions where user_id = p.id and top_genre is not null group by top_genre order by count(*) desc limit 1))
               from book_sessions where user_id = p.id),
      'vesanje', (select jsonb_build_object('partija', count(*), 'pobeda', count(*) filter (where won), 'bodovi', coalesce(sum(score), 0))
                  from hangman_sessions where user_id = p.id),
      'brzi', (select jsonb_build_object('partija', count(*), 'rekord', max(score), 'tacnih', coalesce(sum(correct_count), 0), 'tacnost', round(avg(accuracy)))
               from quick_sessions where user_id = p.id),
      'duel', (select jsonb_build_object('pobeda', count(*) filter (where ishod = 'p'), 'poraza', count(*) filter (where ishod = 'z'), 'nereseno', count(*) filter (where ishod = 'n'))
               from duel)),
    'igre', coalesce((
      select jsonb_agg(jsonb_build_object(
        'igra', g.igra, 'partija', g.partija, 'najbolje', g.najbolje, 'prosek_ms', g.prosek_ms,
        'tacnost', case when g.odgovora > 0 then round(g.tacnih * 100.0 / g.odgovora) end,
        'sa_pomoci', g.sa_pomoci) order by g.partija desc)
      from (
        select igra, count(*) as partija, max(poeni) as najbolje, avg(prosek_ms)::int as prosek_ms,
               sum(tacnih) as tacnih, sum(tacnih + netacnih) as odgovora, count(pomoc) as sa_pomoci
        from rezultati_igara where user_id = p.id group by igra
      ) g), '[]'::jsonb),
    'pomoci', coalesce((
      select jsonb_object_agg(pomoc, broj) from (
        select pomoc, count(*) as broj from rezultati_igara where user_id = p.id and pomoc is not null group by pomoc
      ) x), '{}'::jsonb),
    'skoro', coalesce((select jsonb_agg(jsonb_build_object('igra', igra, 'poeni', poeni, 'kad', created_at) order by created_at desc)
                       from (select * from aktivnost order by created_at desc limit 10) a), '[]'::jsonb)
  )
  from public_profiles p where p.id = p_id;
$$;

-- Pratioci i praćeni (spisak kao na Instagramu); javni podaci.
create or replace function public.spisak_pracenja(p_id uuid, p_vrsta text)
returns table (id uuid, nadimak text, avatar text, ja_pratim boolean)
language sql stable security definer set search_path to 'public' as $$
  select pp.id, coalesce(nullif(pp.nickname, ''), nullif(pp.first_name, ''), 'Igrač'), pp.avatar,
         exists (select 1 from pracenja x where x.ko = auth.uid() and x.koga = pp.id)
  from pracenja f join public_profiles pp on pp.id = case when p_vrsta = 'pratioci' then f.ko else f.koga end
  where case when p_vrsta = 'pratioci' then f.koga else f.ko end = p_id
  order by f.created_at desc
  limit 200;
$$;

grant execute on function public.profil_igraca(uuid), public.spisak_pracenja(uuid, text) to anon, authenticated;
