-- Part of a long element done (a stretch of hedge, path or kerb).
-- progress.parts: [{day, p:[[x,y],...], r, m}] in EPSG:25832, set on the phone when a worker taps
-- where they started and stopped. Lines: the stretch along the line between the taps. Areas: within r metres of the taps.
-- element_log.part: {m, of, u:"m"|"m2"} for each newly marked stretch, shown in Historik.
alter table public.progress add column if not exists parts jsonb;
alter table public.progress_trash add column if not exists parts jsonb;
alter table public.element_log add column if not exists part jsonb;
comment on column public.progress.parts is 'Stretches done on a long element: [{day, p:[[x,y],...], r (areas), m (size)}], EPSG:25832.';
comment on column public.element_log.part is 'A stretch marked done that day: {m, of, u: m | m2}.';

-- The trash trigger copied old.* by position; with the new column it must name the columns.
create or replace function public.progress_to_trash()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  insert into public.progress_trash (task_id, element_id, status, note, worker, updated_at, reason, parts, deleted_at)
    values (old.task_id, old.element_id, old.status, old.note, old.worker, old.updated_at, old.reason, old.parts, now());
  delete from public.progress_trash where deleted_at < now() - interval '14 days';
  return old;
end $function$;
