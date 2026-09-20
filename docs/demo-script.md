# FlightDeck demo: the shot list

Twelve shots, about six and a half minutes. `frontend/e2e/demo.spec.ts` drives the portal through them
in this order, so recording is an execution rather than an improvisation: start the driver headed,
record the window, and follow.

The driver also writes a **timed script of the run** to `verification/demo-run.md` — every beat with
its `mm:ss` from the first visible frame, what was on screen, what was clicked and what the instance
answered — so the narration or the subtitles can be laid over the recording afterwards without
guessing at timings. It is written line by line as the run goes, so a run that dies halfway still
leaves the part that already played, and it is not committed: it is working material for whoever is
recording.

```bash
cd frontend && FD_DEMO=1 FLIGHTDECK_PORT=52780 npx playwright test --project=demo --headed
```

## The one rule this script exists to protect

**Nothing here is accelerated, stubbed, skipped or simulated.** The driver intercepts no request and
fakes no response; every wait you see is the instance's own. If a connection test takes ten seconds,
the shot takes ten seconds.

This is not fastidiousness. A demo that hides latency is discovered at the evaluator's first install,
and after that every other claim in the submission is doubted.

Two different times are involved, and confusing them is how a demo starts lying:

- **Work** — how long the portal actually took. Reported by the driver for every shot, never padded.
- **Minimum** — how long the shot stays on screen, so a viewer can read it. Holding a screen open is
  not hiding latency; shortening a wait would be, and nothing here does that.

What the driver *enforces* is that each shot genuinely drove the portal: it counts the requests the
shot made to the instance and **fails a shot that made none**, because that is a shot showing a
static page. One shot legitimately talks to nobody — the session trail is kept in the browser tab and
never reaches the instance, which is the thing that shot exists to show — and it is not exempted but
held to the opposite check: a shot that claims to be local and then calls the instance fails too. The timings it reports, and the total below, are what the author and a viewer compare
the finished recording against — a published video shorter than the sum of the minimums has been sped
up, which is the one thing this script forbids.

**Total on screen: 6 minutes 20 seconds**, plus whatever the instance's own work adds. A measured
run came to 6m 21s, with a 20.8 s pre-roll before the clock started.

## Why it opens where it opens

The contest checklist asks for the video to open on the instrument cluster and the dry-run, not on a
menu. The reason is worth stating: a navigation tour shows that an application has screens. The
cluster shows telemetry the portal reads for itself and draws at one-second resolution, and the
dry-run shows the one thing most management portals do not do at all — tell you what a change will
cost before you make it. Those two shots are the argument. The rest is evidence.

## The shots

| # | Shot | What it proves | Minimum |
|---|---|---|---|
| 1 | The instrument cluster, filling | Real telemetry, at one-second resolution, drawn on canvas; the window is this tab's and nothing is persisted | 45 s |
| 2 | <kbd>Ctrl</kbd>+<kbd>K</kbd>, `FD_Demo` | The portal is driven by name, not by menu; results are grouped by domain and open in place | 20 s |
| 3 | A deletion, rehearsed | The diff, the impact — who loses what — the typed confirmation, and **Cancel**: nothing is applied | 40 s |
| 4 | Safe mode, and the second tab | Read-only by default, per tab, enforced by the server rather than by the interface | 25 s |
| 5 | Web applications and the REST explorer | Exposure markers on every application; a real request executed in-process against this instance | 35 s |
| 6 | Permissions, followed as a graph | A privilege with the chain of roles that grants it, and the jump from role to the users who hold it | 30 s |
| 7 | Self-protection | The change that would leave no administrator, refused; the process running this session, refused; and a daemon whose control is disabled because the platform says so | 40 s |
| 8 | Security and secrets | Secrets set and replaced, never shown; the declined encryption writes with their reason | 25 s |
| 9 | Tasks, and the jump to logs | A failed run, and "open the logs of this period" arriving filtered and saying so | 30 s |
| 10 | The unified log stream | Five sources in one list, the original record behind a line, and a jump from an event to a process | 45 s |
| 11 | The session trail, exported | Everything the session proposed — applied, cancelled, blocked — kept in the tab and never on the instance | 25 s |
| 12 | The light theme | The same portal in light, with the same semantic palette: the state colours mean the same thing in both | 20 s |

### Shot 1 — The instrument cluster (45 s)

Open on `system/instruments`. Let it run. The series must be visibly filling, which takes time — that
is the shot. Say: the portal reads CPU and memory from the host and shared memory and disk from the
SysAdmin API, at one-second resolution, and keeps the window in the browser tab only.

Do not cut away early. An empty canvas is what this screen looks like in its first second, and it is
the one state this demo must not show.

### Shot 2 — The command palette (20 s)

<kbd>Ctrl</kbd>+<kbd>K</kbd>, type `FD_Demo`. Results appear grouped by domain — roles, resources, a
web application, tasks, a wallet collection. The driver reads the grouped results and closes the
palette with <kbd>Esc</kbd> without opening anything: the next shot opens the role, and opening it
twice would waste the minute.

### Shot 3 — A deletion, rehearsed (40 s)

The driver opens `FD_Demo_Operator` directly, turns off safe mode from the glareshield, and presses
**Delete** on the role. Say that safe mode applies to this tab alone. Read the rehearsal on screen:

