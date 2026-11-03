-- Pitanja se igraču ne ponavljaju 7 dana (03.11.2026, vlasnik):
-- 1) nikad viđena idu prva; 2) od viđenih pre 7+ dana sme najviše 10% partije; 3) viđena u poslednjih 7 dana
-- dolaze tek kad igrač prođe ceo fond. „Viđeno” = poslato aplikaciji (vidjena_pitanja) ili odgovoreno na vebu (question_answer_log).
-- Bez prijave izbor ostaje nasumičan.

create table if not exists public.vidjena_pitanja (
  user_id uuid not null references auth.users (id) on delete cascade,
  pitanje uuid not null,
  kad timestamptz not null default now(),
  primary key (user_id, pitanje)
);
alter table public.vidjena_pitanja enable row level security;
create index if not exists question_answer_log_user_question on public.question_answer_log (user_id, question_id, created_at);

-- Viđena pitanja igrača sa poslednjim viđenjem (aplikacija + veb).
create or replace function public.moja_vidjena()
returns table (pitanje uuid, kad timestamptz)
language sql stable security definer set search_path to 'public' as $$
  select x.pitanje, max(x.kad) from (
    select v.pitanje, v.kad from vidjena_pitanja v where v.user_id = auth.uid()
    union all
    select l.question_id, l.created_at from question_answer_log l where l.user_id = auth.uid()
  ) x group by x.pitanje;
$$;

-- Paket za igre u aplikaciji (PRO, Book, Brzi, Duel, Osvajanje, Kafana).
create or replace function public.aplikacija_pitanja(p_igra text, p_broj integer default 60)
returns table (id uuid, question_text text, options jsonb, correct_answer integer, genre text)
language sql volatile security definer set search_path to 'public' as $$
  with sve as (
    select q.id, q.question_text, q.options, q.correct_answer::int as correct_answer, null::text as genre
    from questions q where p_igra = 'opste' and q.is_active and jsonb_array_length(q.options) = 4
    union all
    select b.id, b.question_text, b.options, b.correct_answer::int, b.genre
    from book_questions b where p_igra = 'book' and b.is_active and jsonb_array_length(b.options) = 4
    union all
    select k.id, k.question_text, to_jsonb(k.options), k.correct_answer, null::text
    from kafana_questions k where p_igra = 'kafana' and k.is_active and array_length(k.options, 1) = 4
  ),
  n as (select least(greatest(p_broj, 1), 80) as broj),
  vidjeno as (select * from moja_vidjena()),
  rang as (
    select s.*, g.grupa, row_number() over (partition by g.grupa order by random()) as rb
    from sve s left join vidjeno v on v.pitanje = s.id
    cross join lateral (select case when v.kad is null then 0 when v.kad < now() - interval '7 days' then 1 else 2 end as grupa) g
  ),
  izbor as (
    select r.* from rang r, n
    -- Nova i do 10% starih zajedno; ostatak starih, pa sveže viđena, tek kad novih nema dovoljno.
    order by case when r.grupa = 0 or (r.grupa = 1 and r.rb <= ceil(n.broj * 0.1)) then 0 else r.grupa end, random()
    limit (select broj from n)
  ),
  upis as (
    insert into vidjena_pitanja (user_id, pitanje, kad)
    select auth.uid(), i.id, now() from izbor i where auth.uid() is not null
    on conflict (user_id, pitanje) do update set kad = excluded.kad
  )
  select i.id, i.question_text, i.options, i.correct_answer, i.genre from izbor i;
$$;

-- Kviz po temi (10 pitanja): isto pravilo; tema može biti i kategorija (tags).
create or replace function public.aplikacija_kviz(p_fond text, p_zanr text default null, p_tezina text default null, p_broj integer default 10)
returns table (id uuid, question_text text, options jsonb, correct_answer integer, genre text)
language sql volatile security definer set search_path to 'public' as $$
  with sve as (
    select q.id, q.question_text, q.options, q.correct_answer::int as correct_answer, null::text as genre
    from questions q
    where p_fond = 'opste' and q.is_active and jsonb_array_length(q.options) = 4
      and (p_tezina is distinct from 'tesko' or q.difficulty in ('hard', 'impossible'))
      and (p_zanr is null or p_zanr = any(q.tags))
    union all
    select b.id, b.question_text, b.options, b.correct_answer::int, b.genre
    from book_questions b
    where p_fond = 'book' and b.is_active and jsonb_array_length(b.options) = 4 and (p_zanr is null or b.genre = p_zanr)
  ),
  n as (select least(greatest(p_broj, 1), 30) as broj),
  vidjeno as (select * from moja_vidjena()),
  rang as (
    select s.*, g.grupa, row_number() over (partition by g.grupa order by random()) as rb
    from sve s left join vidjeno v on v.pitanje = s.id
    cross join lateral (select case when v.kad is null then 0 when v.kad < now() - interval '7 days' then 1 else 2 end as grupa) g
  ),
  izbor as (
    select r.* from rang r, n
    order by case when r.grupa = 0 or (r.grupa = 1 and r.rb <= ceil(n.broj * 0.1)) then 0 else r.grupa end, random()
    limit (select broj from n)
  ),
  upis as (
    insert into vidjena_pitanja (user_id, pitanje, kad)
    select auth.uid(), i.id, now() from izbor i where auth.uid() is not null
    on conflict (user_id, pitanje) do update set kad = excluded.kad
  )
  select i.id, i.question_text, i.options, i.correct_answer, i.genre from izbor i;
$$;

-- PRO na vebu: isto pravilo (umesto dosadašnjih 72 sata); viđeno se tu beleži odgovorom (question_answer_log).
create or replace function public.pro_pitanja(p_broj integer default 300)
returns table (id uuid, question_text text, options jsonb, correct_answer integer, difficulty text, info text)
language sql volatile security definer set search_path to 'public' as $$
  with n as (select least(greatest(p_broj, 50), 600) as broj),
  vidjeno as (select * from moja_vidjena()),
  rang as (
    select q.id, q.question_text, q.options, q.correct_answer, q.difficulty, q.info, g.grupa,
           row_number() over (partition by g.grupa order by random()) as rb
    from questions q left join vidjeno v on v.pitanje = q.id
    cross join lateral (select case when v.kad is null then 0 when v.kad < now() - interval '7 days' then 1 else 2 end as grupa) g
    where q.is_active
  )
  select r.id, r.question_text, r.options, r.correct_answer, r.difficulty, r.info from rang r, n
  order by case when r.grupa = 0 or (r.grupa = 1 and r.rb <= ceil(n.broj * 0.1)) then 0 else r.grupa end, (r.difficulty = 'medium'), random()
  limit (select broj from n);
$$;

revoke all on function public.moja_vidjena() from public, anon;
grant execute on function public.moja_vidjena() to authenticated;
grant execute on function public.aplikacija_pitanja(text, integer), public.aplikacija_kviz(text, text, text, integer), public.pro_pitanja(integer) to anon, authenticated;
