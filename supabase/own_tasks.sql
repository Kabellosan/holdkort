-- Udførende may create tasks for themselves only, and change or close the tasks they made.
-- Run after login.sql and login_lock.sql. Koordinator keeps every other right; Hjælper can't create tasks.

-- Hjælper gets its own role name, so the database can tell it from Udførende
create or replace function public.hk_role() returns text
language sql stable set search_path = '' as $$
  select case auth.jwt()->>'email'
    when 'koordinator@holdkort.example' then 'boss'
    when 'udfoerende@holdkort.example' then 'crew'
    when 'hjaelper@holdkort.example' then 'helper'
  end
$$;

drop policy if exists "login add people" on public.people;
drop policy if exists "login edit people" on public.people;
create policy "login add people" on public.people for insert to authenticated
  with check (public.hk_role() = 'boss' or (public.hk_role() in ('crew','helper') and role = 'crew' and removed is null));
create policy "login edit people" on public.people for update to authenticated
  using (public.hk_role() = 'boss' or (public.hk_role() in ('crew','helper') and role = 'crew' and removed is null))
  with check (public.hk_role() = 'boss' or (public.hk_role() in ('crew','helper') and role = 'crew' and removed is null));

-- Marks a task made with the Udførende login. Set by the database, never by the phone, and never changed.
alter table public.tasks add column if not exists made_by_crew boolean not null default false;
create or replace function public.tasks_made_by() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then new.made_by_crew := coalesce(public.hk_role() = 'crew', false);
  else new.made_by_crew := old.made_by_crew; end if;
  return new;
end $$;
drop trigger if exists tasks_made_by on public.tasks;
create trigger tasks_made_by before insert or update on public.tasks for each row execute function public.tasks_made_by();

-- Only for yourself: exactly one person on the task, and it's the one who made it
create or replace function public.hk_self_task(assignees text[], created_by text) returns boolean
language sql immutable set search_path = '' as $$
  select coalesce(cardinality(assignees) = 1 and lower(btrim(assignees[1])) = lower(btrim(created_by)), false)
$$;

create policy "crew add own tasks" on public.tasks for insert to authenticated
  with check (public.hk_role() = 'crew' and public.hk_self_task(assignees, created_by));
create policy "crew edit own tasks" on public.tasks for update to authenticated
  using (public.hk_role() = 'crew' and made_by_crew)
  with check (public.hk_role() = 'crew' and made_by_crew and public.hk_self_task(assignees, created_by));
create policy "crew clear own marks" on public.progress for delete to authenticated
  using (public.hk_role() = 'crew' and (select t.archived and t.made_by_crew from public.tasks t where t.id = progress.task_id));
