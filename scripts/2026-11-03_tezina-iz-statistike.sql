-- Težina pitanja iz stvarnih odgovora (03.11.2026): posle najmanje 20 prikaza procenat tačnih određuje težinu.
-- ≥ 75% lako, 45–75% srednje, 20–45% teško, < 20% nemoguće. Pokreće se svake noći (pg_cron) i ručno.
-- Brojači times_correct / times_wrong se pune iz aplikacije (RPC zabelezi_odgovore) i veba.

create or replace function public.preracunaj_tezinu()
returns int language plpgsql security definer set search_path to 'public' as $$
declare n int;
begin
  update questions q set difficulty = case
      when q.times_correct::numeric / nullif(q.times_correct + q.times_wrong, 0) >= 0.75 then 'easy'
      when q.times_correct::numeric / nullif(q.times_correct + q.times_wrong, 0) >= 0.45 then 'medium'
      when q.times_correct::numeric / nullif(q.times_correct + q.times_wrong, 0) >= 0.20 then 'hard'
      else 'impossible' end
  where q.times_correct + q.times_wrong >= 20;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- Aplikacija šalje ishode partije: [{"id": uuid, "tacno": bool}, ...]; najviše 100 po pozivu.
create or replace function public.zabelezi_odgovore(p_odgovori jsonb)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if jsonb_array_length(p_odgovori) > 100 then raise exception 'previše odgovora'; end if;
  -- Isto pitanje dvaput u partiji: zbir po pitanju (UPDATE … FROM menja red samo jednom).
  update questions q set
    times_shown = q.times_shown + z.n,
    times_correct = q.times_correct + z.t,
    times_wrong = q.times_wrong + z.n - z.t
  from (select (o->>'id')::uuid id, count(*)::int n, count(*) filter (where (o->>'tacno')::boolean)::int t
        from jsonb_array_elements(p_odgovori) o group by 1) z
  where q.id = z.id;
end;
$$;

revoke all on function public.preracunaj_tezinu() from public, anon, authenticated;
grant execute on function public.zabelezi_odgovore(jsonb) to anon, authenticated;
select cron.schedule('tezina-pitanja', '30 2 * * *', 'select public.preracunaj_tezinu()');
