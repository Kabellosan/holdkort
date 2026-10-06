# Holdkort: handoff notes

Read this first. It's the source of truth for decisions made so far; the README is the user-facing guide.

## What it is
A phone web app for Captain's idverde crew (Ikast-Brande Kommune contract). Bosses create tasks ("all HA3 Pur in Brande"), assign them to people, and the crew marks each kommune element **Mangler / I gang / Færdig / Blokeret**. Replaces calling each other to say where you've been.

- Live: https://kabellosan.github.io/holdkort/ (GitHub Pages, branch `main`, repo root)
- Repo: `Kabellosan/holdkort`. Everything is in `index.html` (one file, OpenLayers 10 + proj4 + supabase-js from jsDelivr), `sw.js`, `manifest.json`.
- UI language: **Danish**. README and these notes: English.

## Data sources (all verified working from the browser, CORS ok)
- **Elements (WFS, GeoServer):** `https://kort.ikast-brande.dk/wfs/entreprenoer_udbud/ows` (NOT `/geoserver/...`, that 404s).
  - Layers: `element_arealer_distribution` (most area types incl. HA3 Pur, FB2a Fortov, GR*), `element_arealer_vej_sti_distribution`, `element_linier_distribution`, `element_punkter_distribution`, `element_kantsten_distribution`, `element_vej_sti_distribution` (roads, has `vejnavn`). `element_bro_tunnel_distribution` has no `elementkode` and errors.
  - Filter field `elementkode`; geometry column `wkb_geometry`; stable id `ogc_fid`. CRS EPSG:25832.
  - Pur and fortov have no street name; the app borrows the nearest road's `vejnavn`.
  - Code → name list is in `CODES` in `index.html` (from the WMS capabilities titles).
  - Per-type "definition of done" and safety requirements are in `REQS` in `index.html` (`{done:[], safety:[]}` per code), shown in a folded "Krav og sikkerhed" section in the element panel. Hidden for types with nothing filled in. Empty until the user supplies their requirements PDF; never invent requirements.
