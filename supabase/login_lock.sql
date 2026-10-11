-- Run only after login.sql, after the three accounts exist and the new app (Supabase login) is live.
-- Locks out everyone without a login: the public key alone can no longer read or change anything.
drop policy if exists "app read tasks" on public.tasks;
drop policy if exists "app add tasks" on public.tasks;
drop policy if exists "app edit tasks" on public.tasks;
drop policy if exists "app read people" on public.people;
drop policy if exists "app add people" on public.people;
drop policy if exists "app edit people" on public.people;
drop policy if exists "app read marks" on public.progress;
drop policy if exists "app add marks" on public.progress;
drop policy if exists "app edit marks" on public.progress;
drop policy if exists "app clear marks" on public.progress;
drop policy if exists "app read packages" on public.packages;
drop policy if exists "app add packages" on public.packages;
drop policy if exists "app edit packages" on public.packages;
drop policy if exists "app delete packages" on public.packages;
alter policy "log read" on public.element_log to authenticated using (public.hk_role() is not null);
alter policy "log add" on public.element_log to authenticated
  with check (public.hk_role() is not null and day >= current_date - 1 and day <= current_date + 1);
alter policy "log undo" on public.element_log to authenticated using (public.hk_role() is not null and day >= current_date - 1);
alter policy "photos add" on storage.objects to authenticated;
