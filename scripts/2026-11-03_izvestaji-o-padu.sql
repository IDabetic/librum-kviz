-- Izveštaji o padu aplikacije (Apple MetricKit, Android posle restarta): stek poziva bez ličnih podataka.
-- App upisuje (anon ili prijavljen), niko ne čita kroz API; čita se samo iz SQL konzole / service role.
-- Ažurirano: 3. novembar 2026. · v1

create table if not exists izvestaji_o_padu (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  platforma text not null check (platforma in ('ios', 'android')),
  verzija text not null check (char_length(verzija) <= 40),
  izvestaj jsonb not null check (pg_column_size(izvestaj) <= 262144)
);
create index if not exists izvestaji_o_padu_created_at_idx on izvestaji_o_padu (created_at desc);
alter table izvestaji_o_padu enable row level security;
drop policy if exists "upis izvestaja o padu" on izvestaji_o_padu;
create policy "upis izvestaja o padu" on izvestaji_o_padu for insert to anon, authenticated with check (true);
grant insert on izvestaji_o_padu to anon, authenticated;
