# Holdkort

Shared task map for the idverde crew in Ikast-Brande. The kommune's maintenance elements (pur, fortove, græs …) are loaded as individual shapes, and the crew marks each one **Mangler / I gang / Færdig / Blokeret**. Each worker decides when their marks are sent to the rest of the team.

## How it works on the job
1. **Boss creates a task:** taps **Ny opgave** and marks the area on the map, either as a **rectangle** (drag the corners or edges to resize, the middle to move) or **drawn freehand** with a finger (then drag the points to adjust). Then searches "pur", ticks *HA3 Pur*, picks who should do it (or Alle), taps **Opret**. A boss can redraw a task's area later with **▭ Område** inside the task.
2. **Crew opens the task:** every pur bed in that area shows up in red, and the top shows e.g. `0/47`.
3. **Næste ▸** jumps to the nearest location nobody has started, based on your GPS (which never leaves the phone).
4. Tap **Færdig** → it turns green on your phone. Press **Send** when you choose, and it turns green for everyone. **Send senere** tucks the unsent count into a small chip at the top; **Annuller** (tap twice) throws the unsent marks away. Setting an element back to what the team already sees is not counted as a change. Tap more elements on the map to mark several at once. **I gang** (yellow) tells the others you're on it, so Næste skips it for them. **🚧 Blokeret** is for when you can't finish (a parked car, road work …): pick a reason, add a note if you like. It shows dark with a 🚧 sign on the map and in Overblik, counts as not done, and Næste only offers it when nothing else is left.
   Under each element, a folded **Krav og sikkerhed** section shows when that type counts as done and what to watch out for (filled in per type code in `REQS` in `index.html`).
5. **Liste** shows everything nearest first, with notes like "kun nordsiden mangler".
6. When the job is done, tap **Afslut** on the task. Next season, make a new task and everything starts red again.

**Who sees which tasks:** the crew only sees tasks with their name on them, plus tasks for everyone ("Alle"). Bosses see every task, and the **Holdet** tab shows one card per person with the tasks they are on. There a boss can **+ Tilføj person** or **Fjern** someone (after a confirm screen): removing takes them off their tasks (a task left with nobody becomes "Alle", and the screen warns about it) and stops them logging in with the crew code; their history stays. Needs `supabase/people_removed.sql`. This is enforced by the app, not the database (see Login below).

**Overblik (bosses):** pick a type, e.g. *Pur*, to see every pur bed in the whole kommune. Beds inside a task show that task's status; purple ones aren't in any task yet. Each task's area has its own outline colour, matching the stripe next to it in the list, so overlapping tasks can be told apart. Tap a task in the list to zoom to it and fade the others; tap it again to show all. Tapping a bed lists every task it's in. **+ Ny opgave med pur** lets you draw a new task right around the purple ones, and while drawing it shows how many the area catches.

**Sidst passet (last tended):** every time an element is sent as **Færdig**, the app keeps a line in a log with the day, the task and who sent it (names are only shown to bosses). The log stays when the task is closed. So when a new task is opened, each element says e.g. *Sidst passet for 5 dage siden*, with a ⚠ when an element still marked Mangler was done in the last 14 days, and the list shows it too. Every other status change (Mangler, I gang, Blokeret with its reason) is logged the same way, so **Historik** on an element shows the whole trail with notes and photos. Tapping **Færdig** by mistake and setting it back the same day removes the line again.

**On a computer:** on screens 1024 px and wider (a laptop or office PC), the panel sits in a sidebar on the left and the map fills the rest, which makes planning tasks and checking Overblik easier for bosses. Freehand areas are drawn by holding the mouse button down. Phones look exactly as before.

**Photos:** **📷 Billede** on an element takes or picks a photo. It's shrunk on the phone (which also strips GPS and other hidden data) and waits in the outbox like any other change until **Send**.

**Overblik → Sidst passet:** colours every element of the type across the kommune by days since it was last done: green 0–7, light green 8–14, yellow 15–30, orange 31–60, red over 60, grey if it's not in the log yet. Tapping an element shows the day.

Sidewalks (`FB2a`) come split into stretches by street and station, so you can mark "Rosenstien 0–25" done without the whole street.

## Where the data comes from
- **Elements:** the kommune's open GeoServer, workspace `entreprenoer_udbud` (`element_arealer_distribution`, `element_arealer_vej_sti_distribution`, lines, points, curbs).
- **Aerial photo:** the kommune's WMS (`theme-ortofoto2024`).
- **Plain map:** OpenStreetMap tiles, shown paler so the status colours stand out. The "Luftfoto / Kort" switch under the zoom buttons picks one; each phone remembers its choice.

### Easy on the kommune's server
- Each task's elements are downloaded **once** and stored on the phone. Reopening a task is instant and costs the server nothing.
- Stored data is refreshed **at most once a day**, in the background, after a random 15 s – 3 min delay, and **never between 06:00 and 09:00**. **Opdater** in the task forces a refresh.
- Aerial photo tiles are stored on the phone for **180 days** (the 2024 photo doesn't change).
- **Overblik** downloads one type for the whole kommune (bosses only), stored on the phone and refreshed by the same once-a-day rule.
- The map remembers where you were; a task only zooms to its area the first time you open it.

The kommune's `robots.txt` asks automated programs not to use the site, so there is **no** nightly server job. With the kommune's OK, a nightly download shared by all phones would cut their load to one request a night.

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
  summary jsonb,
  area jsonb -- freehand task area (GeoJSON polygon, EPSG:25832); null = the rectangle in extent
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

**Tending log and photos:** run [`supabase/element_log.sql`](supabase/element_log.sql) as well. Until it's run, the app works as before and simply shows no "sidst passet".

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
