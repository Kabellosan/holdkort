-- Anonymous beta (2026-10-29): the whole schema for the separate Supabase project "Holdkort beta anonym"
-- (lkctygsamscansymqjcn), used by /beta/. Never run this on the real project.
--
-- Same tables and columns as the real app, so the app code works unchanged, but the database keeps no names:
-- triggers blank every name column (worker, created_by, assignees, saved_by), `people` takes no rows and there is
-- no photo bucket. Data is what, where and which day only.
--
-- Two shared accounts, the password is the login code (create them in Authentication > Users, "Auto Confirm User",
-- then turn off "Allow new users to sign up"):
--   koordinator@holdkort.example   (Koordinator)
--   udfoerende@holdkort.example    (Udførende)
-- There is no Hjælper here: that role sees only tasks with its own name.

-- ---------- who is logged in ----------
create or replace function public.hk_role() returns text
language sql stable set search_path = '' as $$
  select case auth.jwt()->>'email'
    when 'koordinator@holdkort.example' then 'boss'
    when 'udfoerende@holdkort.example' then 'crew'
  end
$$;

-- ---------- tables ----------
create table public.tasks (
  id text primary key, name text not null, codes text[] not null, extent jsonb not null,
  assignees text[] not null default '{}', created_by text not null default '', created_at timestamptz not null default now(),
  archived boolean not null default false, summary jsonb, area jsonb, elements text[],
  made_by_crew boolean not null default false, spots jsonb, surface jsonb
);
create table public.progress (
  task_id text not null references public.tasks(id) on delete cascade, element_id text not null,
  status text not null default 'todo' check (status in ('todo','doing','done','blocked')),
  note text not null default '', worker text not null default '', updated_at timestamptz not null default now(),
  reason text, parts jsonb, primary key (task_id, element_id)
);
create table public.progress_trash (
  task_id text not null, element_id text not null, status text not null, note text not null, worker text not null,
  updated_at timestamptz not null, reason text, deleted_at timestamptz not null default now(), parts jsonb
);
create table public.people (name text primary key, role text not null default 'crew' check (role in ('crew','boss')), removed date);
create table public.packages (
  id uuid primary key default gen_random_uuid(), name text not null, codes text[] not null default '{}',
  created_by text, created_at timestamptz not null default now(), surface text[]
);
create table public.element_log (
  id bigint generated always as identity primary key, element_id text not null, code text, task_id text,
  day date not null default current_date, done boolean not null default false, note text, photo text,
  status text, reason text, worker text, part jsonb, edited boolean not null default false
);
create index element_log_element on public.element_log (element_id, day desc);
create index element_log_code on public.element_log (code) where done;
create table public.pins (
  id uuid primary key default gen_random_uuid(), task_id text, x double precision not null, y double precision not null,
  title text, worker text, day date not null default current_date, closed date,
  flaw text, element text, code text, reported date, what text
);
create index pins_flaw on public.pins (day) where flaw is not null and closed is null;
create table public.tbl_lines (
  name text primary key, num text, title text, els jsonb not null default '[]', n integer not null default 0,
  saved_at timestamptz not null default now(), saved_by text
);
create view public.last_tended with (security_invoker = on) as
  select element_id, code, max(day) as last_day from public.element_log where done group by element_id, code;

-- ---------- no names: blank them on every write ----------
create or replace function public.anon_blank() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_table_name = 'tasks' then new.created_by := ''; new.assignees := '{}';
  elsif tg_table_name = 'progress' then new.worker := '';
  elsif tg_table_name in ('element_log','pins') then new.worker := null;
  elsif tg_table_name = 'packages' then new.created_by := null;
  elsif tg_table_name = 'tbl_lines' then new.saved_by := null;
  end if;
  if tg_table_name = 'element_log' then new.photo := null; end if;
  return new;
end $$;
create trigger anon_blank before insert or update on public.tasks for each row execute function public.anon_blank();
create trigger anon_blank before insert or update on public.progress for each row execute function public.anon_blank();
create trigger anon_blank before insert or update on public.element_log for each row execute function public.anon_blank();
create trigger anon_blank before insert or update on public.pins for each row execute function public.anon_blank();
create trigger anon_blank before insert or update on public.packages for each row execute function public.anon_blank();
create trigger anon_blank before insert or update on public.tbl_lines for each row execute function public.anon_blank();

-- ---------- the same helpers as the real app ----------
create or replace function public.progress_day_only() returns trigger
language plpgsql set search_path = '' as $$ begin new.updated_at := date_trunc('day', now()); return new; end $$;
create trigger progress_day_only before insert or update on public.progress for each row execute function public.progress_day_only();

create or replace function public.progress_to_trash() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.progress_trash (task_id, element_id, status, note, worker, updated_at, reason, parts, deleted_at)
    values (old.task_id, old.element_id, old.status, old.note, old.worker, old.updated_at, old.reason, old.parts, now());
  delete from public.progress_trash where deleted_at < now() - interval '14 days';
  return old;
end $$;
create trigger progress_to_trash before delete on public.progress for each row execute function public.progress_to_trash();

create or replace function public.tasks_made_by() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then new.made_by_crew := coalesce(public.hk_role() = 'crew', false);
  else new.made_by_crew := old.made_by_crew; end if;
  return new;
end $$;
create trigger tasks_made_by before insert or update on public.tasks for each row execute function public.tasks_made_by();

