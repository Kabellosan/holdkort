# Holdkort

Shared task map for the idverde crew in Ikast-Brande. The kommune's maintenance elements (pur, fortove, græs …) are loaded as individual shapes, and the crew marks each one **Mangler / I gang / Færdig**. Everyone sees the same progress live.

## How it works on the job
1. **Boss creates a task:** zooms the map to Brande, taps **Ny opgave**, searches "pur", ticks *HA3 Pur*, taps **Opret**. The task covers the area on screen.
2. **Crew opens the task:** every pur bed in that area shows up in red, and the top shows e.g. `0/47`.
3. **Næste ▸** jumps to the nearest location nobody has started, based on your GPS.
4. Tap **Færdig** → it turns green on everyone's phone, with your name and time. **I gang** (yellow) tells the others you're on it, so Næste skips it for them.
5. **Liste** shows everything nearest first, with notes like "kun nordsiden mangler".
6. When the job is done, tap **Afslut** on the task. Next season, make a new task and everything starts red again.

Sidewalks (`FB2a`) come split into stretches by street and station, so you can mark "Rosenstien 0–25" done without the whole street.

## Where the data comes from
- **Elements:** the kommune's open GeoServer, workspace `entreprenoer_udbud` (`element_arealer_distribution`, `element_arealer_vej_sti_distribution`, lines, points, curbs). Fetched fresh when a task opens and saved on the phone for offline use.
- **Aerial photo:** the kommune's WMS (`theme-orto_foraar_daf`), cached on the phone for 30 days. **Gem kort offline** pre-downloads the area on screen.

## 1. Put it online — GitHub Pages (free)
1. New repo, e.g. `Kabellosan/holdkort`. Upload `index.html`, `sw.js`, `manifest.json`.
2. Settings → Pages → Deploy from branch → `main` / root.
3. On the phone, open `https://kabellosan.github.io/holdkort/` → Share → **Føj til hjemmeskærm**. Allow location when asked.

## 2. Share with the crew — Supabase (free)
Without this, everything stays on one phone (red dot next to your name).

1. Create a project at supabase.com.
2. SQL Editor → run:

```sql
create table tasks (
  id uuid primary key,
  name text not null,
  codes text[] not null,
  extent jsonb not null,
  created_by text default '',
  created_at timestamptz default now(),
  archived boolean default false
);
create table progress (
  task_id uuid references tasks(id) on delete cascade,
  element_id text not null,
  status text not null default 'todo',
  note text default '',
  worker text default '',
  updated_at timestamptz default now(),
  primary key (task_id, element_id)
);
alter table tasks enable row level security;
alter table progress enable row level security;
create policy "crew" on tasks for all using (true) with check (true);
create policy "crew" on progress for all using (true) with check (true);
alter publication supabase_realtime add table tasks, progress;
```

3. Project Settings → API → copy **Project URL** and the **anon public** key into the top of `index.html` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`). Commit. The dot turns green.

These policies let anyone with the link edit. Fine for testing with the crew; add Supabase email login before it spreads further.

## If "Kunne ikke hente elementer fra kommunen" shows up
Two likely causes:
- **Wrong address.** `WFS_URL` at the top of `index.html` is `https://kort.ikast-brande.dk/geoserver/entreprenoer_udbud/ows`. Compare with the address bar when you open a GeoJSON from GeoServer's Layer Preview and fix it if it differs.
- **The server blocks browser apps from other sites (CORS).** Then the fix is a tiny relay, e.g. a free Supabase Edge Function that fetches from the kommune for the app. Ask Claude to add it.
