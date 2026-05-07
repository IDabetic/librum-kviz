-- Run this once in Supabase SQL Editor.
-- Adds the columns the rematch flow on /igraj-zajedno/[code]/kraj uses to
-- coordinate "we both want a rematch → spin up a new room and redirect".

alter table public.game_rooms
  add column if not exists host_rematch boolean not null default false,
  add column if not exists guest_rematch boolean not null default false,
  add column if not exists rematch_room_code text;

-- Optional but cheap: index for the realtime UI to look up the new room
-- by code if it ever does that path.
create index if not exists game_rooms_rematch_code_idx
  on public.game_rooms (rematch_room_code) where rematch_room_code is not null;
