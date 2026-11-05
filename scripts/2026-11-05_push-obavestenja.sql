-- Push obaveštenja (izazov na duel, novi pratilac) — 05.11.2026, migracija karijera_51.
-- Tajne (APNs ključ, Firebase servisni nalog, deljena tajna) stoje u Supabase Vault-u, ne u kodu.
-- Upisuju se jednom, van repoa:  select vault.create_secret('<vrednost>', 'APNS_KEY');
--   imena: APNS_KEY, APNS_KEY_ID, APNS_TEAM_ID, APNS_PRODUKCIJA ('1'), FIREBASE_SA (ceo JSON), OBAVESTI_TAJNA
-- Funkcija `obavesti` ih čita preko push_tajne() (samo service_role), okidač ih koristi za zaglavlje.

create extension if not exists pg_net;

create or replace function public.push_tajne() returns jsonb
language sql security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(name, decrypted_secret), '{}'::jsonb)
  from vault.decrypted_secrets
  where name in ('APNS_KEY', 'APNS_KEY_ID', 'APNS_TEAM_ID', 'APNS_PRODUKCIJA', 'FIREBASE_SA', 'OBAVESTI_TAJNA')
$$;
revoke all on function public.push_tajne() from public, anon, authenticated;
grant execute on function public.push_tajne() to service_role;

-- Okidač šalje red funkciji `obavesti` asinhrono (pg_net); greška u slanju nikad ne obara upis izazova/praćenja.
create or replace function public.obavesti_okidac() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  tajna text;
begin
  select decrypted_secret into tajna from vault.decrypted_secrets where name = 'OBAVESTI_TAJNA';
  if tajna is null then return new; end if;
  perform net.http_post(
    url := 'https://htnfatughrtmbgtekxfs.supabase.co/functions/v1/obavesti',
    body := jsonb_build_object('type', tg_op, 'table', tg_table_name, 'record', to_jsonb(new)),
    headers := jsonb_build_object('content-type', 'application/json', 'x-obavesti-tajna', tajna),
    timeout_milliseconds := 5000);
  return new;
exception when others then
  raise warning 'obavesti_okidac: %', sqlerrm;
  return new;
end $$;
revoke all on function public.obavesti_okidac() from public, anon, authenticated;

drop trigger if exists obavesti_izazov on public.izazovi;
create trigger obavesti_izazov after insert on public.izazovi for each row execute function public.obavesti_okidac();
drop trigger if exists obavesti_pracenje on public.pracenja;
create trigger obavesti_pracenje after insert on public.pracenja for each row execute function public.obavesti_okidac();