-- ---------- rules: only the two logged-in accounts; anon (the public key alone) gets nothing ----------
alter table public.tasks enable row level security;
alter table public.progress enable row level security;
alter table public.progress_trash enable row level security;
alter table public.people enable row level security;
alter table public.packages enable row level security;
alter table public.element_log enable row level security;
alter table public.pins enable row level security;
alter table public.tbl_lines enable row level security;

create policy "login read tasks" on public.tasks for select to authenticated using (public.hk_role() is not null);
create policy "boss add tasks" on public.tasks for insert to authenticated with check (public.hk_role() = 'boss');
create policy "boss edit tasks" on public.tasks for update to authenticated using (public.hk_role() = 'boss') with check (public.hk_role() = 'boss');
-- Udførende make tasks for everyone (no names here) and change only those made with the Udførende code
create policy "crew add own tasks" on public.tasks for insert to authenticated with check (public.hk_role() = 'crew');
create policy "crew edit own tasks" on public.tasks for update to authenticated
  using (public.hk_role() = 'crew' and made_by_crew) with check (public.hk_role() = 'crew' and made_by_crew);

create policy "login read marks" on public.progress for select to authenticated using (public.hk_role() is not null);
create policy "login add marks" on public.progress for insert to authenticated with check (public.hk_role() is not null);
create policy "login edit marks" on public.progress for update to authenticated using (public.hk_role() is not null) with check (public.hk_role() is not null);
create policy "boss clear marks" on public.progress for delete to authenticated
  using (public.hk_role() = 'boss' and (select t.archived from public.tasks t where t.id = progress.task_id));
create policy "crew clear own marks" on public.progress for delete to authenticated
  using (public.hk_role() = 'crew' and (select t.archived and t.made_by_crew from public.tasks t where t.id = progress.task_id));

-- people: readable (always empty), no writes at all
create policy "login read people" on public.people for select to authenticated using (public.hk_role() is not null);

create policy "login read packages" on public.packages for select to authenticated using (public.hk_role() is not null);
create policy "boss add packages" on public.packages for insert to authenticated with check (public.hk_role() = 'boss');
create policy "boss edit packages" on public.packages for update to authenticated using (public.hk_role() = 'boss') with check (public.hk_role() = 'boss');
create policy "boss delete packages" on public.packages for delete to authenticated using (public.hk_role() = 'boss');

create policy "log read" on public.element_log for select to authenticated using (public.hk_role() is not null);
create policy "log add" on public.element_log for insert to authenticated
  with check (public.hk_role() is not null and day between current_date - 1 and current_date + 1);
create policy "log undo" on public.element_log for delete to authenticated using (public.hk_role() is not null and day >= current_date - 1);
create policy "log recent change" on public.element_log for update to authenticated
  using (public.hk_role() is not null and day >= current_date - 1) with check (public.hk_role() is not null and day >= current_date - 1);
create policy "log boss change" on public.element_log for update to authenticated using (public.hk_role() = 'boss') with check (public.hk_role() = 'boss');
create policy "log boss remove" on public.element_log for delete to authenticated
  using (public.hk_role() = 'boss' and status is null and done = false);

create policy "pins read" on public.pins for select to authenticated using (public.hk_role() is not null);
create policy "pins add" on public.pins for insert to authenticated with check (public.hk_role() is not null and closed is null);
create policy "pins close" on public.pins for update to authenticated using (public.hk_role() is not null);

create policy "login read tbl_lines" on public.tbl_lines for select to authenticated using (public.hk_role() is not null);
create policy "boss add tbl_lines" on public.tbl_lines for insert to authenticated with check (public.hk_role() = 'boss');
create policy "boss edit tbl_lines" on public.tbl_lines for update to authenticated using (public.hk_role() = 'boss') with check (public.hk_role() = 'boss');

grant select, insert, update, delete on public.tasks, public.progress, public.people, public.packages,
  public.element_log, public.pins, public.tbl_lines to authenticated;
grant select on public.last_tended to authenticated;
revoke all on public.tasks, public.progress, public.progress_trash, public.people, public.packages,
  public.element_log, public.pins, public.tbl_lines, public.last_tended from anon;

-- ---------- realtime ----------
alter publication supabase_realtime add table public.tasks, public.progress, public.pins;

-- ---------- the same starting packages as the real app (one per kommune map folder), copied 2026-10-29 ----------
insert into public.packages (name, codes, surface) values
('16.3a', '{FB1a,FB1b,FB1c,FB1j,FB2a}', '{!asfalt}'),
('Afvanding', '{VA3,VA3c,VA3d}', null),
('Bevoksning', '{SK2,SK3,SK5,SK6a,SK7}', null),
('Blomster', '{BL1,BL3,BL5}', null),
('Buske og hæk', '{BU1,BU1a,BU2,BU3,HA1,HA3,HA11,HA21}', null),
('Bygværker', '{BY1,BY2,BY2a,BY3,BY9}', null),
('Fast belægning', '{FB1,FB1a,FB1b,FB1c,FB1j,FB2a,FB3a,FB3b,GR7d}', null),
('Græs', '{GR2,GR3,GR4,GR6l,GR6m,GR6n,GR6o,GR7,GR7b,GR7c,GR9,GR20,GR30}', null),
('Hæk og pur', '{HA1,HA3,HA11,HA21}', null),
('Klatreplanter', '{KL2,KL3}', null),
('Løs belægning', '{LB2,LB2a,LB2b,LB2c,LB3}', null),
('Sport og leg', '{GR5b,GR5c,SB4a,SB4b,SB4e,SB4f,SB4g,SB4h,UD6}', null),
('Træer', '{TR1,TR2,TR3,TR4}', null);
