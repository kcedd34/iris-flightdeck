# FlightDeck demo: the shot list

Nine shots, about four and a half minutes. `frontend/e2e/demo.spec.ts` drives the portal through them
in this order, so recording is an execution rather than an improvisation: start the driver headed,
record the window, and follow.

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
static page. The timings it reports, and the total below, are what the author and a viewer compare
the finished recording against — a published video shorter than the sum of the minimums has been sped
up, which is the one thing this script forbids.

**Total on screen: 4 minutes 55 seconds**, plus whatever the instance's own work adds.

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
| 7 | Security and secrets | Secrets set and replaced, never shown; the declined encryption writes with their reason | 25 s |
| 8 | Tasks, and the jump to logs | A failed run, and "open the logs of this period" arriving filtered and saying so | 30 s |
| 9 | The unified log stream | Five sources in one list, the original record behind a line, and a jump from an event to a process | 45 s |

### Shot 1 — The instrument cluster (45 s)

Open on `system/instruments`. Let it run. The series must be visibly filling, which takes time — that
is the shot. Say: the portal reads CPU and memory from the host and shared memory and disk from the
SysAdmin API, at one-second resolution, and keeps the window in the browser tab only.

Do not cut away early. An empty canvas is what this screen looks like in its first second, and it is
the one state this demo must not show.

### Shot 2 — The command palette (20 s)

<kbd>Ctrl</kbd>+<kbd>K</kbd>, type `FD_Demo`. Results appear grouped by domain — roles, resources, a
web application, tasks, a wallet collection. Open one from the keyboard.

### Shot 3 — A deletion, rehearsed (40 s)

From the palette, `delete a role`. The portal offers to leave safe mode first — take the offer, and
say it applies to this tab alone. Choose `FD_Demo_Operator`. Read the rehearsal on screen:

- the four fields that would change, current beside commanded;
- the impact: the users who would lose a privilege, named, and which privilege;
- the confirmation, which asks you to type the role's name because the change is destructive.

Then **Cancel**. The instance is untouched, and the session trail records that the change was opened
and abandoned.

### Shot 4 — Safe mode (25 s)

Open a second tab. It starts read-only, because safe mode is per tab and never remembered. Say that
the server rejects a change from a read-only tab before it reaches IRIS, so the guarantee does not
depend on the interface being honest.

### Shot 5 — Web applications and the REST explorer (35 s)

The web application list with its exposure markers — `/csp/fd-demo` carries "No authentication",
which is why the demo creates it. Then the REST explorer: run `GET /api/flightdeck/v1/session/capabilities`
against this instance and show the status and the elapsed time. Say it is dispatched in-process and
that the executor is not an outbound proxy.

### Shot 6 — Permissions as a graph (30 s)

Open a role, show a privilege with the chain of roles that grants it, and follow the link to the users
who hold it. The point is that you follow a question instead of re-finding each object by name.

### Shot 7 — Security and secrets (25 s)

The wallet: a secret is set or replaced, never read back. Then the encryption section, where the
writes are disabled with their reason and the native path. Say this is a decision, recorded as
declined rather than missing.

### Shot 8 — Tasks, and the jump to logs (30 s)

The task list with each task's recent history. Open the demonstration task that fails on purpose,
open its failed run, and use "open the logs of this period". The stream opens filtered on that task
and window **and says so on screen**.

The driver asks the instance to run that task before the demo starts, and waits a short while for the
failure to be recorded. The instance's task manager decides when it actually runs, so if the failure
has not been recorded by then the shot shows the list and its history bands instead, and the driver
says so in its output. The demo never pretends to a failure the instance has not had — which is the
same rule as everything else here, applied to its own subject matter.

### Shot 9 — The unified log stream (45 s)

The five sources in one list under one schema. Point out a line whose source states no level and
therefore reads `unknown` rather than being guessed at. Open an event and show the original record
behind it. Jump from an event to the process it names. Turn on live follow and let new lines arrive.

Close on this: it is the one mandatory axis of the brief with no official API coverage.

## What the author does

The driver does everything except record. The recording and its publication are the author's:

1. Start a fresh install so the instance looks like an evaluator's (`docker compose down -v && docker compose up -d`).
2. Run the driver headed, at 1440×900, and record that window.
3. Publish, and put the link in the submission.

Do not speed the recording up afterwards. That would undo the only rule this script has.
