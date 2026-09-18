# Verification records

Evidence for feature 001. The JSON reports are produced by `scripts/verify/run-both-images.sh`
and validated by `scripts/verify/validate_report.py`.

## Day-1 platform verification (User Story 1), 2026-09-17

| Image | Report | Present | Absent | Inconclusive | Exit |
|---|---|---|---|---|---|
| `intersystemsdc/iris-community:2026.2-zpm` (IRIS 2026.2 Build 221U) | `iris-2026.2.json` | 8 | 0 | 0 | 0 |
| `intersystemsdc/irishealth-community:2026.2-zpm` (IRIS for Health 2026.2 Build 221U) | `irisforhealth-2026.2.json` | 8 | 0 | 0 | 0 |

**Gate (T021): passed.** Probe 2 selects `in_process` on both images. Candidate outcomes on both:
- `in_process`: present;
- `jwt`: present, but not used by design (research R4);
- `loopback_proxy`: absent (the official API rejects the forwarded FlightDeck session).

No area is blocked: there are no inconclusive probes.

### Findings used by later tasks

- **Probe 3, shapes match the spec** on both images.
  - `system-resources`: 56 rows, keys `Name, Seize, Nseize, Aseize, Bseize, BusySet`.
  - `shared-memory`: 28 rows, keys `Description, SMHAllocated, SMHAvailable, SMHUsed, SMTUsed,
    GSTUsed, AllUsed`.

  SHM vital = `100 × ΣSMHUsed / ΣSMHAllocated` (T077).
- **Probe 4, async database metrics.**
  - `POST /v2/database-dir/info?dir=…` returns 202 with a `Location` header (upper-case
    `LOCATION`), whose value points at `/api/admin/v1/async-result?id=…` even when called on v2.
    The id is read from it and polled on `/v2/async-result`.
  - The result was ready on the first poll (about 25 ms).
  - Result keys include `Size` (MB), `AvailableSpace` (MB free inside the database), `MaxSize`
    (MB, 0 = unlimited) and `DiskFree` (string with unit, e.g. `799.42GB`).

  DSK vital (T077) = max over mounted local databases of `used / capacity`, where
  `used = Size − AvailableSpace` and `capacity = MaxSize` when `MaxSize > 0`, otherwise
  `Size + DiskFree` (converted to MB). With unlimited databases on a large disk this is close to 0 %,
  which is accurate.
- **Probe 7, log sources.**
  - `messages.log` is at `/usr/irissys/mgr/messages.log`.
  - `alerts.log` exists on IRIS for Health and is absent until the first alert on IRIS CE.
  - `Ens.Util.Log` is queryable in interoperability namespaces: `USER` on CE; `HSCUSTOM`, `HSLIB`,
    `HSSYS` and `USER` on IRIS for Health.
- **Probe 8**: auditing is enabled by default on both images.

### Script bugs found and fixed during the first run

The first run reported probe 4 `inconclusive`, probe 7 `confirmed_absent` and loopback
`inconclusive`. All three were defects in the script, not the platform:
- the `Location` header lookup was case-sensitive;
- `Ens.Util.Log` was checked from `%SYS`, where interoperability classes are not mapped;
- the loopback candidate's first request was proxied upstream before a session existed.

They were fixed and the run repeated (the table above).

## R4 open items (T046), dev container IRIS 2026.2 CE, 2026-09-17

- **(b) No Basic challenge.** `POST /api/flightdeck/v1/session` with bad credentials returns
  `HTTP/1.1 401 Unauthorized`, `Content-Length: 0` and **no `WWW-Authenticate` header** (checked with
  `curl -si`, for an unknown user and for a real user with a wrong password; the status lines are
  identical). No fallback was needed. The browser-dialog check runs in the e2e invalid-credential test.
- **(c) Application role instead of a public grant.** `fd_e2e_operator` (roles: `%Operator` only)
  signs in with 200 and gets `capabilitySummary` 58/273. The only access to the FlightDeck code
  database comes from `MatchRoles=:FlightDeck_Runtime` (`%DB_USER:R`, created through
  `PUT /v2/security/role`). No public permission was changed.
