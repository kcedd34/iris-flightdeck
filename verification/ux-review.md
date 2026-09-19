# UI and UX review

**2026-09-19. Findings only — nothing here was fixed.** Every item carries a class (defect, friction,
polish), an estimated cost, and what it touches. Items that would require changing
`frontend/src/pattern/` are marked **pattern layer**, because a change there reaches every domain.

Nothing in this document proposes an alternative to the token table, the semantic palette, the radius
hierarchy, the motion budget, the glareshield geometry, the rail, the list-plus-inspector shape or the
two signature moments. Those are settled.

## How this was measured

Against the real install (IRIS for Health Community 2026.2, served by IRIS itself at
`/flightdeck/`, not the Vite dev server), at **1280×800**, in both themes, signed in as `_SYSTEM`.

- A sweep of all 38 sections in both themes, recording headings, controls, disabled controls and their
  reasons, live regions, empty-state copy and horizontal overflow.
- Six scripted journeys: sign in, turn off safe mode, a mutation through the dry-run, terminate a
  process, open a task and jump to its logs, use the REST explorer — plus the command palette.
- Focus and tab order read from `document.activeElement` after each keystroke, not inferred.
- Network throttled (1.2 s latency, 150 kbit/s) to see the loading states an evaluator on a remote
  demo will actually see.
- The native Management Portal at `/csp/sys` walked for the same six areas, counting clicks.

Two source-level audits ran alongside: one over every user-visible string, one over keyboard and focus
handling. Their findings are folded in below. **Where a claim was runtime-testable I tested it**, and
say so; where a finding is source-level only, it says so.

---

## Summary

| # | Class | Finding | Cost | Pattern layer |
|---|---|---|---|---|
| D1 | defect | Empty states blame filters that are not set | 1 pattern change + 24 call sites | **yes** |
| D2 | defect | The dry-run does not take focus when it opens, and drops it on close | one component | no |
| D3 | defect | Pressing Edit opens the form without moving focus to it | one component | **yes** |
| D4 | defect | Ctrl+K opens the palette on top of an open confirmation | one line | no |
| D5 | defect | Escape from the safe-mode panel drops focus to `<body>` | one line | no |
| D6 | defect | The Processes namespace filter is an empty dropdown | one line | no |
| D7 | defect | `FD History` and `FD Info` raw JSON shown as form fields | one line | no |
| D8 | defect | Four non-interactive vitals are tab stops on every screen | one line | no |
| D9 | defect | The palette input suppresses its focus ring | one line | no |
| D10 | defect | The New button's refusal reason is mouse-only | one component + 2 copies | **yes** |
| D11 | defect | Task run history is mouse-only (`title` attribute) | one component | no |
| D12 | defect | A cold load shows a blank page with no fallback markup | ~6 lines | no |
| D13 | defect | Five of the 19 contract messages diverge in a way that loses meaning | one line each | no |
| D14 | defect | `SafeModeControl` puts click/key handlers on a bare `<span>` | one component | no |
| A1 | friction | Every refused process repeats the same sentence as its identity | one line | no |
| A2 | friction | The palette does not know the native portal's vocabulary | ~20 lines of aliases | no |
| A3 | friction | Palette labels are vendor API summaries, with class names in them | see below | no |
| A4 | friction | No impact and no consequence shown for an ordinary edit | one component | no |
| A5 | friction | The diff shows raw JSON where the form has a real editor | one component | **yes** |
| A6 | friction | Home wastes two thirds of the screen and never teaches the palette | one component | no |
| A7 | friction | The log stream shows a column of "unknown", and a paragraph in the toolbar | two lines | no |
| A8 | friction | Web authentication and Encryption show raw API field names | ~25 label entries | no |
| A9 | friction | The Disk vital is labelled "Fullest database" and reads 0% | one line | no |
| A10 | friction | Asynchronous changes are announced to nobody | several components | **partly** |
| A11 | friction | The live log list is a 200-row `aria-live` region | one line | no |
| A12 | friction | Reaching the inspector means tabbing past every row | cross-cutting | **yes** |
| A13 | friction | The instrument screen carries a table of meaningless counters | one component | no |
| A14 | friction | The REST list mixes applications with undispatched classes | one line | no |
| A15 | friction | A task's runs sit after its links in the tab order | one line | **yes** |
| A16 | friction | Safe mode plus dry-run costs 2–4 interactions the native portal does not | — (deliberate) | no |
| P1–P10 | polish | Voice, spelling and copy consistency | one line each | no |

