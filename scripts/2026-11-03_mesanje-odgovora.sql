-- Redosled odgovora se meša svakih 7 dana (03.11.2026, vlasnik): igrači pamte „bio je pod A”.
-- Svako pitanje dobija nov nasumičan redosled; correct_answer prati tačan odgovor. Admin može i ručno (/majmun/podesavanja).
-- Napomena: duel koji traje dok se meša prikaže rivalov izbor na drugom mestu; poeni se računaju u trenutku odgovora, pa ostaju tačni.

create table if not exists public.mesanje_odgovora (
  id bigint generated always as identity primary key,
  kad timestamptz not null default now(),
  ko uuid,
  pitanja int not null
);
alter table public.mesanje_odgovora enable row level security;

create or replace function public.promesaj_odgovore(p_ko uuid default null)
returns int language plpgsql security definer set search_path to 'public' as $$
declare n int := 0; m int;
begin
  -- Za svako pitanje: permutacija 0..3, nove opcije po njoj, tačan odgovor na svom novom mestu.
  with p as (
    select q.id, array_agg(o.i order by random()) red
    from questions q cross join generate_series(0, jsonb_array_length(q.options) - 1) o(i)
    where jsonb_array_length(q.options) = 4 group by q.id
  )
  update questions q set
    options = (select jsonb_agg(q.options -> r.i order by r.ord) from unnest(p.red) with ordinality r(i, ord)),
    correct_answer = array_position(p.red, q.correct_answer) - 1
  from p where p.id = q.id;
  get diagnostics m = row_count; n := n + m;

  with p as (
    select b.id, array_agg(o.i order by random()) red
    from book_questions b cross join generate_series(0, jsonb_array_length(b.options) - 1) o(i)
    where jsonb_array_length(b.options) = 4 group by b.id
  )
  update book_questions b set
    options = (select jsonb_agg(b.options -> r.i order by r.ord) from unnest(p.red) with ordinality r(i, ord)),
    correct_answer = array_position(p.red, b.correct_answer::int) - 1
  from p where p.id = b.id;
  get diagnostics m = row_count; n := n + m;

  with p as (
    select k.id, array_agg(o.i order by random()) red
    from kafana_questions k cross join generate_series(1, array_length(k.options, 1)) o(i)
    where array_length(k.options, 1) = 4 group by k.id
  )
  update kafana_questions k set
    options = (select array_agg(k.options[r.i] order by r.ord) from unnest(p.red) with ordinality r(i, ord)),
    correct_answer = array_position(p.red, k.correct_answer + 1) - 1
  from p where p.id = k.id;
  get diagnostics m = row_count; n := n + m;

  insert into mesanje_odgovora (ko, pitanja) values (p_ko, n);
  return n;
end;
$$;

-- Ručno iz admina: samo urednik.
create or replace function public.admin_promesaj_odgovore()
returns int language plpgsql security definer set search_path to 'public' as $$
begin
  if not is_admin_user() then raise exception 'samo urednik'; end if;
  return promesaj_odgovore(auth.uid());
end;
$$;

create or replace function public.admin_poslednje_mesanje()
returns table (kad timestamptz, pitanja int)
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not is_admin_user() then raise exception 'samo urednik'; end if;
  return query select m.kad, m.pitanja from mesanje_odgovora m order by m.kad desc limit 1;
end;
$$;

revoke all on function public.promesaj_odgovore(uuid) from public, anon, authenticated;
revoke all on function public.admin_promesaj_odgovore(), public.admin_poslednje_mesanje() from public, anon;
grant execute on function public.admin_promesaj_odgovore(), public.admin_poslednje_mesanje() to authenticated;

-- Svakog ponedeljka u 03:00 UTC (04:00 Beograd).
create extension if not exists pg_cron;
select cron.schedule('mesanje-odgovora', '0 3 * * 1', 'select public.promesaj_odgovore(null)');
