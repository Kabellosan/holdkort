-- Deleting photos (2026-10-15). Run once in the Supabase SQL editor.
-- Already allowed without this file: anyone logged in deletes a log line from today or yesterday ("log undo").
-- This adds: a koordinator may remove any photo, also older ones; a line that also holds a status change
-- (photos sent before 2026-10-15) keeps the status and only loses the photo; and the photo file itself can be deleted.

create policy "log photo remove" on public.element_log for delete to authenticated
  using (public.hk_role() = 'boss' and photo is not null);

grant update (photo) on public.element_log to authenticated;
create policy "log photo clear" on public.element_log for update to authenticated
  using (photo is not null and (public.hk_role() = 'boss' or day >= current_date - 1))
  with check (photo is null);

-- The file in the photos bucket (its path starts with the day it was sent: <day>/<uuid>.jpg)
create policy "photos see" on storage.objects for select to authenticated
  using (bucket_id = 'photos');
create policy "photos remove" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (public.hk_role() = 'boss' or split_part(name, '/', 1) >= (current_date - 1)::text));
