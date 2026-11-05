-- Osvajanje: kako igrač igra (vlasnik 04.11.2026): sam, u savezu (svako svoja boja i vojska) ili zajedno (isti tim, ista boja).
-- Aplikacija upisuje način uz rezultat partije; javni profil (profil_igraca) pokazuje koliko partija je odigrano na koji način.
-- Aditivno: stari klijenti ne šalju kolonu (null), profil tada ništa ne broji.

alter table public.rezultati_igara add column if not exists nacin text
  check (nacin is null or nacin in ('sam', 'savez', 'zajedno'));

do $$
declare d text;
begin
  d := pg_get_functiondef('public.profil_igraca(uuid)'::regprocedure);
  if position('osvajanje_nacin' in d) = 0 then
    d := replace(d, '''skoro'', coalesce(',
      '''osvajanje_nacin'', (select jsonb_build_object(''sam'', count(*) filter (where nacin = ''sam''), ''savez'', count(*) filter (where nacin = ''savez''), ''zajedno'', count(*) filter (where nacin = ''zajedno'')) from rezultati_igara where user_id = p.id and igra = ''osvajanje''),
    ''skoro'', coalesce(');
    execute d;
  end if;
end $$;

-- Dopuna 04.11.2026 uveče: izdaje saveznika na profilu (koliko puta je igrač izdao, koliko saveza je odigrao verno).
alter table public.rezultati_igara add column if not exists izdaja int check (izdaja is null or izdaja between 0 and 50);
do $$
declare d text;
begin
  d := pg_get_functiondef('public.profil_igraca(uuid)'::regprocedure);
  if position('''izdaje''' in d) = 0 then
    d := replace(d, '''zajedno'', count(*) filter (where nacin = ''zajedno''))',
      '''zajedno'', count(*) filter (where nacin = ''zajedno''), ''izdaje'', coalesce(sum(izdaja), 0), ''verno'', count(*) filter (where nacin = ''savez'' and coalesce(izdaja, 0) = 0))');
    execute d;
  end if;
end $$;