---

## 1. Defects

### D1. Empty states blame filters that are not set — **the most visible finding on a clean instance**

`frontend/src/domains/**` passes a fixed `empty` prop to `DomainList`, so a list with no rows always
says the filters are at fault. On a stock Community instance most of these lists are genuinely empty,
and no filter is set. X.509 (`security/sections.tsx:115`) shows, with an empty search box and **no
filter controls on the screen at all**:

> **No X.509 credential matches**
> The filters exclude every credential on this instance. Clear the filters or the search text.

The user is told to clear something that does not exist. Same wording in **24 places**
(`grep -c "The filters exclude"`), covering X.509, MFT, privileged routines, wallet, TLS, LDAP,
superservers, databases, directories, namespaces, locks, journal files, audit events, users, roles,
resources, services, web applications, percent-class access and processes. Verified visually in both
themes.

Six sections already do it correctly — `security/OAuth2.tsx:94`, `system/sections.tsx:256` and
siblings say *"This instance defines no DocDB application. Add one…"* — and `rest-apis/Services.tsx:76`
already switches copy on a condition. So the distinction is understood; it is just not applied.

`DomainList` already knows both halves (`items.length`, `props.total`, the search string and the filter
values), so the right fix is one decision in the pattern layer plus a second copy string per section.
**Cost:** one change in `pattern/DomainList.tsx` and a second `empty` shape at 24 call sites. **Pattern
layer: yes.**

### D2. The dry-run does not take focus when it opens, and drops it on close

Measured, twice:

- Editing a role → `focus the moment the dry-run opens: BODY`.
- Terminating a process → focus stays on the **Terminate button behind the dialog**.
- After Escape in both cases → `BODY`.

`mutation/DryRun.tsx:59-62` calls `e.preventDefault()` in `onOpenAutoFocus` and then focuses the Apply
button, which is still `disabled` while the preview is in flight, so nothing receives focus and Radix's
fallback has already been cancelled. On close, `useMutation.tsx:112` only clears state; Radix's own
restore is cancelled and its `triggerRef` is null because these dialogs are controlled rather than
opened by a `Dialog.Trigger`.

The trap itself works — the tab trail cycles `Differences → Cancel → Apply` and stays inside. And
when the graded-confirmation field appears after the preview lands, focus is not moved to it either
(`DryRun.tsx:156-169`), so a keyboard user must discover by tabbing that there is now a field they must
type into.

This is the single confirmation surface for every mutation in the product, and it is the screen the
video is built around. **Cost:** one component. **Pattern layer: no** (but shared by every domain).

### D3. Pressing Edit opens the form without moving focus to it

Measured: `focus after pressing Edit: BODY`. The form is rendered in the inspector, which is a sibling
rendered after the entire list in the DOM, so a keyboard user who presses Edit must then tab through
every remaining list row to reach the first field. **Cost:** one component
(`pattern/ListInspector.tsx` / `pattern/DomainSection.tsx`). **Pattern layer: yes.**

### D4. Ctrl+K opens the command palette on top of an open confirmation

Measured: with the dry-run open, Ctrl+K opened the palette over it (`command-palette` visible, dry-run
still mounted). Two trapped focus scopes are stacked, and the palette can navigate away while a
confirmation is pending. The first Escape closes the palette and leaves the dry-run open, so it
recovers — but it should not be reachable. `palette/CommandPalette.tsx:50-64` listens on `window` with
capture and never checks whether a modal is open. **Cost:** one line.

### D5. Escape from the safe-mode panel drops focus to `<body>`

Measured: `after Escape, focus: BODY`. Focus should return to the safe-mode indicator that opened it.
Inside the panel the trap is correct (the trail cycles between *Turn off safe mode* and *Cancel*).
**Cost:** one line.

### D6. The Processes namespace filter is an empty dropdown

`domains/system/Processes.tsx:49` passes `{ id: "namespace", label: "Namespace", options: [] }`.
`DomainList` renders the `<select>` regardless, so the screen carries a narrow empty dropdown with a
visually-hidden label and nothing to choose — visible in the screenshot beside the search box. Every
other section builds its namespace options from the data. **Cost:** one line (populate it, or drop the
filter).

