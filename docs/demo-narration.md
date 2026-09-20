# FlightDeck demo: narration

Read over the recording the driver produces. One block per shot, in the order
[`demo-script.md`](demo-script.md) and `frontend/e2e/demo.spec.ts` run them.

Each block is sized to its shot's **minimum** at **150 words per minute**, with about **15% left over** so the
reading is not rushed and can sit inside the shot rather than run to its edge. A 40-second shot
takes about 85 words.

`[pause]` marks a place to stop and let the screen carry itself. They are where the driver is moving
between things, so the reading and the picture stay together.

Two shots depend on something the instance may not deliver, and both have a second version below.
Check the timed script the run wrote (`verification/demo-run.md`) to see which one happened before
recording the voice.

For shot 7, the middle beat has three possible outcomes and the main version covers two of them:
the control can already be disabled with its reason on it, or the confirmation can open and be
refused. Both are the portal refusing, and the line reads the same. The alternative is only for the
third, where an ordinary confirmation opens and nothing is refused.

---

## Shot 1 — The instrument cluster

**45 s minimum · 97 words · about 39 s spoken · budget 96 words**

This is FlightDeck, driving an InterSystems IRIS instance. [pause] The panel on top is the cluster. CPU and memory come from the host. Shared memory and disk come from the SysAdmin API. [pause] Every reading refreshes each second, and each one draws its own history beneath it. Watch the curves fill. That takes a few seconds, and the demo waits for it. [pause] The window lives in this browser tab. Nothing here is written to the instance, and nothing carries over to another tab. [pause] The figures beside the instance name are the same readings, kept in view wherever you go.

## Shot 2 — The command palette

**20 s minimum · 41 words · about 16 s spoken · budget 42 words**

Control K opens the command palette. [pause] I type F D underscore Demo. The palette searches the instance itself and groups what it finds by domain. Roles, resources, tasks, a wallet collection. [pause] Enter opens the highlighted one in place. Escape closes it.

## Shot 3 — A deletion, rehearsed

**40 s minimum · 78 words · about 31 s spoken · budget 85 words**

Here is the role F D Demo Operator. [pause] Safe mode is on, so this tab is read only. I turn it off, and that applies to this tab alone. [pause] Now Delete. [pause] Before anything is sent, the portal shows the rehearsal. The fields that would change, current beside commanded. The impact: which users lose which privilege, by name. And a confirmation that asks me to type the role's name. [pause] I cancel. The role is untouched. Nothing reached the instance.

## Shot 4 — Safe mode

**25 s minimum · 50 words · about 20 s spoken · budget 53 words**

Safe mode belongs to the browser tab. [pause] I open a second tab. It starts read only, while the first one is still live. [pause] The server enforces this. A change sent from a read-only tab is refused before it reaches IRIS, so the guarantee holds even when the interface is wrong.

## Shot 5 — Web applications and the REST explorer

**35 s minimum · 78 words · about 31 s spoken · budget 74 words**

Every web application on the instance, each with an exposure marker. [pause] This one allows unauthenticated access, and the marker says so. [pause] Now the REST services the instance publishes. I open FlightDeck's own API, type a path, and send it. [pause] Two hundred, with the time it took. The request ran inside the instance, and the executor opens no outbound connection. [pause] It runs as me, with my roles, and extra roles an application grants real callers are not granted here.

## Shot 6 — Permissions as a graph

**30 s minimum · 63 words · about 25 s spoken · budget 64 words**

The role again, with its effective privileges. [pause] Each one carries the chain of roles that grants it, so you see where it came from. [pause] And the accounts on this instance, with the disabled and expired ones marked. [pause] From here you follow the question. Role to the accounts that hold it, account to what it reaches. A privilege is never shown without its provenance.

## Shot 7 — Self-protection

**40 s minimum · 77 words · about 31 s spoken · budget 85 words**

Three refusals. [pause] First, I have disabled the other administrators on this instance. That is real, and they are restored at the end of this shot. One is left, and I clear its Enabled box. The portal refuses. The change would leave no administrator, and it names what it counted. [pause] Second, this process is running my session. Terminate is refused. [pause] Third, this one is a platform daemon. The instance says it cannot be ended, and the control follows.

