# Holdkort

Shared task map for the idverde crew in Ikast-Brande. The kommune's maintenance elements (pur, fortove, græs …) are loaded as individual shapes, and the crew marks each one **Mangler / I gang / Færdig**. Each worker decides when their marks are sent to the rest of the team.

## How it works on the job
1. **Boss creates a task:** zooms the map to Brande, taps **Ny opgave**, searches "pur", ticks *HA3 Pur*, picks who should do it (or Alle), taps **Opret**. The task covers the area on screen.
2. **Crew opens the task:** every pur bed in that area shows up in red, and the top shows e.g. `0/47`.
3. **Næste ▸** jumps to the nearest location nobody has started, based on your GPS (which never leaves the phone).
4. Tap **Færdig** → it turns green on your phone. Press **Send** when you choose, and it turns green for everyone. Tap more elements on the map to mark several at once. **I gang** (yellow) tells the others you're on it, so Næste skips it for them.
5. **Liste** shows everything nearest first, with notes like "kun nordsiden mangler".
6. When the job is done, tap **Afslut** on the task. Next season, make a new task and everything starts red again.

Sidewalks (`FB2a`) come split into stretches by street and station, so you can mark "Rosenstien 0–25" done without the whole street.

## Where the data comes from
- **Elements:** the kommune's open GeoServer, workspace `entreprenoer_udbud` (`element_arealer_distribution`, `element_arealer_vej_sti_distribution`, lines, points, curbs). Fetched fresh when a task opens and saved on the phone for offline use.
- **Aerial photo:** the kommune's WMS (`theme-ortofoto2024`), cached on the phone for 30 days.

## 1. Put it online — GitHub Pages (free)
1. New repo, e.g. `Kabellosan/holdkort`. Upload `index.html`, `sw.js`, `manifest.json`.
2. Settings → Pages → Deploy from branch → `main` / root.
3. On the phone, open `https://kabellosan.github.io/holdkort/` → Share → **Føj til hjemmeskærm**. Allow location when asked.

## 2. Share with the crew — Supabase (free)
**Connected:** project `rvfwmmctqndfqvbuuoyi` (EU, Ireland). The database stores only the day a mark was sent (a trigger strips the time), and marks can only be deleted once their task is closed. The steps below are for setting it up again from scratch.

1. Create a project at supabase.com.
2. SQL Editor → run:

```sql
create table tasks (
  id text primary key,
  name text not null,
  codes text[] not null,
  extent jsonb not null,
  assignees text[] default '{}',
  created_by text default '',
  created_at timestamptz default now(),
  archived boolean default false,
  summary jsonb
);
create table progress (
  task_id text references tasks(id) on delete cascade,
  element_id text not null,
  status text not null default 'todo',
  note text default '',
  worker text default '',
  updated_at timestamptz default now(),
  primary key (task_id, element_id)
);
create table people (
  name text primary key,
  role text not null default 'crew'
);
alter table tasks enable row level security;
alter table progress enable row level security;
alter table people enable row level security;
create policy "crew" on tasks for all using (true) with check (true);
create policy "crew" on progress for all using (true) with check (true);
create policy "crew" on people for all using (true) with check (true);
alter publication supabase_realtime add table tasks, progress;
```

3. Project Settings → API → copy **Project URL** and the **anon public** key into the top of `index.html` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`). The dot turns green.

## Logins and roles
- Everyone logs in once with **name + code**. The crew code gives the crew view; the boss code also lets you create, assign and close tasks.
- Codes are stored as SHA-256 hashes at the top of `index.html` (`CREW_CODE_SHA`, `BOSS_CODE_SHA`). Placeholder codes are `hold` and `chef`. Change them before real use.
- This login is trust-based: anyone with the anon key could read the database directly. Fine for a crew that trusts each other; switch to Supabase email login before it becomes an official tool.

## Privacy by design
- **GPS never leaves the phone.** It's only used to find the nearest element.
- **Nothing is sent until the worker presses Send.** "Send automatisk" is opt-in per person.
- **Only the send day is shown,** never clock times per mark. No routes, no positions, no per-person statistics.
- **Bosses see progress, not people:** the app hides who marked what from the boss view.
- **Closing a task deletes all its marks.** Only "done X of Y" is kept in `tasks.summary`.

In Denmark, new forms of workplace control generally have to be announced to employees in advance, and anything tied to names falls under GDPR. Worth showing this to your tillidsrepræsentant before rolling it out.

## If "Kunne ikke hente elementer fra kommunen" shows up
Two likely causes:
- **Wrong address.** `WFS_URL` at the top of `index.html` is `https://kort.ikast-brande.dk/wfs/entreprenoer_udbud/ows`. If the kommune moves its GeoServer, update it there.
- **The kommune's server is down or changed its rules.** If it starts blocking apps on other sites (CORS), a small relay through a Supabase Edge Function can fix it.
