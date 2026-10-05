-- Tending log: one line each time an element is sent as done, or gets a note or photo.
-- Only the day and the task, never a worker's name. Kept when a task is closed.
create table public.element_log (
  id bigint generated always as identity primary key,
  element_id text not null,
  code text,
  task_id text,
  day date not null default current_date,
  done boolean not null default false,
  note text,
  photo text
);
create index element_log_element on public.element_log (element_id, day desc);
create index element_log_code on public.element_log (code) where done;
alter table public.element_log enable row level security;
create policy "log read" on public.element_log for select to anon, authenticated using (true);
create policy "log add" on public.element_log for insert to anon, authenticated
  with check (day between current_date - 1 and current_date + 1);
-- A mistaken "Færdig" can be taken back the same day (or the next, to cover time zones)
create policy "log undo" on public.element_log for delete to anon, authenticated
  using (day >= current_date - 1);
grant select, insert, delete on public.element_log to anon, authenticated;

-- Last day each element was done, for "sidst passet" and the overview colours
create view public.last_tended with (security_invoker = on) as
  select element_id, code, max(day) as last_day
  from public.element_log where done group by element_id, code;
grant select on public.last_tended to anon, authenticated;

-- Every status change gets a line (todo/doing/blocked/done), with the blocked reason
alter table public.element_log add column status text, add column reason text;

-- Photos: public bucket, jpegs up to 3 MB; the app can upload but not overwrite or delete
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 3145728, array['image/jpeg']);
create policy "photos add" on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'photos');