### Alternative — The refusal for the process running this session did not land — replaces the middle beat only, between the first refusal and the daemon

**70 words · about 28 s spoken**

Second, I asked to end the process the instance reported as my session, and the confirmation opened instead of a refusal. [pause] The reason is in the platform. This instance reports no session on the process, so the rule matches on the process id, and IRIS moves a session between processes between requests. The refusal is real. It fires on the request that meets it. This click did not meet it.

## Shot 8 — Security and secrets

**25 s minimum · 49 words · about 20 s spoken · budget 53 words**

The wallet holds secrets by name. A value is set or replaced here, and never read back. [pause] Encryption is read only in this portal. The writes are disabled, each with its reason and the path in the native portal that performs it. [pause] That is a decision, recorded as declined.

## Shot 9 — Tasks, and the jump to logs

**30 s minimum · 57 words · about 23 s spoken · budget 64 words**

The task list. Each row carries a band of its recent runs. [pause] This task failed. I open it, and the run history shows the error the platform recorded. [pause] Open the logs of this period. [pause] The stream arrives filtered on that task and that window, and it says so at the top. There was no query to compose.

### Alternative — The failing task has no recorded run yet — replaces the whole block

**66 words · about 26 s spoken**

The task list. Each row carries a band of its recent runs, so a failure shows without opening anything. [pause] The demonstration task that fails on purpose has not been run by the scheduler yet, so there is no failed run to open. [pause] From a failed run, the portal opens the logs of that period filtered on the task. This instance has not given it one yet.

## Shot 10 — The unified log stream

**45 s minimum · 89 words · about 36 s spoken · budget 96 words**

Five sources, merged into one stream. [pause] Audit and journal come from the official API. System messages, alerts and the interoperability log are read by FlightDeck, because the API covers none of them. [pause] Each source reports how much it read. [pause] This line's source stated no level, so the severity reads unknown. Nothing is guessed. [pause] I open a line, and the original record sits behind the normalised fields, unedited. [pause] Then follow, which keeps the stream live. This is the one required area of the brief with no official API behind it.

## Shot 11 — The session trail, exported

**25 s minimum · 50 words · about 20 s spoken · budget 53 words**

The session trail, opened from the palette by name. [pause] It holds what this session proposed: the two refusals from a moment ago, each with its reason. [pause] I export it. Secret fields appear as changed or unchanged, never as values. [pause] The trail lives in this tab. It never reaches the instance.

## Shot 12 — The light theme

**20 s minimum · 42 words · about 17 s spoken · budget 42 words**

The same portal in light. [pause] The state colours carry the same meaning in both themes. [pause] And colour is never the only signal. A state that matters also changes its label or its glyph. [pause] The choice is remembered for this IRIS account alone.

---

## Totals

| # | Shot | Minimum | Words | Spoken | Budget |
|---|---|---|---|---|---|
| 1 | The instrument cluster | 45 s | 97 | 39 s | 96 |
| 2 | The command palette | 20 s | 41 | 16 s | 42 |
| 3 | A deletion, rehearsed | 40 s | 78 | 31 s | 85 |
| 4 | Safe mode | 25 s | 50 | 20 s | 53 |
| 5 | Web applications and the REST explorer | 35 s | 78 | 31 s | 74 |
| 6 | Permissions as a graph | 30 s | 63 | 25 s | 64 |
| 7 | Self-protection | 40 s | 77 | 31 s | 85 |
| 8 | Security and secrets | 25 s | 49 | 20 s | 53 |
| 9 | Tasks, and the jump to logs | 30 s | 57 | 23 s | 64 |
| 10 | The unified log stream | 45 s | 89 | 36 s | 96 |
| 11 | The session trail, exported | 25 s | 50 | 20 s | 53 |
| 12 | The light theme | 20 s | 42 | 17 s | 42 |
| | **Total** | **380 s** | **771** | **308 s** | **807** |

The alternatives are not in the total: only one version of each of shots 7 and 9 is read.
