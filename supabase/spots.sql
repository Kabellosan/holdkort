-- Tasks made by tapping the spots on the map ("Tryk på stederne"). Run once in the Supabase SQL editor.
-- spots holds what the phones need to fetch the picked elements again, in the order they were tapped:
--   a kommune element: {"id":"arealer:123", "code":"HA3", "box":[x0,y0,x1,y1], "street":"Storegade"}
--   a spot set by hand: {"id":"egen:<uuid>", "name":"Bed ved kirken", "xy":[x,y]}
-- Coordinates in EPSG:25832. null = an ordinary task with an area. tasks.elements still lists the ids.
alter table public.tasks add column if not exists spots jsonb;
notify pgrst, 'reload schema';
