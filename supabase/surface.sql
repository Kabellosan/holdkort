-- Belægning on packages and tasks (2026-10-21). Run once in the Supabase SQL editor; it is safe to run again.
--
-- The kommune's tilbudsliste 16.3 a is the paved types (FB1a, FB1b, FB1c, FB1j, FB2a) with beton or granit only:
-- a fortov in asphalt isn't in it. A package can carry that rule, and a task made from it keeps it.
alter table public.packages add column if not exists surface text[];  -- e.g. {beton,granit}; null = every belægning
alter table public.tasks add column if not exists surface jsonb;      -- {"FB2a": ["beton","granit"], …}; null = no rule

update public.packages set surface = array['beton','granit'] where name = '16.3a' and surface is null;

notify pgrst, 'reload schema';