### D7. `FD History` and `FD Info` raw JSON shown as form fields in the task inspector

Measured on the first task:

> FD History `{"at":"2026-09-19 00:00:00","completed":"2026-09-19 00:00:00","kind":"run","result":"Success",…}`
> FD Info `{"Type":"System","Status":"1","Error":"Success","LastSchedule":…}`

These are FlightDeck's own composed fields, presented to the user as two JSON blobs among the task's
real fields. **Cost:** one line (exclude them from the rendered field list). The same data already
drives the history band and the next-run line.

### D8. Four non-interactive vitals are tab stops on every screen

`shell/Vitals.tsx:67` — `<span className="vital" tabIndex={0} aria-label={tip}>` as a tooltip trigger.
Four dead stops in the glareshield before any control, on every screen, and the tooltip text is
verbatim the `aria-label`, so a screen-reader user gains nothing from the stop.
`shell/LimitedModeIndicator.tsx:13` adds a fifth `tabIndex={0}` on a `role="status"` element. **Cost:**
one line each.

### D9. The palette input suppresses its focus ring

`palette/palette.css:36-38` — `.palette [cmdk-input]:focus { outline: none; }`. Specificity beats the
one global `:focus-visible` rule in `theme/base.css:34`, and the input has no border or background of
its own, so tabbing back to it from the results leaves no indication of where focus is. **Cost:** one
line. (Source-level; not separately confirmed in a browser.)

### D10. The New button's refusal reason is mouse-only

`pattern/DomainSection.tsx:88-99` marks the button `aria-disabled` — correct, it stays focusable — but
passes the reason **only** as `title`. A keyboard or screen-reader user gets a dead button and no
reason anywhere. `pattern/ActionBar.tsx:52,60-64` does the same job properly, with `aria-describedby`
and a visible `.action-reason`. Two hand-rolled copies repeat it
(`domains/web-apps/WebApplications.tsx:62-71`, `PercentClassAccess.tsx:64-73`). **Cost:** one component
plus two call sites. **Pattern layer: yes.**

### D11. Task run history is mouse-only

`domains/tasks/HistoryBand.tsx:24-31` puts each run's time, result and failure message in a `title`
attribute on a decorative `<span>`, and labels the group `"5 recent runs"`. The component's own comment
says it exists "so an intermittent failure is visible without opening anything" — which is exactly what
a keyboard or screen-reader user cannot do. **Cost:** one component (fold the results into the label).

### D12. A cold load shows a blank page

Measured with the network throttled: on a full page load, `.view` did not exist at 300 ms, 900 ms,
1800 ms, 3000 ms or 5000 ms — the page was blank the whole time. `frontend/index.html` is an empty
`<div id="root">` with no fallback content, so a cold load or a hard refresh on a slow link shows white.

**In-app navigation is fine and should not be changed**: clicking a rail item under the same throttling
showed 12 skeleton rows and `aria-busy="true"` at 250 ms. The gap is only the first load — which is
precisely what an evaluator opening the online demo experiences. **Cost:** ~6 lines of static markup in
`index.html`, removed on mount.

### D13. Five canonical messages diverge in a way that loses meaning

Against the 19 in `docs/prd.md` §9. Eight are verbatim; the divergences that matter:

- **#5, last administrative access** (`Mutation/LastAdmin.cls:82`) never says the operation is blocked,
  and leaks `%Admin_Secure:USE` and `%All` into the most consequential sentence in the product.
- **#7, reading a secret** — not implemented anywhere. The nearest text is a field hint.
- **#9, task already running** — not implemented; the platform's own refusal is shown instead.
- **#10, suspending the task manager** asks the user to type `the task manager`, where the contract says
  the instance name.
- **#11, terminating a process** asks the user to type `process 1083`, where the contract says the
  process ID — and the dialog title reads **"Apply to process process 1083"** (measured), duplicating
  the word.

**Cost:** one line each. #7 and #9 are new strings.

### D14. `SafeModeControl` puts click and key handlers on a bare `<span>`

