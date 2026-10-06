-- Bosses can take someone off the team. The row is kept (no deletes on people),
-- so names in element_log / Historik stay. removed = the day it happened, null = on the team.
alter table public.people add column if not exists removed date;
comment on column public.people.removed is 'Day a boss took this person off the team (null = on the team). The row is kept so history names stay.';
