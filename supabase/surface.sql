-- Belægning on packages and tasks (2026-10-21). Run once in the Supabase SQL editor; it is safe to run again.
--
-- The kommune's tilbudsliste 16.3 a is stier, torve, pladser, anden fast belægning and heller (FB1a, FB1b, FB1c, FB1j)
-- plus fortove (FB2a) in beton or granit only: a fortov in asphalt isn't in it. A package can carry that rule, and a task made from it keeps it.
alter table public.packages add column if not exists surface text[];  -- {beton} = every type in it; {FB2a:beton} = that type only; null = no rule
alter table public.tasks add column if not exists surface jsonb;      -- {"FB2a": ["beton","granit"], …}; null = no rule

-- 16.3a: only the fortove must be beton or granit (Captain's Nørre Snede test showed stier, pladser and heller in any belægning)
update public.packages set surface = array['FB2a:beton','FB2a:granit'] where name = '16.3a';

notify pgrst, 'reload schema';
