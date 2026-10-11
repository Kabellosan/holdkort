-- "Betroet" (trusted): a crew member who may create tasks, but only for themselves.
-- A boss sets it in Holdet (people.role = 'trusted'); they log in with the crew code as before.
alter table public.people drop constraint if exists people_role_check;
alter table public.people add constraint people_role_check check (role in ('crew', 'trusted', 'boss'));

-- The database checks every new task against the creator's role in people:
--   boss    -> anything
--   trusted -> assignees must be exactly themselves (no "Alle", nobody else)
--   crew / unknown name -> may not create tasks
-- And on later changes: created_by can't change, and a trusted member's task can't be handed to anyone else
-- (it may become empty, which is what happens when a boss takes the person off the team).
-- Names match like the app does: case-insensitive, extra spaces ignored.
-- Note: login is name + shared code, so this stops mistakes and old app versions, not someone typing a boss's name.
create or replace function public.task_creator_rule() returns trigger
language plpgsql set search_path = public as $$
declare
  me text := lower(regexp_replace(btrim(coalesce(new.created_by, '')), '\s+', ' ', 'g'));
  r text;
begin
  if tg_op = 'UPDATE' and new.created_by is distinct from old.created_by then
    raise exception 'Opgavens opretter kan ikke ændres';
  end if;
  select case when bool_or(role = 'boss' and removed is null) then 'boss'
              when bool_or(role = 'trusted' and removed is null) then 'trusted'
              else 'crew' end
    into r
    from public.people
   where lower(regexp_replace(btrim(name), '\s+', ' ', 'g')) = me;
  if r = 'boss' then return new; end if;
  if tg_op = 'INSERT' then
    if r <> 'trusted' then raise exception 'Du må ikke oprette opgaver. Spørg en chef.'; end if;
    if coalesce(cardinality(new.assignees), 0) = 0 then
      raise exception 'En betroet må kun lave opgaver til sig selv';
    end if;
  elsif new.assignees is not distinct from old.assignees or r <> 'trusted' then
    return new;
  end if;
  if exists (select 1 from unnest(coalesce(new.assignees, '{}')) a
              where lower(regexp_replace(btrim(a), '\s+', ' ', 'g')) <> me) then
    raise exception 'En betroet må kun lave opgaver til sig selv';
  end if;
  return new;
end $$;

drop trigger if exists task_creator_rule on public.tasks;
create trigger task_creator_rule before insert or update on public.tasks
  for each row execute function public.task_creator_rule();
