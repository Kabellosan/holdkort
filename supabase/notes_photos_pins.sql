-- Notes, photos and pins (2026-10-15). Run once in the Supabase SQL editor; it is safe to run again.
-- Replaces photo_delete.sql and pins.sql (never run separately).
--
-- Already allowed before this file: anyone logged in deletes an element_log line from today or yesterday ("log undo").
-- This file adds:
--   * notes and photos can be changed (a note edited, or a note/photo taken off a line that also holds a status)
--     on lines from today or yesterday; a koordinator can take notes and photos off any line, and delete
--     any line that is only a note or a photo;
--   * "(rettet)" after an edited note;
--   * photo files can be deleted (own from today/yesterday, a koordinator's any time);
--   * 📌 pins in a task.

-- ---------- element_log: edit and delete notes and photos ----------
alter table public.element_log add column if not exists edited boolean not null default false;
grant update (note, photo, edited) on public.element_log to authenticated;

drop policy if exists "log photo clear" on public.element_log;
drop policy if exists "log recent change" on public.element_log;
create policy "log recent change" on public.element_log for update to authenticated
  using (public.hk_role() is not null and day >= current_date - 1)
  with check (public.hk_role() is not null and day >= current_date - 1);

drop policy if exists "log boss change" on public.element_log;
create policy "log boss change" on public.element_log for update to authenticated
  using (public.hk_role() = 'boss')
  with check (public.hk_role() = 'boss');

drop policy if exists "log photo remove" on public.element_log;
drop policy if exists "log boss remove" on public.element_log;
create policy "log boss remove" on public.element_log for delete to authenticated
  using (public.hk_role() = 'boss' and status is null and done = false);

-- ---------- photo files ----------
drop policy if exists "photos see" on storage.objects;
create policy "photos see" on storage.objects for select to authenticated
  using (bucket_id = 'photos');
drop policy if exists "photos remove" on storage.objects;
create policy "photos remove" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (public.hk_role() = 'boss' or split_part(name, '/', 1) >= (current_date - 1)::text));

-- ---------- 📌 pins ----------
-- A spot in a task that anyone puts a note or photo on, also where the kommune has no element.
-- The conversation is in element_log with element_id 'pin:<pin id>' (and 'opgave:<task id>' for the whole task).
create table if not exists public.pins (
  id uuid primary key default gen_random_uuid(),
  task_id text not null,
  x double precision not null,   -- EPSG:25832, like everything else in the app
  y double precision not null,
  title text,                    -- the start of the first note
  worker text,
  day date not null default current_date,
  closed date                    -- set by "✓ Klaret, fjern pinnen"; the notes stay
);
create index if not exists pins_task on public.pins (task_id) where closed is null;
alter table public.pins enable row level security;
drop policy if exists "pins read" on public.pins;
create policy "pins read" on public.pins for select to authenticated using (public.hk_role() is not null);
drop policy if exists "pins add" on public.pins;
create policy "pins add" on public.pins for insert to authenticated with check (public.hk_role() is not null and closed is null);
drop policy if exists "pins close" on public.pins;
create policy "pins close" on public.pins for update to authenticated using (public.hk_role() is not null);
grant select, insert, update on public.pins to authenticated;
do $$ begin
  alter publication supabase_realtime add table public.pins;
exception when duplicate_object then null;
end $$;
