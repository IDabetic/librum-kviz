-- ─────────────────────────────────────────────────────────────────
-- order_num for book_questions + kafana_questions
-- ─────────────────────────────────────────────────────────────────
-- Run once in Supabase SQL Editor.
--
-- public.questions already has an `order_num` integer column that the
-- admin "🔢 Promešaj redosled pitanja" tool randomizes. Book and
-- Kafanski pools didn't have it, so the order-shuffle would fail for
-- them. This adds the column with the same shape. Idempotent — safe
-- to run multiple times.
-- ─────────────────────────────────────────────────────────────────

alter table public.book_questions
  add column if not exists order_num integer not null default 0;

alter table public.kafana_questions
  add column if not exists order_num integer not null default 0;

-- Sanity check:
--   select count(*) from public.book_questions where order_num = 0;
--   select count(*) from public.kafana_questions where order_num = 0;
-- (All rows start at 0; the admin shuffle tool reassigns them.)