- **No administrative privilege.** `fd_e2e_none` (no roles) cannot read `%SYS`. The in-process call
  raises `<PROTECT>`, which `FlightDeck.Admin.Client` maps to 403. Sign-in returns 403
  `NO_ADMIN_PRIVILEGE` listing all eleven `%Admin_*:U` privileges, and the IRIS session is ended
  (the next request is 401).
- **(a) IRIS for Health 2026.2**: verified in the compose install run (T075); see `install-runs.md`.


## SysAdmin API findings during implementation

- **`PUT /v2/security/resource` cannot create or update a resource with no public permission.**
  `PublicPermission: ""` returns HTTP 400 with an empty `errors` array, on create and on update,
  while system resources such as `%DB_USER` report `PublicPermission: ""`. Omitting the field
  returns `ERROR #40301 Field 'PublicPermission' is required`. Demo resources therefore use the
  least permission the API accepts, `U` (Constitution I forbids falling back to
  `Security.Resources`). Observed on IRIS 2026.2 Build 221U.
- **IPM `WebApplication` attributes are `Security.Applications` property names.** `AutheEnabled`
  is honored; `PasswordAuthEnabled`/`UnauthenticatedEnabled` are silently ignored, and the app is
  then created unauthenticated (`AutheEnabled=64`). Caught during the first dev install and fixed in
  `module.xml`.
- **`%CSP.REST.DispatchRequest` is `Final`**, and `OnPreDispatch` runs before `DispatchMap`, so the
  safe-mode guard lives in `OnPreDispatch` and still runs before routing.
- **`%CSP.Request.ContentType` has a private setter**, and official handlers return 415 without it.
  `FlightDeck.Admin.Request` subclasses `%CSP.Request` to set it.
- **Declared privilege vs actual behavior: `GET /v2/database-dirs`.** The spec declares
  `(%Admin_Manage:U or %Admin_Operate:U)`, but a user whose only role is `%Operator` (which holds
  `%Admin_Operate:U`) gets HTTP 403 with an empty error. `POST /v2/database-dir/info` for the same
  user returns 202. The capability map follows the spec (Constitution III), so the Disk vital
  reports the API's refusal instead of claiming a requirement the user already meets. Observed on
  IRIS 2026.2 Build 221U.
- **procfs and streams.** `%Stream.FileCharacter` reads nothing from `/proc/stat` and
  `/proc/meminfo` (size 0). `FlightDeck.Native.HostMetrics` reads them through a sequential device.
  Host CPU/memory matched `top`/`free` inside the container (1.8 % vs 2.4 % CPU idle load; 14.9 % vs
  14.9 % memory).
- **`GET /v2/security/ldap/configurations` fails for an `%Operator`-only user** with HTTP 500
  `ERROR #5002 <INVALID OREF>AppendStatementResult+5^%Api.Admin.Util.ClassQuery.1`, although the spec
  declares `(%Admin_Operate:U or %Admin_Secure:U)` and `_SYSTEM` gets 200. The palette shows the
  IRIS error text for that group and marks the search degraded; the other groups are unaffected.
  Observed on IRIS for Health 2026.2 Build 221U.

## SysAdmin API v1 dialect (IRIS 2026.1)

- `v1-api-2026.1.md` / `.json`: coverage of v1 against the v2 specification (173 same shape,
  28 different shape, 72 absent).
- `v1-adapter-spike.md`: cost spike over 5 of the 28 translations.
- `v1-translations-2026.1.md`: the 28 translations verified live by effect through the adapter,
  14/14 test methods in three consecutive runs (`FlightDeck.Test.V1Translations`), with two
  limits:
  - pause and resume of async results are verified as reachable only, because no v1 async task
    supports them;
  - external language server start/stop is verified for `%Java Server` only. **`%Python Server`
    is NOT VERIFIED** (it timed out in the image).
