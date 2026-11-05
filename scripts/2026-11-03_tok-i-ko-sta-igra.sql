-- Igrači (vlasnik 03.11.2026, UX prolaz):
-- 1) tok_objava: bez prijave `moja` je bilo NULL (o.ko = NULL) i app nije mogao da pročita objave → coalesce na false.
-- 2) ko_sta_igra: isti igrač se ponavljao po svakoj igri → jedan red po igraču (poslednja igra).
create or replace function public.tok_objava(p_vrsta text default 'svi', p_pre bigint default null, p_broj integer default 20)
returns table(id bigint, ko uuid, nadimak text, avatar text, vrsta text, igra text, tekst text, poeni integer, kod_sobe text,
              created_at timestamp with time zone, srca bigint, moje_srce boolean, komentara bigint, moja boolean)
language sql stable security definer set search_path to 'public' as $function$
  select o.id, o.ko, coalesce(nullif(p.nickname, ''), nullif(p.first_name, ''), 'Igrač'), p.avatar, o.vrsta, o.igra, o.tekst, o.poeni, o.kod_sobe,
         o.created_at,
         (select count(*) from objave_srca s where s.objava = o.id),
         exists (select 1 from objave_srca s where s.objava = o.id and s.ko = auth.uid()),
         (select count(*) from komentari k where k.objava = o.id and not k.sakriven),
         coalesce(o.ko = auth.uid(), false)
  from objave o join public_profiles p on p.id = o.ko
  where not o.sakrivena
    and (p_pre is null or o.id < p_pre)
    and (auth.uid() is null or not blokirani(auth.uid(), o.ko))
    and (p_vrsta <> 'pratim' or o.ko = auth.uid() or exists (select 1 from pracenja f where f.ko = auth.uid() and f.koga = o.ko))
  order by o.id desc
  limit least(greatest(p_broj, 1), 50);
$function$;

create or replace function public.ko_sta_igra(p_broj integer default 20)
returns table(ko uuid, nadimak text, avatar text, igra text, poeni integer, kad timestamp with time zone)
language sql stable security definer set search_path to 'public' as $function$
  with poslednja as (
    select distinct on (r.user_id) r.user_id, r.igra, r.poeni, r.created_at
    from rezultati_igara r
    where r.created_at > now() - interval '7 days'
      and (auth.uid() is null or not blokirani(auth.uid(), r.user_id))
    order by r.user_id, r.created_at desc
  )
  select r.user_id, coalesce(nullif(p.nickname, ''), nullif(p.first_name, ''), 'Igrač'), p.avatar, r.igra, r.poeni, r.created_at
  from poslednja r join public_profiles p on p.id = r.user_id
  order by (exists (select 1 from pracenja f where f.ko = auth.uid() and f.koga = r.user_id)) desc, r.created_at desc
  limit least(greatest(p_broj, 1), 50);
$function$;
