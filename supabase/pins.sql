-- 📌 Pins (2026-10-15, Captain asked): a spot in a task that anyone puts a note or photo on, so the crew and the
-- koordinatorer can talk about it, also where the kommune has no element. Run once in the Supabase SQL editor.
-- The conversation itself is in element_log, with element_id 'pin:<pin id>' (and 'opgave:<task id>' for the whole task),
-- so it uses the rules and photo storage that are already there.
create table public.pins (
  id uuid primary key default gen_random_uuid(),
  task_id text not null,
  x double precision not null,   -- EPSG:25832, like everything else in the app
  y double precision not null,
  title text,                    -- the start of the first note
  worker text,
  day date not null default current_date,
  closed date                    -- set by "✓ Klaret, fjern pinnen"; the notes stay
);
create index pins_task on public.pins (task_id) where closed is null;
alter table public.pins enable row level security;
create policy "pins read" on public.pins for select to authenticated using (public.hk_role() is not null);
create policy "pins add" on public.pins for insert to authenticated with check (public.hk_role() is not null and closed is null);
create policy "pins close" on public.pins for update to authenticated using (public.hk_role() is not null);
grant select, insert, update on public.pins to authenticated;
alter publication supabase_realtime add table public.pins;