`session/SafeModeControl.tsx:16` — `<span onClick={…} onKeyDown={…}>` with no `role` and no `tabIndex`.
It works only because its one caller passes a real `<button>` as the child, and the key handler then
fires in addition to the bubbled click, so `arm()` runs twice per activation (harmless today). Any
future caller passing a non-button gets a control invisible to the keyboard. **Cost:** one component.

---

## 2. Friction

### A1. Every refused process repeats the same sentence as its identity

Measured on the Processes list: **19 of 68 rows** carry *"The instance does not allow terminating this
process"* as their primary marker, and because the default sort is CPU time, **the first 12 rows are
all of them**. The screen reads as twelve copies of one sentence; the process's actual identity
(`CONTROL`, `WRTDMN`, `GARCOL`, `JRNDMN`…) is pushed to small grey text on the right.

The reason belongs on the action, where `ActionBar` already states it correctly. In the list it costs a
whole column and hides what the row is. **Cost:** one line (drop the marker from the row, or reduce it
to a glyph). The journey is one of the six the evaluator will try.

### A2. The palette does not know the native portal's vocabulary

An experienced IRIS administrator types what the Management Portal calls things. Measured, typing each
of the portal's own menu captions into the palette:

| Typed | Palette |
|---|---|
| Manage Roles, Manage Services, Manage Resources | **0 results** |
| Configure Namespaces, Configure Databases, Configure Memory | **0 results** |
| Manage Locks, View Processes, View Messages Log | **0 results** |
| View Background Tasks, View System Dashboard | **0 results** |
| System Administration, System Operation, System Explorer | **0 results** |
| SSL/TLS Configurations | **0 results** |
| Task Schedule, Background Tasks, Messages Log, System Dashboard, Memory | **0 results** |
| Namespaces, Locks, Processes, Databases, Journals, Auditing, TLS, X.509 Credentials | hit |

The pattern is exact: the palette matches its own section names and nothing else. "Memory" misses
although the glareshield shows a Memory vital; "Messages Log" misses although the log stream reads
`messages.log`; "System Dashboard" misses although Instruments is its counterpart.

This is a discovery defect in a product whose README leads with the palette, and the user is right that
a synonym costs a line each. **Cost:** ~20 alias entries beside the section definitions.

### A3. Palette labels are vendor API summaries

Every mutating operation enters the palette with the official OpenAPI `summary` as its label and
`METHOD /v2/path` as its visible context (`palette/actions.ts:59,61`). Measured examples:

- `Delete a database (Config.Databases)` — an ObjectScript class name in a command name.
- `Edit/Create a license server`, `Create/edit an SSL Configuration` — vendor casing and word order.
- `Update miscellaneous journal settings PUT /v2/journal/settings`.
- `Authenticate user and receive JWT tokens. Available starting in IRIS 2026.2` — a version claim baked
  into a label.

155 operations are affected. Renaming all of them is not a days-before-submission change; **suppressing
the parenthetical class names and the two or three worst labels is**. **Cost:** either a small override
map for the worst offenders (cheap) or a full relabelling (not cheap). Recommend the former.

### A4. No impact and no consequence for an ordinary edit

Measured on a role edit: `dry-run-impact` count **0**, `dry-run-consequence` count **0**. The dialog
shows the field diff and nothing else. The README sells "dry-run with impact analysis" as a
differentiator, and the most likely mutation an evaluator performs shows none. The absence is
indistinguishable from "we could not compute it".

For contrast, terminating a process **does** carry its consequence — *"The process stops at once. Work
in flight is lost, and anything waiting on it fails."* — so the mechanism exists. **Cost:** one
component (state "nothing else on this instance refers to it" when an impact provider ran and found
nothing, and say so when none exists).

### A5. The diff shows raw JSON where the form has a real editor

Measured, same dialog: the `Resources` row reads
`{"Name":"FD_Demo_Reports","Permissions":"RW"}` in both columns, wrapped mid-token. The edit form
behind the dialog renders the same field as name + permission chips with a Remove button. The signature
moment shows the worse of the two representations. **Cost:** one component. **Pattern layer: yes** (the
diff renderer is shared).

*Not a finding:* the diff's colour coding works — the changed row is coloured, unchanged rows are muted,
and "1 of 4 fields change" is accurate. Showing unchanged rows is fine.

### A6. Home wastes two thirds of the screen and never teaches the palette

