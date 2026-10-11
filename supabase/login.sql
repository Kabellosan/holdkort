-- Login codes checked by the database (Supabase Auth), not by the public app code.
--
-- Three shared accounts, one per role. The password IS the login code (lowercase, at least 6 characters).
-- Create them in the Supabase dashboard: Authentication > Users > Add user > Create new user,
-- tick "Auto Confirm User". Then turn off sign-ups: Authentication > Sign In / Providers >
-- "Allow new users to sign up" off.
--   koordinator@holdkort.example   (Koordinator)
--   udfoerende@holdkort.example    (Udførende)
--   hjaelper@holdkort.example      (Hjælper)
-- .example is a reserved domain: no e-mail can ever be sent to or received for these addresses.

-- ===== Step 1: who is logged in =====
create or replace function public.hk_role() returns text
language sql stable set search_path = '' as $$
  select case auth.jwt()->>'email'
    when 'koordinator@holdkort.example' then 'boss'
    when 'udfoerende@holdkort.example' then 'crew'
    when 'hjaelper@holdkort.example' then 'crew'
  end
$$;

-- ===== Step 2: rules for logged-in phones =====
-- Everyone logged in reads everything and marks progress. Only Koordinator creates, edits and
-- closes tasks, removes people and edits packages.
create policy "login read tasks" on public.tasks for select to authenticated using (public.hk_role() is not null);
create policy "boss add tasks" on public.tasks for insert to authenticated with check (public.hk_role() = 'boss');
create policy "boss edit tasks" on public.tasks for update to authenticated using (public.hk_role() = 'boss') with check (public.hk_role() = 'boss');

create policy "login read people" on public.people for select to authenticated using (public.hk_role() is not null);
create policy "login add people" on public.people for insert to authenticated
  with check (public.hk_role() = 'boss' or (public.hk_role() = 'crew' and role = 'crew' and removed is null));
create policy "login edit people" on public.people for update to authenticated
  using (public.hk_role() = 'boss' or (public.hk_role() = 'crew' and role = 'crew' and removed is null))
  with check (public.hk_role() = 'boss' or (public.hk_role() = 'crew' and role = 'crew' and removed is null));

create policy "login read marks" on public.progress for select to authenticated using (public.hk_role() is not null);
create policy "login add marks" on public.progress for insert to authenticated with check (public.hk_role() is not null);
create policy "login edit marks" on public.progress for update to authenticated using (public.hk_role() is not null) with check (public.hk_role() is not null);
create policy "boss clear marks" on public.progress for delete to authenticated
  using (public.hk_role() = 'boss' and (select t.archived from public.tasks t where t.id = progress.task_id));

create policy "login read packages" on public.packages for select to authenticated using (public.hk_role() is not null);
create policy "boss add packages" on public.packages for insert to authenticated with check (public.hk_role() = 'boss');
create policy "boss edit packages" on public.packages for update to authenticated using (public.hk_role() = 'boss') with check (public.hk_role() = 'boss');
create policy "boss delete packages" on public.packages for delete to authenticated using (public.hk_role() = 'boss');

-- ===== Step 3: a safety net for closed tasks =====
-- Marks deleted when a task is closed are kept out of sight for 14 days, so a mistake (or vandalism)
-- can be undone. Nobody can read this table through the app; only the dashboard can.
create table if not exists public.progress_trash (like public.progress);
alter table public.progress_trash add column if not exists deleted_at timestamptz not null default now();
alter table public.progress_trash enable row level security;

create or replace function public.progress_to_trash() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.progress_trash select old.*, now();
  delete from public.progress_trash where deleted_at < now() - interval '14 days';
  return old;
end $$;
drop trigger if exists progress_to_trash on public.progress;
create trigger progress_to_trash before delete on public.progress for each row execute function public.progress_to_trash();

-- To reopen a closed task with its marks (replace the id):
--   update public.tasks set archived = false, summary = null where id = 'TASK-ID';
--   insert into public.progress (task_id, element_id, status, note, reason, worker, updated_at)
--     select task_id, element_id, status, note, reason, worker, updated_at from public.progress_trash where task_id = 'TASK-ID'
--     on conflict do nothing;

