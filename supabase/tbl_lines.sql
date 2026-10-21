-- Tilbudsliste lines saved once for the whole kommune (2026-10-21). Run once in the Supabase SQL editor; safe to run again.
--
-- A koordinator's phone reads a line of the kommune's "Tilbudslisten, Grøn" from the old map (WMS as SVG), finds the
-- kommune elements under it and saves the list here, so new tasks and Overblik use it at once. Nothing runs by itself.
-- els: [{i: '<layer short>:<ogc_fid>', c: elementkode, b: [x0,y0,x1,y1] in EPSG:25832}]

create table if not exists public.tbl_lines (
  name text primary key,          -- the WMS layer name
  num text,                       -- "16.3 a"
  title text,
  els jsonb not null default '[]'::jsonb,
  n int not null default 0,       -- number of elements
  saved_at timestamptz not null default now(),
  saved_by text
);
alter table public.tbl_lines enable row level security;
drop policy if exists "login read tbl_lines" on public.tbl_lines;
drop policy if exists "boss add tbl_lines" on public.tbl_lines;
drop policy if exists "boss edit tbl_lines" on public.tbl_lines;
create policy "login read tbl_lines" on public.tbl_lines for select to authenticated using (true);
create policy "boss add tbl_lines" on public.tbl_lines for insert to authenticated with check (public.hk_role() = 'boss');
create policy "boss edit tbl_lines" on public.tbl_lines for update to authenticated using (public.hk_role() = 'boss') with check (public.hk_role() = 'boss');
notify pgrst, 'reload schema';
