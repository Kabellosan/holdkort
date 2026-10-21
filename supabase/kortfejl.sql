-- ⚠️ Kortfejl (2026-10-21). Run once in the Supabase SQL editor after notes_photos_pins.sql; it is safe to run again.
--
-- A kortfejl is a pin that tells the kommune its map is wrong (an element missing, the wrong type, in the wrong
-- place, gone, or not matching the tilbudsliste). It can be made outside a task, so task_id may now be empty.
-- Its conversation is in element_log with element_id 'pin:<pin id>', like any other pin.

alter table public.pins alter column task_id drop not null;
alter table public.pins add column if not exists flaw text;      -- what is wrong; null = an ordinary pin in a task
alter table public.pins add column if not exists element text;   -- '<layer short>:<ogc_fid>' when it is about one kommune element
alter table public.pins add column if not exists code text;      -- that element's elementkode
alter table public.pins add column if not exists reported date;  -- the day it was sent to the kommune
alter table public.pins add column if not exists what text;      -- that element's name and street, as the app showed it
create index if not exists pins_flaw on public.pins (day) where flaw is not null and closed is null;

-- The existing pin rules already cover this: anyone logged in reads, adds and updates pins.
-- Ask PostgREST to see the new columns right away.
notify pgrst, 'reload schema';
