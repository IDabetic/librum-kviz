-- ─────────────────────────────────────────────────────────────────
-- PHASE 1: Create public_profiles view + is_admin() function
-- ─────────────────────────────────────────────────────────────────
-- Run this FIRST in Supabase SQL Editor.
-- This is non-disruptive: it only ADDS a view and a helper function.
-- The existing `profiles` table stays unchanged for now.
--
-- After this runs successfully, merge PR with code refactor that
-- switches anon-facing queries to public_profiles. Verify the site
-- still works (leaderboard, public profile, header) — then run
-- phase 2 to finally lock profiles down.
-- ─────────────────────────────────────────────────────────────────

-- 1) Helper: is the current authenticated user an admin?
-- SECURITY DEFINER so the function bypasses RLS on profiles
-- (otherwise we'd hit infinite recursion: policy → profiles → policy → ...).
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role in ('admin', 'super_admin')
  );
$$;

grant execute on function public.is_admin() to anon, authenticated;

-- 2) Public view: only the columns that are safe to expose to anon
-- (and to authenticated users looking at someone else's profile).
-- security_invoker = false (DEFINER mode) so the view bypasses RLS
-- on the underlying `profiles` table. The column whitelist is the
-- only thing controlling what leaks out — and we deliberately
-- expose only display-safe fields here.
create or replace view public.public_profiles
with (security_invoker = false) as
select
  id,
  first_name,
  last_name,
  nickname,
  avatar,
  city,
  created_at
from public.profiles;

-- Read access to anon + authenticated.
grant select on public.public_profiles to anon, authenticated;

-- 3) Add `is_blocked` column for admin moderation (used by phase 3).
-- Default false so existing rows aren't blocked. We block a user by
-- setting this to true; the middleware will then sign them out.
alter table public.profiles
  add column if not exists is_blocked boolean not null default false;

-- ─────────────────────────────────────────────────────────────────
-- Verify phase 1 worked:
--   select count(*) from public.public_profiles;  -- should match profiles count
--   select public.is_admin();                     -- should return true/false
-- ─────────────────────────────────────────────────────────────────