- the fields that would change, current beside commanded;
- the impact: the users who would lose a privilege, named, and which privilege;
- the confirmation, which asks you to type the role's name because the change is destructive.

Then **Cancel**. The instance is untouched. **A cancelled rehearsal leaves no trail entry** — the
session trail records what was blocked and what was applied, and a change that was abandoned before
anything was sent is neither. Shot 11 shows the trail, and what is in it comes from shot 7.

### Shot 4 — Safe mode (25 s)

Open a second tab. It starts read-only, because safe mode is per tab and never remembered. Say that
the server rejects a change from a read-only tab before it reaches IRIS, so the guarantee does not
depend on the interface being honest.

### Shot 5 — Web applications and the REST explorer (35 s)

The web application list with its exposure markers — on a demo install `/csp/fd-demo` carries
"No authentication", which is why the install creates it. Then the REST explorer: the driver runs
`GET /api/flightdeck/v1/session/capabilities` against this instance and the panel shows the status
and the elapsed time. Say it is dispatched in-process and that the executor is not an outbound proxy.

### Shot 6 — Permissions as a graph (30 s)

Open `FD_Demo_Operator` and show a privilege with the chain of roles that grants it. The driver then
opens the account list, where disabled and expired accounts carry their markers. Say that a privilege
is never shown without its provenance.

### Shot 7 — Self-protection (40 s)

Three refusals, in order.

1. **The last administrator.** The driver disables every other counted administrator through the
   official API, edits the remaining one to clear `Enabled`, and the portal refuses: the change would
   leave the instance with no administrator. It names what it counted and what it could not see.
   Apply stays disabled. The accounts are re-enabled at the end of the shot.

   **Narrate this as what it is.** The instance really is reduced to one administrator for a few
   seconds and really is restored. Saying otherwise over a recording of it would be the one thing
   this script forbids.

2. **The process running this session.** The driver finds the process the instance reports as this
   session's and presses **Terminate**. The portal refuses: ending it would end the session
   mid-request.

   **This one is intermittent, and the reason is worth knowing.** This instance reports no CSP session
   on the process, so the rule matches on the process id — and IRIS serves consecutive requests from
   different processes, so the process that was the session's when the list was read may already have
   been replaced when the screen opens it. The refusal is real and fires on the request that meets
   it. When it does not land, the driver says so in the timed script and the ordinary confirmation
   appears instead. Use the alternative narration in `docs/demo-narration.md`.

3. **A process the platform will not let anyone end.** A daemon, whose **Terminate** is disabled with
   the instance's own answer beside it. Say that the schema carries what may be done to each object
   and the control follows it.

### Shot 8 — Security and secrets (25 s)

The wallet: a secret is set or replaced, never read back. Then the encryption section, where the
writes are disabled with their reason and the native path. Say this is a decision, recorded as
declined rather than missing.

### Shot 9 — Tasks, and the jump to logs (30 s)

The task list with each task's recent history. Open the demonstration task that fails on purpose,
open its failed run, and use "open the logs of this period". The stream opens filtered on that task
and window **and says so on screen**.

The driver asks the instance to run that task before the demo starts, and waits a short while for the
failure to be recorded. The instance's task manager decides when it actually runs, so if the failure
has not been recorded by then the shot shows the list and its history bands instead, and the driver
says so in its output and in the timed script. The demo never pretends to a failure the instance has
not had — which is the same rule as everything else here, applied to its own subject matter. Use the
alternative narration when that happens.

### Shot 10 — The unified log stream (45 s)

The five sources in one list under one schema, each saying how much it read. Point out a line whose
source states no level and therefore reads `unknown` rather than being guessed at. Open an event and
show the original record behind it. Then turn on live follow and let new lines arrive.

Close on this: it is the one mandatory axis of the brief with no official API coverage.

### Shot 11 — The session trail, exported (25 s)

Open the trail from the palette by name. What is in it is what this session proposed: the two
refusals from shot 7, each with its reason. Export it and show the file coming down. Say that secret
fields appear in the export as changed or unchanged and never as values, and that the trail lives in
this tab and never reaches the instance.

**This is the one shot that makes no request at all**, which is the thing it demonstrates. The driver
checks that it makes none.

### Shot 12 — The light theme (20 s)

Switch to light from the glareshield. The driver shows the instrument cluster and the log stream
again. Say that the state colours mean the same thing in both themes, and that colour is never the
only signal.

## What the author does

The driver does everything except record. The recording and its publication are the author's:

1. Start a fresh install so the instance looks like an evaluator's (`docker compose down -v && docker compose up -d`).
2. Run the driver headed and record that window. It opens at **1920×1080**, which the project's
   Playwright configuration sets for this project alone, so the screen has to be at least that for an
   uncropped capture.

   ```bash
   cd frontend
   FD_DEMO=1 npx playwright test --project=demo --headed
   ```

   Start the recording first. The timed script's clock begins at the first visible frame of the
   application, and the pre-roll before it — the instance running the failing task — took 20.8 s on a
   measured run. End to end the command takes about 6 minutes 45 seconds.
3. Publish, and put the link in the submission.

The narration to read over each shot, sized to its minimum, is in
[`demo-narration.md`](demo-narration.md).

Do not speed the recording up afterwards. That would undo the only rule this script has.