- `v1-native-gaps-2026.1.md`: native providers on v1 and the T101 decision.
  - Disk per database: verified equal to `database-dir/info` on 2026.2 for all 10 databases.
  - Namespace reads: native, verified equal to the official API on 2026.2 over 21 requests;
    writes withheld.
  - Journal: deliberately not native (authorization stays in IRIS).

### Test matrix, 2026-09-17 (fresh compose installs, after T109 dialect boundary)

| Install | Backend | Playwright | Other gates |
|---|---|---|---|
| IRIS CE 2026.2 (`2026.2-zpm`, port 52780) | 56/56 (all classes; tests without their subject log a skip) | 24 passed, 8 skipped (`limited` skips when the map has no unavailable operation) | safe-mode enforcement ok |
| IRIS CE 2026.1 (`2026.1-zpm`, port 52791, limited mode) | 34/34: `V1Translations` 14, `Dialect` 6, `NativeDatabases` 5, `NativeNamespaces` 4, `AdminClient` 5 (now version-agnostic) | `limited` project 8/8 | install and demo complete on v1 |

**Boundary gate.** `npm run check:dialect` passes with 5 declared exceptions. It was checked against
probe files: it flagged exactly the 4 real checks, `instance.dialect === "v1"`, `o["apiVersion"]`,
`%Get("apiVersion")` and `Client.Limited()`. It ignored `dialect`/`limited` in comments and in UI
text ("Limited mode").

Static gates on the same tree: `check-generated`, `check-dist`, verification script unit tests,
`lint`, `check:tokens`, `check:dialect`, `contrast`, `vitest` (6), `build`.