At 1280×800 the home screen fills the top-left and leaves roughly two thirds of the viewport empty,
ending at *"Nothing needs attention"*. It is the first screen after sign-in and the first impression in
the video.

More importantly, **nothing on it mentions the command palette**. The README's first sentence leads
with the interaction model; the product's own first screen does not. An evaluator can plausibly finish
a whole session without pressing Ctrl+K. **Cost:** one component — a line of copy is enough; it does
not need a new layout.

### A7. The log stream shows a column of "unknown", and a paragraph in the toolbar

At 1280 in both themes, every audit row renders severity `unknown` — 25 consecutive rows of the same
word in the screenshot, because audit records carry no severity (correctly documented). And the
unknown-severity checkbox carries a three-line explanatory paragraph *inside the filter bar*:

> Include events whose source stated no severity (unknown). They are not ranked, so a minimum severity
> neither includes nor excludes them.

It squeezes the text filter and the Follow live / Export buttons against the right edge. **Cost:** two
lines (render `—` rather than the word, and move the explanation to the control's title or a hint row).

### A8. Web authentication and Encryption show raw API field names

Measured section text: *Authe Always Try Delegated, Authe Cache, Authe Delegated, Authe KB, Authe LDAP
Cache, Authe Login Token, Authe O Auth2, Authe OS Delegated, Authe OSLDAP, Authe Two Factor PW, JWT Sig
Alg* — and on Encryption: *DB Enc Start Mode, DB Enc IRIS Temp, DB Enc Default Key ID*.

`domains/presentation.ts:31-52` overrides 21 names and lets everything else through `humanize()`, which
only splits camel case. The file states the policy deliberately ("nothing here renames or reinterprets
an official field"), and that policy is defensible — but "Authe KB" is not a field name a reader can
map to Kerberos, and the `LABELS` map already proves exceptions are acceptable. **Cost:** ~25 entries in
the existing map; no mechanism change.

### A9. The Disk vital is labelled "Fullest database" and reads 0%

Measured: `{"text":"Disk0%","label":"Fullest database"}`. The word in the glareshield says disk, the
tooltip says database, and on a clean instance the number is 0% — which reads as "no data" rather than
"nothing is full". **Cost:** one line (name it what it measures).

### A10. Asynchronous changes are announced to nobody

Source-level, with the live-region inventory taken from the running app:

- The four glareshield vitals refresh every 10 s and change `data-state` at a threshold with no live
  region; a vital going to warning is silent.
- The instrument cluster polls at 1 Hz; band changes, the stale marker and the warning-coloured message
  line are silent. **Pattern layer** (`pattern/instruments/`).
- After a mutation applies, three queries refresh the list, the entity and the links in place; only the
  row *count* is in a `role="status"`, so deleting announces "11 of 339" and terminating announces
  nothing. **Pattern layer** (`pattern/useDomainMutation.ts`, `pattern/DomainList.tsx`).
- The REST explorer's response — status, elapsed time, body — appears with no announcement and no focus
  move.
- The dry-run summary changes from "Reading the current state from the instance." to "N of M fields
  change." with no live region.

Done correctly already: the palette result count, the palette's assertive refusal, the safe-mode flip,
the "Applied" status, and ~30 `role="alert"` error blocks. **Cost:** several small components; the two
pattern-layer ones are the risky half.

### A11. The live log list is a 200-row `aria-live` region

`domains/logs/Stream.tsx:211` sets `aria-live="polite"` on the whole `<ul>` while following, with a
200-row limit and a 5 s refetch. The count of genuinely new events is never stated. Source-level; needs
a screen reader to confirm how much it actually speaks. **Cost:** one line plus a small status element.

### A12. Reaching the inspector means tabbing past every row

There is no skip link anywhere in the app, and the inspector is rendered after the whole list. On the
Processes screen that is up to 68 stops between the list and the Terminate button; on Resources, 185.
`<main className="work">` exists but has no `tabIndex={-1}` and nothing targets it. **Cost:**
cross-cutting — a skip link in the shell plus focus movement on selection in the pattern layer.
**Pattern layer: yes.**

### A13. The instrument screen carries a table of meaningless counters

The Instruments section — the signature screen and the one in the video — ends in a "Resource seizes"
table of roughly 25 rows of `Seize / Nseize / Aseize / Bseize / Busy set` counters, under a note that
honestly admits *"The specification states no meaning for these counters"*. Honest, and still a wall of
numbers with no decision value on the most-seen screen. **Cost:** one component (collapse it behind a
disclosure).

### A14. The REST list mixes applications with undispatched classes

The list shows 40 entries, of which 16 are class names like `%Api.InteropEditors.v1`,
`HS.FHIRServer.MFE.V1`, each marked *"No web application serves it directly"*. They cannot be called,
so they are 16 rows of internal names the user cannot act on. **Cost:** one line (a filter default, or
a separate group).

### A15. A task's runs sit after its links in the tab order

`pattern/EntityInspector.tsx:75-83` renders `inspectorExtra` after `LinksPanel`, so the run history — the
reason you opened a failed task — is further down the tab order than the entity graph.
**Pattern layer: yes.** **Cost:** one line.

### A16. Safe mode and the dry-run cost interactions the native portal does not

Stated so it is recorded as a decision, not an oversight. To change a role's description:

- Native portal: open Users/Roles → open the role → edit → Save. No confirmation.
- FlightDeck: open the section → open the role → **turn off safe mode (2 interactions)** → Edit → change
  → Review changes → **Apply**. Two to four extra interactions.

This is the product's argument and should not be removed. The one part worth keeping an eye on is that
safe mode re-arms on a full page reload, so an evaluator who refreshes pays the cost again — correct by
RN-FD-03 (never persisted), and worth a sentence in the README rather than a code change.

---

## 3. Comparison with the native portal

### Clicks to the same place (measured in both)

| Task | Native portal | FlightDeck | Faster |
|---|---|---|---|
| Users | 3 — System Administration › Security › Users | 1 — rail *Permissions* | FlightDeck |
| Web applications | 4 — System Administration › Security › Applications › Web Applications | 1 — rail *Web applications and APIs* | FlightDeck |
| TLS configurations | 3 — System Administration › Security › SSL/TLS Configurations | 1 — rail *Security and secrets* | FlightDeck |
| Processes | 2 — System Operation › Processes | 2 — rail *System* › tab *Processes* | equal |
| Tasks | 3 — System Operation › Task Manager › Task Schedule | 1 — rail *Tasks* | FlightDeck |
| Messages log | 3 — System Operation › System Logs › Messages Log | 1 — rail *Logs* | FlightDeck |

FlightDeck is faster or equal on all six, because the rail is flat where the portal's menu is three
deep. **The one place it is slower is not navigation but change** (A16), and that is deliberate.

### Vocabulary

The portal's own words, taken from its menu: *System Administration, System Operation, System Explorer,
Interoperability, Analytics, Health*; and *Configure Namespaces, Configure Databases, Configure Memory,
Manage Web Applications, Manage Users, Manage Roles, Manage Services, Manage Resources, Manage Locks,
View SQL, View Classes, View Routines, View Globals, View System Dashboard, View Processes, View
Messages Log, View Background Tasks*.

Of the phrases an administrator would actually type, **15 of 17 return nothing** in the palette (A2).
The portal also has its own search, and it answers "Users" with *"Users — View, add, or edit user
definitions."* — so the comparison an evaluator may run is search against search, and ours loses on
their vocabulary.

### Information present there and absent here

- **Processes.** The portal lists, per row: Job #, Process ID, User, Device, Namespace, Routine,
  Commands, Globals, State, Total CPU Time, Elapsed Time, Parent PID, Client Name, Client EXE, Client
  IP — sortable by any column. FlightDeck shows Namespace · Routine · State · CPU on the row and the
  rest only in the inspector, one process at a time, sortable by three fields. Every field exists in
  FlightDeck; what is missing is **comparability across rows** when triaging. *Scope decision, but a
  real cost — the closest thing to "slower than the portal".*
- **Users.** The portal adds per-row Delete and Profile links. Delete is an action-placement choice.
  **Profile** reads data the official SysAdmin API does not report (`GET /v2/security/user` returns 16
  fields, none of them login history), so its absence is a consequence of the API-first rule, not an
  omission.
- **Everything else compared** (web applications, TLS, tasks, messages log) showed no field present
  there and absent here.

No change to appearance is proposed anywhere. The differences in look are deliberate and are not in
this list.

---

## 4. Polish

| # | Finding | Where |
|---|---|---|
| P1 | The same actor is called "the server", "the instance", "the platform", "the official API" and "the SysAdmin API". "The instance" should win; two contract lines (#13, #17) say "server" and should be revised to match the code, not the reverse | ~11 sites |
| P2 | Loading copy mixes "Signing in" / "Searching" (no ellipsis) with "Applying…" / "Reading…" and lowercase fragments "· refreshing", "reading it now" | 6 sites |
| P3 | Two empty states restate the title instead of giving a cause (`system/sections.tsx:205`, `tasks/sections.tsx:155`); three fill the required next action with an explanation the user cannot act on (`home/Home.tsx:43`, `system/sections.tsx:236`, `tasks/Tasks.tsx:41`) | 5 sites |
| P4 | Message #3 is a literal in five places and #17 in three, with no shared constant; the safe-mode indicator uses a sixth wording as its accessible name, different from its visible text | 8 sites |
| P5 | `Vitals/Service.cls:27,42` hand-rolls half of canonical message #2, dropping "Ask your instance administrator for access."; `shell/Vitals.tsx:55` appends the raw token `%Admin_Operate:U` | 3 sites |
| P6 | Filter labels are `visually-hidden` everywhere, so the sort control rests on "CPU time", which does not read as a sort | `pattern/DomainList.tsx:51` |
| P7 | `.inspector-close` floats right but is rendered first, so reading and tab order are "Close" then the thing it closes | `shell/shell.css:321` |
| P8 | Empty states never offer the "New" action, although `EmptyState` accepts one | 24 sites |
| P9 | The palette finds "License" but not "Licence", while the README writes "licence" | 1 alias |
| P10 | The palette's zero-result help repeats the full domain list and the keyboard shortcuts every time | `CommandPalette.tsx` |
| P11 | `palette/CommandPalette.tsx:87` falls back to "This action is not available to you." with no reason — the one refusal in the product that does not say why | 1 site |

---

## 5. What was checked and is right

Recorded so the list above is read as exceptions, not as a verdict.

- **In-app loading**: skeleton rows plus `aria-busy` within 250 ms under heavy throttling. Correct.
- **The diff**: colour-coded changed rows, muted unchanged rows, an accurate "N of M fields change", and
  "Nothing is sent until you apply."
- **Focus traps**: both the dry-run and the safe-mode panel trap focus correctly once entered.
- **Refused actions**: `ActionBar` uses `aria-disabled` rather than `disabled`, so refused controls stay
  focusable and carry their reason through `aria-describedby` and visible text. This is the model the
  rest of the app should follow (D10).
- **List rows are real buttons** everywhere — there is no clickable div in the product.
- **Sign-in** completes by keyboard with correct labels, `autoFocus`, Enter-to-submit and a
  `role="alert"` error. The submit button is skipped by Tab only while it is legitimately disabled.
- **The dry-run offers "Turn off safe mode and continue"**, so a user who forgot is not sent back to the
  glareshield.
- **The safe-mode disarm is reachable three ways**: glareshield, palette, and the banner inside the edit
  form.
- **Both themes** render every section without a layout difference; no horizontal page scroll at 1280 in
  either.
- **No positive `tabIndex`** anywhere, and one single global `:focus-visible` rule.
- The session capability panel (`262 of 273 operations available to you`, per domain) is genuinely
  useful and has no equivalent in the native portal.

---

## 6. Suggested order, if only some of this is done

Not a decision — the user decides. Offered because the submission is days away and the cheapest items
are also the most visible.

1. **D1** (empty states) — the state an evaluator sees most on a clean instance, and the fix is
   mechanical.
2. **A2** (palette synonyms) — one line each, and it is the first thing an experienced administrator
   tries.
3. **D6, D7, D9, A1, A9** — one-line each, all visible on screens in the video.
4. **D2, D5, D3** — focus handling on the confirmation path; D2 is the highest-value accessibility fix
   and touches one component.
5. **D4, D12, A4, A7** — small, visible, low risk.
6. Everything marked **pattern layer** (D1's mechanism, D3, D10, A5, A10, A12, A15) — real risk this
   close to submission; worth doing only for the ones above that need it.
