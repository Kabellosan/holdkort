-- Belægning on packages and tasks (2026-10-21). Run once in the Supabase SQL editor; it is safe to run again.
--
-- The kommune's tilbudsliste 16.3 a is stier, torve, pladser, anden fast belægning and heller (FB1a, FB1b, FB1c, FB1j)
-- plus fortove (FB2a) in beton or granit only: a fortov in asphalt isn't in it. A package can carry that rule, and a task made from it keeps it.
alter table public.packages add column if not exists surface text[];  -- {beton} = every type in it; {FB2a:beton} = that type only; {!asfalt} = anything but asfalt; null = no rule
alter table public.tasks add column if not exists surface jsonb;      -- {"FB2a": ["beton","granit"], …}; null = no rule

-- 16.3a: everything but asfalt (Captain's tests in Nørre Snede and Isenvad, 2026-10-21)
update public.packages set surface = array['!asfalt'] where name = '16.3a';

notify pgrst, 'reload schema';
