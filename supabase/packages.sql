-- Packages: named groups of element types a boss can pick when creating a task ("Fast belægning" = all FB types).
-- Anyone with the app can read them; bosses add, edit and delete them in the app (trust-based, like the rest).
create table if not exists public.packages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  codes text[] not null default '{}',
  created_by text,
  created_at timestamptz not null default now()
);
alter table public.packages enable row level security;
create policy "app read packages"   on public.packages for select to anon using (true);
create policy "app add packages"    on public.packages for insert to anon with check (true);
create policy "app edit packages"   on public.packages for update to anon using (true) with check (true);
create policy "app delete packages" on public.packages for delete to anon using (true);

-- Starter packages from the kommune's own code groups (FB = fast belægning, LB = løs belægning, HA = hæk og pur)
insert into public.packages (name, codes, created_by) values
  ('Fast belægning', '{FB1,FB1a,FB1b,FB1c,FB1j,FB2a,FB3a,FB3b}', 'Holdkort'),
  ('Løs belægning',  '{LB2,LB2a,LB2b,LB2c,LB3}', 'Holdkort'),
  ('Hæk og pur',     '{HA1,HA3,HA11,HA21}', 'Holdkort');

-- A task can be limited to hand-picked elements (ids like 'arealer:1234'); null = every element of its types in the area
alter table public.tasks add column if not exists elements text[];
comment on column public.tasks.elements is 'Hand-picked element ids (null = all elements of the task''s types in its area)';
