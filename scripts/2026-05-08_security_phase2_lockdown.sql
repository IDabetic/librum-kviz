-- ─────────────────────────────────────────────────────────────────
-- PHASE 2: Lock down `profiles` table with RLS
-- ─────────────────────────────────────────────────────────────────
-- Run this AFTER:
--   (a) phase 1 SQL ran successfully (public_profiles view exists)
--   (b) the code-refactor PR is merged and deployed
--   (c) you've verified the site works end-to-end with the view
--
-- This phase closes the P0 leak: anon can no longer read profiles
-- directly. Email / role / phone / is_blocked become inaccessible
-- via the Data API except to the row's owner (via auth.uid()) and
-- to admins (via is_admin()).
-- ─────────────────────────────────────────────────────────────────

begin;

-- 1) Drop any existing permissive policies so we start clean.
drop policy if exists profiles_select_all on public.profiles;
drop policy if exists profiles_select_own on public.profiles;
drop policy if exists profiles_insert_own on public.profiles;
drop policy if exists profiles_update_own on public.profiles;
drop policy if exists profiles_admin_all  on public.profiles;
drop policy if exists profiles_admin_select on public.profiles;
drop policy if exists profiles_admin_update on public.profiles;

-- 2) Enable + force RLS. FORCE means even the table owner respects RLS
-- (relevant if you ever connect as the owner role).
alter table public.profiles enable row level security;
alter table public.profiles force row level security;

-- 3) Revoke everything from anon. Anon goes through public_profiles
-- exclusively from here on.
revoke all on table public.profiles from anon;

-- 4) Authenticated keeps INSERT / UPDATE / SELECT but only against
-- the row policies below. We deliberately don't grant DELETE — users
-- delete their account through the dedicated server route which
-- uses the service role.
revoke all on table public.profiles from authenticated;
grant select, insert, update on table public.profiles to authenticated;

-- 5) Row-level policies. Each operation is scoped to the row owner
-- (auth.uid() = id) OR an admin (public.is_admin()).

-- SELECT: own row only, or admin.
create policy profiles_select_own
on public.profiles
for select
to authenticated
using (
  (select auth.uid()) = id
  or public.is_admin()
);

-- INSERT: create your own row only (signup hook). Admin can insert any.
create policy profiles_insert_own
on public.profiles
for insert
to authenticated
with check (
  (select auth.uid()) = id
  or public.is_admin()
);

-- UPDATE: own row, or admin.
create policy profiles_update_own
on public.profiles
for update
to authenticated
using (
  (select auth.uid()) = id
  or public.is_admin()
)
with check (
  (select auth.uid()) = id
  or public.is_admin()
);

-- DELETE: admins only (regular users go through /api/account-delete
-- which uses the service role and auth.admin.deleteUser).
create policy profiles_delete_admin
on public.profiles
for delete
to authenticated
using (public.is_admin());

commit;

-- ─────────────────────────────────────────────────────────────────
-- Sanity check: as anon (logged-out) the Data API should now refuse
-- to read profiles. Try this from your browser console:
--
--   const r = await fetch(
--     'https://<your-project>.supabase.co/rest/v1/profiles?select=email',
--     { headers: { apikey: '<anon-key>', Authorization: 'Bearer <anon-key>' } }
--   ); console.log(r.status); console.log(await r.text());
--
-- Expected: 200 with an empty array (RLS hides everything from anon),
-- or 401/403. Either way: no email leaks.
--
-- Try the same against public_profiles — should return the safe
-- columns only (id, first_name, last_name, nickname, avatar, city).
-- ─────────────────────────────────────────────────────────────────