- **Aerial photo (WMS, MapServer):** `https://kort.ikast-brande.dk/wms`, `SERVICENAME=entreprenoer_udbud`, layer `theme-ortofoto2024`. `theme-orto_foraar_daf` (from the kommune's own map link) does NOT exist in this service.
- **Place search:** Photon (photon.komoot.io) while typing; Nominatim only on Enter / "Søg grundigere" (its usage policy forbids autocomplete). Typing "… station" adds a Photon `osm_tag=railway:station` query. **DAWA is shut down (HTTP 410).**
- The kommune's `robots.txt` is `Disallow: /`. Therefore: **no nightly server job / scraper** without the kommune's written OK. Phones fetch only when a person opens a task.

## Load on the kommune's server
- Element data per task is stored on the phone (Cache API `elements-v1`); refreshed at most once a day, random 15 s–3 min delay, never 06:00–09:00. "Opdater" forces it.
- Aerial tiles: fixed 256 px grid in EPSG:25832, service worker cache-first, 180 days.
- A task only auto-zooms the first time it's opened; map position is remembered.
- Task areas: a rectangle (`extent` only, `area` null) or a freehand polygon (`area` = GeoJSON Polygon in EPSG:25832, `extent` = its bounding box). The WFS request uses the bbox; elements are cut to the polygon on the phone (`hitsArea`). Max bbox 60 km². If the `area` column is missing, saves fall back to the rectangle. Stored element data carries an area key, so redrawing a task re-downloads it.
- Overblik (boss): one type for the whole kommune via `elementkode IN (...)` with no bbox, cached as `type:<code>` with the same once-a-day rules. Status per element comes from the tasks covering it (done > blocked > doing > todo); purple = in no task. Each task area gets an outline colour from `TASK_COLORS` (by created_at order, avoiding the status colours), shown as a stripe in the task list; tapping a task focuses it.

## Backend: Supabase
- Project `rvfwmmctqndfqvbuuoyi` (org "Kabellosan's Org", region eu-west-1), connected via the Supabase connector.
- Publishable key is in `index.html` (public by design). Never put the service_role key in the repo.
- Tables: `tasks` (id, name, codes[], extent, assignees[], created_by, created_at, archived, summary, area), `progress` (task_id, element_id, status todo|doing|done|blocked, note, reason (only for blocked: Bil parkeret / Vejarbejde / Andet), worker, updated_at; PK task_id+element_id), `people` (name, role).
- Trigger `progress_day_only` truncates `updated_at` to the day **in the database**.
- RLS (anon): read/insert/update on all three; delete on `progress` only when its task is archived; no deletes on tasks/people.
- Realtime on `tasks` and `progress`.
- `element_log` (id, element_id, code, task_id, day, done, status, reason, note, photo): append-only per-element log with `worker` name (user chose "names for bosses" on 2026-10-06; Historik shows names only to bosses), survives archiving. Written on Send for every status change (status/reason; `done` = newly done, feeds last_tended), a new note, or a photo; if the status/reason/worker columns are missing it falls back to the old done/note/photo lines; un-doing within a day deletes that task's done line (RLS allows delete only for day >= yesterday, insert only for today ± 1). View `last_tended` (element_id, code, last_day; security_invoker) feeds "Sidst passet" in the element pane/list (RECENT = 14 days warning) and Overblik's "Sidst passet" mode (AGES buckets). SQL in `supabase/element_log.sql`.
- Storage bucket `photos` (public, jpeg ≤ 3 MB, insert-only for anon). Photos are re-encoded on the phone via canvas (strips EXIF/GPS), kept in Cache API `photos-v1` with the pending mark until Send, path `<day>/<uuid>.jpg`.
- Pending rows carry `_was`, `_note0`, `_code`, `_photos` for the log; anything starting with `_` is stripped before the `progress` upsert.

## Decisions the user made (don't undo without asking)
- **Individual elements**, multi-select by tapping more elements. An earlier auto-grouping into "stops" was rejected.
- **Login = name + shared code**, roles crew/boss. Codes are SHA-256 hashes in `index.html` (`CREW_CODE_SHA`, `BOSS_CODE_SHA`); placeholders `hold` / `chef`. Trust-based, not real security.
- **Privacy:** the worker decides when data is sent (outbox + "Send"; auto-send is opt-in). GPS never leaves the phone. Only the day is stored/shown. Bosses see progress, not who did what, in the task views; but the `element_log` history shows bosses who made each change (user's choice, 2026-10-06). Closing a task deletes all its marks; only `summary {done,total}` and `element_log` (day, task, status, worker, note, photo per element) remain. A "Hvad deles?" screen explains this in Danish.
- Assigned names match case- and whitespace-insensitively.
- **Task visibility:** crew sees only tasks assigned to them by name or to everyone (empty `assignees`); bosses see all, plus a "Holdet" tab (per-person cards from `people` crew + assignee names). App-level only: with the shared anon key and name login, RLS cannot tell users apart. A firm version needs per-person Supabase Auth and RLS on `tasks`/`progress` by user id.

## Open items
- Real login codes (user to choose).
- Test leftovers in `people`: "Test Cache", "Test Chef" (deletion was cancelled at the confirm prompt; ask before deleting). One archived test task in `tasks`.
- User should reset the Supabase database password (it was posted in chat; the app doesn't use it).
- Suggested: email the kommune's GIS team for OK to do a nightly shared download; show the privacy design to the tillidsrepræsentant before rollout.
- Later: Supabase email login if it becomes an official tool.

## How to test
- Use the Claude desktop browser pane at mobile size (375×812) on the live URL.
- For tests that shouldn't touch the shared database, build a task object in JS and call `openTask(t)` without `saveTask`. If you do write to Supabase, prefix ids with `test-` and clean up afterwards (with the user's OK).
- After each push, GitHub Pages needs ~60–70 s. Bump `?v=` on the URL to bypass caches.