Findings while installing on 2026.1:
- **The IPM `SystemRequirements` pin (`>=2026.2`) refused the install**; it is now `>=2026.1`.
- **`POST /v1/task` rejects a start date and time already in the past** ("ERROR #7432: Start Date
  and Time must be after the current date and time"); 2026.2 accepted it. The demo tasks now start
  tomorrow on both versions.
- **A user without privileges cannot read `%SYS`**, so the v1 dispatcher cannot be detected for
  them. Detection reports "unknown", the call returns the API's 403, and sign-in refuses for
  privileges, not for the version (e2e on both versions).

## SysAdmin API findings for web applications (feature 002 research R2), 2026-09-17

Observed on IRIS CE 2026.2 (Build 221U), install `iris-flightdeck-iris-1`, as `_SYSTEM`.

- **`IsSystemApp` is never set.**
  - `GET /v2/web-apps?maxRows=500` returns 25 applications, all with `"IsSystemApp": false`.
  - The platform's own applications report `"Type": "System,CSP"` in the same response, for
    example `/csp/sys`, `/csp/sys/mgr` and `/csp/sys/sec`.
  - The list schema promises a system marking the platform does not provide.
  - FlightDeck marks an application as a system application when **either** field says so; both
    are the API's own statements, and no name pattern is used. `FlightDeck.Test.WebAppSystemMarking`
    fails if the two fields ever disagree, so the workaround gets revisited.
- **Input validation errors return HTTP 500, not 400.**
  - `PUT /v2/web-app?name=/csp/fdt-probe` with `{"Timeout":"abc"}` returns 500 with
    `ERROR #7207: Datatype value 'abc' is not a valid number > ERROR #5802: Datatype validation failed
    on property 'Security.Applications:Timeout'`.
  - `PUT /v2/web-app/pct-access?name=/csp/fd-demo&allowType=AllowPackage&class=FDTProbe` with
    `{"AllowAccess":false}` returns 500 with
    `ERROR #1498: Class name or package must start with a %` (`WebAppPctAccessMustStartWithPct`).
  - The error text is precise; only the status class is wrong. This is the same pattern already
    recorded for v1 input errors.
  - FlightDeck's mutation layer treats these codes as a rejected input: the form is kept, the text
    is shown verbatim, the attempt is not retried, and the 500 is recorded unchanged in the trail.
- **`PUT /v2/web-app` merges fields** (not a defect, recorded because the design relies on it).
  - A body with only `Description` changed that field and kept `NameSpace` and `AutheEnabled`.
  - Creating returns 201; editing returns 200.

## Feature 002 pre-task checks, 2026-09-17

- `rest-executor-spike-2026.2.md`: spike T-EXEC-1. `$ROLES` can be cleared to login roles by any
  user, but set to a non-empty value only by IRISSYS writers, who can then add any role, including
  `%All`. In-process dispatch matches HTTP when roles match and diverges toward less privilege when
  the target application grants roles. The executor design was revised (feature 002 research R8).
- `flightdeck-web-apps-exposure-2026.2.md`: `/api/flightdeck` answers 401 to every anonymous request,
  including unknown routes and the OpenAPI document. `/flightdeck` serves only the 13 built static
  files and answers 405 to other methods. No defect. The web applications list grades
  unauthenticated exposure accordingly (feature 002 research R10).

## Mutation-boundary gate probe (feature 002 T081, SC-011), 2026-09-17

Four temporary files under `frontend/src/domains/web-apps/`, each breaking one rule, then
`npm run check:mutation-boundary`:

| Probe file | Violation | Gate output |
|---|---|---|
| `ProbeDialog.tsx` | imports `@radix-ui/react-dialog` | `renders a dialog (confirmations use the shared dry-run)` |
| `ProbeDiff.tsx` | `data-diff` and a `COMMANDED` column | `renders a diff view (use the shared dry-run)` |
| `ProbeInternals.tsx` | imports `mutation/DryRun` | `imports mutation internals (mutation/DryRun)` |
| `ProbeStorage.ts` | writes `sessionStorage` | `uses sessionStorage (the trail store lives in src/mutation/)` |

Result: exit 1, every file named with its line. After removing the probes: exit 0,
`ok (3 declared exceptions)`. The gate runs inside `npm run build`, so none of these can ship.

Found while building the pattern catalog (T078 to T080), both fixed in the shared layer rather
than in a domain:

- **Secrets in list rows.** `GET /v1/domains/{domain}/{entityType}` returned list items without
  applying the entity type's `secretFields`; web applications declare none, so nothing leaked, but
  the first later domain with a secret in its list would have. Lists now remove them like detail
  reads.
- **Blocked attempts missing from the trail.** A block decided at preview left Apply disabled, so the
  UI never reached apply and no `Blocked` record was written (FR-014). A blocked preview now
  carries the server's masked `Blocked` record, which the shared layer appends once.

## Same backend set on every version (2026-09-17)

Feature 001's 2026.1 matrix ran a chosen subset of test classes, and `CapabilityMap` was not in it;
the class failed there and nobody saw it until feature 002's matrix ran everything. Two changes keep
the versions comparable:

- `scripts/dev/test-backend.sh` (no class filter) fails when a test class present in
  `backend/test/` did not run on that instance, naming it. This also catches a stale container copy.
  Probed with a class created only on the host: the run failed and named it.
- The 2026.1 entry of the feature 002 matrix is the whole suite (115 methods, 25 classes), the same
  as IRIS CE 2026.2 and IRIS for Health 2026.2.

Tests whose subject an instance does not offer report a skip inside the test; they are not removed
from the run.

## e2e that need Docker (2026-09-17)

`rest-confinement` (container connection table), `audit` (IRIS logs) and `pattern` (the fixtures
flag, which has no HTTP surface on purpose) run `docker exec` against `FD_CONTAINER`. All three now
skip with a stated reason when it is unavailable, instead of failing: a red test caused by a missing
Docker socket reads as a broken product.

## Dialect-boundary gate extended to `declined` (feature 003), 2026-09-17

The capability policy added `declined` to every capability entry: it says FlightDeck itself does not
offer an operation, on any version. That is the same kind of fact as `dialect`, `limited` and
`apiVersion` — one a screen must not branch on — and that family leaked once before, which is why
the gate exists. `scripts/check-dialect-boundary.mjs` now flags `declined` too, with four declared
exceptions: the policy class, the capability map, the API types, and the one frontend module that
separates limited mode from a declined operation.

Probed with two temporary files, one backend and one frontend, each reading `entry.declined`:

```
check-dialect-boundary: version or dialect checks outside the dialect layer.
  backend/cls/FlightDeck/Domain/ProbeDeclined.cls:5: quit ''entry.declined
  frontend/src/domains/ProbeDeclined.tsx:2: export const hidden = (c: MutationCapability) => c.declined === true;
```

Exit 1, both named. After removing the probes: `ok (8 declared exceptions)`.

## Platform findings while building the security domain (feature 003 US3), 2026-09-17

- **`GET /info` answers 404 for an account that holds only `%Admin_Wallet:U`**, although the wallet
  operations answer 200 for that same account. FlightDeck derives privileges from `/info`, so such an
  account cannot sign in. The end-to-end account for partial mode therefore holds `%Admin_Wallet`
  plus `%Operator`; it still lacks `%Admin_Secure`, which is what makes the impact analysis report
  itself incomplete. The 404 (rather than 403) is the platform's own answer and is not masked.
- **`POST /v2/security/ssl-configuration/test` takes a fixed ten seconds to report a failed
  connection.** The dry-run stays in its applying state for that long, and the end-to-end test waits
  accordingly. Nothing is retried and nothing is timed out by FlightDeck: the platform's answer is
  what the user sees.
- **A wallet collection names its resource with the permission** (`FD_Demo_Reports:READ`), so a
  resource link compares the part before the colon.
- **A wallet secret is addressed as `<collection>.<secret>` in a single `name` parameter**, and the
  listing returns names and types only. There is no operation that reads a secret's value: UC06-1 is
  satisfied by the official API's own shape, not by a FlightDeck choice.
- **The SQL listings return `Object` and `Action` where their own schema declares `Name` and
  `Privilege`** (recorded earlier); the action descriptors accept either spelling and rewrite
  neither.

## Two usability corrections found by inspection, not by tests (feature 003), 2026-09-17

- **Sign-in refused for an account the instance will not describe.** An account holding only
  `%Admin_Wallet` is refused by the official `GET /info`, so FlightDeck cannot read its privileges.
  The message used to list the privileges FlightDeck needs, which read as "you lack these" although
  the account held one of them. It now states that the API is present and answering, that the
  refusal is about the account, and what to ask for; it is not the version message, and a test
  asserts that distinction. A wrong message here sends an administrator to investigate the instance
  instead of the account.
- **A dry-run that applies a slow operation.** The platform's TLS connection test takes a fixed ten
  seconds, and the dialog said nothing while it waited, which reads as a frozen application. The
  dry-run now shows an applying state, disables Apply while it runs, and a descriptor may declare
  what to say about the wait (`applyNotice`), so the text comes from the operation, not from a
  screen.

Also fixed: `scripts/dev/load-backend.sh` ignored the status of the test-class load, so a test class
that did not parse left the container running the previously compiled version and the suite reported
a stale result. It now fails the load; probed with a deliberately broken class (exit 1, then exit 0
once removed).

## IRIS 2026.1: the wallet secret body has another shape (feature 003)

`PUT /v2/wallet/secret` exists on the v1 dialect, but the body differs. Probed against the live
2026.1 instance, one field at a time:

```
{"Type":"%Wallet.KeyValue","WalletSecretConfig":{"Secret":"value"}}
  -> 400 Field 'WalletSecretConfig.Secret' needs to be an object, not a literal type
{"...":{"Secret":{"Value":"value"}}}            -> 400 'WalletSecretConfig.AllowedHosts' is required
{"...":{"AllowedHosts":["*"],...}}              -> 400 'WalletSecretConfig.RequireTLS' is required
{"...":{"AllowedHosts":["*"],"RequireTLS":false,"Secret":{...}}}
                                                -> 400 'WalletSecretConfig.Usage' is required
{"...":"Usage":"any"...}                        -> 400 'WalletSecretConfig.Usage' needs to be an object
```

FlightDeck does not guess the shape of a secret: the operation is withheld on the v1 dialect
(`scripts/build/v1-translations.json`, reason key `walletSecretWrite`), so the screen disables it
with the reason and the native path, and the demo installer skips the demo secret with the same
message. Reading and deleting wallet secrets stay available on that version.

## Tasks and system, probed for feature 004 (IRIS CE 2026.2, 2026-09-18)

Two platform behaviours that FlightDeck works around and does not mask, plus the two shapes the
specification does not declare. Full probe record and decisions: `specs/004-tasks-system/research.md`.

- **`GET /v2/task/history` ignores its `id` parameter.** `?id=1` and `?id=2` both return the whole
  instance history (42 rows here), each row carrying its own `TaskId`. FlightDeck reads it **once**
  per list and groups by `TaskId`, which is also what makes the per-task history band affordable: one
  request for a list of forty tasks instead of forty.
- **The asynchronous handle arrives in a header that names v1.** `POST /v2/database-dir/info` answers
  **202** with an empty `result` and `LOCATION: /api/admin/v1/async-result?id=<id>`, even on a v2
  instance. Both `/v1/async-result` and `/v2/async-result` answer for that id, so the path in the
  header is a quirk, not a dialect instruction. FlightDeck reads the id from the header and polls
  through the dialect layer; nothing outside `FlightDeck.Admin` sees that string.
- **`SharedMemoryUsage`** (undeclared in the spec) is a list of
  `{Description, SMHAllocated, SMHAvailable, SMHUsed, SMTUsed, GSTUsed, AllUsed}`.
- **`SystemResourcesStats`** (undeclared in the spec) is the seize table:
  `{Name, Seize, Nseize, Aseize, Bseize, BusySet}` per resource.
- `GET /v2/process` takes **`id`**, not `pid` (`?pid=` answers 400), and the four capability fields
  (`CanBeExamined`, `CanBeSuspended`, `CanBeTerminated`, `CanReceiveBroadcast`) already arrive on
  `GET /v2/processes`. Locks carry the same idea in `Removable`.
- `GET /v2/monitor/dashboard/main` pads `BusyProcesses` with empty entries (`{"Process": "",
  "Commands": 0}`); they are dropped on read.

## Log sources, probed for feature 005 (IRIS CE 2026.2, 2026-09-18)

What the five sources actually answer. Full record and decisions: `specs/005-unified-logs/research.md`.

- **`messages.log` states its own severity.** The line shape is
  `MM/DD/YY-HH:MM:SS:mmm (pid) <level> [Category.Event] message`, and `<level>` is the platform's own
  0–3. The normalised severity is therefore a mapping of a value the instance stated, not a judgement
  FlightDeck made. The file is resolved from the instance (`$zutil(12)`), never a hard-coded path.
- **Bounded backwards reading works.** `%Stream.FileCharacter.MoveTo(size − window)` followed by a
  short `Read` returns only that slice, which is what makes RN-FD-25 implementable.
- **A stock instance writes no `alerts.log`.** The manager directory holds `messages.log`,
  `journal.log` and `SystemMonitor.log`. IRIS writes an alerts log only where the System Monitor's
  alert handling is configured, so "absent, with the reason" is that source's normal state — not an
  error, and not an empty list.
- **The interoperability log is SQL, per namespace.** `Ens_Util.Log` exists in each
  interoperability-enabled namespace (on this install, `USER` but not `%SYS`), with
  `ID, ConfigName, Job, MessageId, SessionId, SourceClass, SourceMethod, Stack, StatusValue, Text,
  TimeLogged, TraceCat, Type`. `Type` is the platform's own level.
- **Journal records are asynchronous.** `POST /v2/journal/file/records` answers 202 with the same
  `LOCATION` handle pattern as the disk metrics, and the finished result is a plain array of
  `{Address, TypeName, TimeStamp, ProcessID, GlobalNode, DatabaseName}`. There is no user and no
  severity, and `DatabaseName` is a database — not a namespace.
- **An audit record's key travels with it.** `GET /v2/security/audit/record` requires
  `utcTimeStamp`, `systemID` and `auditIndex`, and all three are present in every row of
  `POST /v2/security/audit/records`, so the original record is always one read away.


---

## Embedded Python in `FlightDeck.Native.HostMetrics`, probed 2026-09-18

The host CPU and host memory provider was rewritten in Embedded Python. What was measured before and
after, on all three supported installs.

### Availability (requirement: IRIS 2021.2 or later)

Confirmed on each image by importing `sys` through `%SYS.Python`:

| Install | IRIS build | Embedded Python |
|---|---|---|
| IRIS CE 2026.2 | 2026.2 (Build 221U) | 3.12.3 |
| IRIS CE 2026.1 | 2026.1 (Build 234U) | 3.12.3 |
| IRIS for Health CE 2026.2 | 2026.2 (Build 221U) | 3.12.3 |

All three are far above the 2021.2 floor, and above the 2026.1 FlightDeck itself requires — so no
instance that can run this portal lacks Embedded Python. **No version is checked in the code**
(Constitution III); availability is a runtime fact, and failure degrades.

### Equivalence, before and after

The two pure parsers were called with the same fixed input on every install, before and after:

| Call | Before | After |
|---|---|---|
| `ParseCPULine("cpu  100 0 50 800 50 0 0 0 0 0")` | busy 150, total 1000 | busy 150, total 1000 |
| `ParseMeminfo(MemTotal 1000 / MemAvailable 250)` | 75 | 75 |
| `Scope()` in a container | `Docker host kernel` | `Docker host kernel` |

Live memory, read against `/proc/meminfo` at the same moment:

| Install | Provider | `awk` over /proc/meminfo |
|---|---|---|
| IRIS CE 2026.2 | 79.7 | 79.7 |
| IRIS CE 2026.1 | 82.8 | 82.8 |
| IRIS for Health CE 2026.2 | 83.1 | 83.0 |

(The Health figure is one read a fraction of a second apart from the other; memory was moving. The
same-instant comparison on 2026.2 matched to the digit.)

`FlightDeck.Test.HostMetrics` passed 3/3 on all three installs before and after, **unchanged** — the
equivalence tests were not edited.

### Degradation when Python cannot be used (never breaks the screen)

Every Python call goes through one guarded helper. Probed by asking it for a method that does not
exist, which is the same failure shape as a Python runtime that will not start:

```objectscript
write $classmethod("FlightDeck.Native.HostMetrics", "Guarded", "NoSuchPythonMethod")   // answers ""
do ##class(FlightDeck.Native.HostMetrics).ParseCPULine("not a cpu line", .b, .t)
// ERROR #5001: Host metrics are not readable on this platform.
```

That is the status the class already returned, so `FlightDeck.Vitals.Service` marks the vital
unavailable with its existing reason. No other class was touched.

### One finding, and it is not an Embedded Python bug

While writing the guard, this failed to compile:

```objectscript
ClassMethod G(name As %String) As %String
{
	try {
		quit name
	} catch {
		quit ""
	}
}
```

with `#1043: QUIT argument not allowed`. Isolated with four probe classes: the same expression
compiles outside a `try` block and fails inside one, with or without a comma in the argument, with or
without `$select` or `$classmethod`. **This is documented ObjectScript semantics, not a defect**:
inside a `TRY`, `QUIT` exits the block and cannot carry a return value. The idiom is to assign to a
variable and quit after the `try`/`catch`, which is what the class does.

Recorded here because it cost time and because it is the kind of thing that looks like an Embedded
Python failure and is not — every Python call returned empty, exactly as an instance without Python
would behave. **Nothing reportable to the contest's bug bounty was found**: the Embedded Python
runtime itself behaved correctly in every respect on all three images.
