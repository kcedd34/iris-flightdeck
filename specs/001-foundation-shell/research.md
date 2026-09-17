# Phase 0 Research: FlightDeck Foundation and Shell

Findings marked **[observed]** were checked against live containers on 2026-09-16:
`intersystemsdc/iris-community:latest` (IRIS 2026.1 build 234U), `intersystemsdc/iris-community:2026.2`
(= `latest-cd`, IRIS 2026.2 build 221U) and `intersystemsdc/irishealth-community:latest-cd`
(IRIS for Health 2026.2 build 221U). The probes were manual and ad hoc. The day-1 script (User Story 1)
must reproduce them before the session design is formally final (FR-007).

---

## R1. Target IRIS version: pin the Community images to 2026.2

**Finding [observed]**: The `latest` tag of both Community images is IRIS **2026.1**. It ships the
SysAdmin API as **v1 only**: `Api.Admin` routes `/info` plus `/v1/*`, about 197 routes, and
`/api/admin/v2/*` returns 404. v1 has no `namespace`, `database`, `database-dir`, `ecp`,
`journal`, `lock`, `fs-access-purpose` or `ext-lang-server` families, and no `/login`,
`/refresh`, `/logout` or `/revoke`. The `2026.2` / `latest-cd` tag ships `%Api.Admin` with
`/v1` and `/v2`. `/info` there reports `apiVersion: 2`, and `/v2/web-apps`, `/v2/namespaces`,
`/v2/security/roles` and `/login` all respond. The same holds for IRIS for Health 2026.2
(`product: "irisforhealth"`).

**Decision**: Pin `intersystemsdc/iris-community:2026.2-zpm` (default) and
`intersystemsdc/irishealth-community:2026.2-zpm` (alternative, selected by one optional variable).
The `-zpm` variants are the same builds with IPM preinstalled (R13).
The minimum supported version is **IRIS 2026.2**. On an older instance, the sign-in screen shows
the §9 message "Not available on this IRIS version or edition. Requires IRIS 2026.2." with the
detected version from `/info`, and no session is created (Constitution VIII: explicit reason,
nothing breaks).

**Rationale**: The contest spec (`docs/sysadmin-api-v2.json`, 273 operations) is v2. Degrading
about 140 operations to "unavailable" on 2026.1 would gut Complexity for no benefit, since 2026.2
is a published Community tag on both editions.

**Alternatives considered**: Targeting v1 on 2026.1 was rejected because it contradicts
Constitution I (the v2 spec is the source) and loses five families outright. Supporting both
v1 and v2 was rejected because it doubles every adapter for an older release the contest does
not target.

## R2. Community image entrypoint crashes: bypass it

**Finding [observed]**: On both `2026.1` and `2026.2`, the image's `/docker-entrypoint.sh`
post-start hook (`iris-after-start` → `irissqlcli` → `dbapi.connect`) fails with "Cannot call an
iris.package wrapper … dbapi.connect". It then runs `[FATAL] Error executing post-startup
command` and **shuts IRIS down**, so the container exits.

**Decision**: The FlightDeck image overrides the entrypoint with
`/tini -- /iris-main --check-caps false -a /opt/flightdeck/docker/first-start.sh`. `iris-main` is
the stock InterSystems launcher. The `-a` hook is ours and writes all output to the container log.

**Rationale**: `docker compose up -d` must work with no manual step (FR-040). The stock hook
cannot be fixed from outside the image, and its only job (namespace/user setup) is replaced by
our installer.

**Alternatives considered**: Setting `IRIS_INIT` to skip the hook does not work: the variable
is re-declared from a marker file inside the script. Waiting for a fixed image is not viable
under the deadline.

## R3. Default credential is expired on first boot

**Finding [observed]**: `_SYSTEM` has `ChangePassword=1` on a fresh container, so any
authentication with `_SYSTEM`/`SYS` returns 401 until the password is changed.

**Decision**: The first-start installer (container path only) calls
`Security.Users.UnExpireUserPasswords("*")`. This keeps the image's documented default `SYS`
password and creates no new credential, consistent with clarification 1 and FR-041. The README
states `_SYSTEM` / `SYS` and that it is for local evaluation only. The IPM path never touches
user accounts.

**Alternatives considered**: Prompting the evaluator to change the password on first sign-in was
rejected: it requires a change-password flow that is out of scope, and it adds a manual step.
Generating a password was rejected by clarification 1.

## R4. Authentication path (probe 2): in-process under the web-application user

**Findings [observed on IRIS 2026.2 CE]**:

- **Candidate 1 (in-process)** was prototyped with a throwaway `%CSP.REST` class (`UseSession = 1`,
  web app `AutheEnabled = 32` Password, `GroupById = %ISCMgtPortal`):
  - The first request with an `Authorization: Basic` header authenticates the user. IRIS issues
    its own `CSPSESSIONID` cookie (httpOnly, IRIS-managed).
  - Later requests with the cookie only are authenticated as the same user (`$username`,
    `$roles` correct). A request with no cookie and no header gets 401.
  - `<Map Prefix="/admin" Forward="%Api.Admin"/>` and a direct in-process
    `##class(%Api.Admin).DispatchRequest(url, method, 1)` both return the official JSON.
  - **The official handlers must run with `$namespace = "%SYS"`** (the `/api/admin` app's
    namespace). In another namespace, `/v2/processes` fails with `ERROR #5660 Query
    'SYS.Process:CONTROLPANEL' does not exist`.
  - Privilege enforcement is intact. A user with only `%Operator` gets `/info` with
    `Operate.use = true`, `/v2/processes` 200, and `/v2/security/roles` **403**.
  - A non-`%All` user gets **403 from the FlightDeck app itself** unless they can read the
    database that holds FlightDeck's code. This was confirmed by granting read and retrying.
- **Candidate 2 (JWT)**: present on 2026.2. `POST /api/admin/login` accepts
  **`{"user": ..., "password": ...}`**. The spec's `LoginRequest.required: ["username", ...]` is
  wrong: `username` returns 401. Access token TTL is 60 s and refresh TTL is 900 s. A bearer
  token works on `/info` and `/v2/*`.
- **Candidate 3 (loopback proxy with CSP cookie)**: not prototyped. The browser only holds the
  session cookie for FlightDeck's own path, so a server-side loopback has no cookie valid for
  `/api/admin/` to forward. Expected `confirmed_absent`; the script must record the real outcome.

**Decision**: Candidate 1, **in-process**, is the session design.

- FlightDeck's REST app `/api/flightdeck` uses Password authentication and IRIS CSP sessions.
  Sign-in is one `POST /api/flightdeck/v1/session` carrying `Authorization: Basic`. The frontend
  builds the header from the form fields, sends it once, and drops the values immediately; they
  are never put in state, storage or logs. From then on the only authenticator is the IRIS-owned
  `CSPSESSIONID` cookie, which FlightDeck neither reads nor writes.
- Every official call goes through one class, `FlightDeck.Admin.Client`. It saves and restores
  `%request`/`%response`, sets `$namespace = "%SYS"`, calls `%Api.Admin.DispatchRequest` and
  captures status and body.
- FlightDeck's code database (the install namespace's routine database) is readable inside the
  app through an **application role**: both web apps' `MatchRoles` grant `FlightDeck_Runtime`,
  which holds only `%DB_<db>:R`. No public grant is made and no user account is changed. This
  must be confirmed by a task before US2 is done.
- **Output capture** (added during implementation). The official handler's output is captured with I/O
  redirection on the current device, not by switching to a file device. In a web request,
  `GET /v2/journal/files` switched devices internally and wrote straight into the HTTP response. The
  mnemonic routine must resolve while the handler runs in `%SYS`. A routine only in the install
  namespace cannot; extended references are not accepted in a mnemonic space; and on IRIS 2026.2 a
  `%Z` class compiled from `USER` is stored in the `USER` database, not IRISSYS. The installer
  therefore also deploys `FlightDeck.Admin.Capture` (redirect entry points only) to `%SYS`
  (Complexity Tracking).
- JWT is **not used**. Holding a 60-second access token plus a refresh token in the tab would be
  a cached credential beyond one request (Constitution II).

**Rationale**: This is the first candidate in PRD §14 order, confirmed present. It needs no
stored token anywhere, runs as the real user with real roles (Constitution II), and adds no
HTTP hop.

**Alternatives considered**: JWT was rejected because refresh requires keeping a refresh token
(a credential) for the session's life. Loopback proxy was rejected as expected-absent and adds a
hop.

**Open verification (tasks)**:
- (a) Confirm on IRIS for Health 2026.2.
- (b) Confirm whether IRIS returns `WWW-Authenticate: Basic` on 401. If it does, browsers may show
  a native auth dialog. Mitigation: the backend's `OnHandleCorsRequest`/401 path never emits it
  for API routes, or the web app sets its login-page behavior so no challenge is sent. Verify
  before US2 sign-off.
- (c) Confirm the `MatchRoles` application role.

## R5. Safe mode enforced in the backend (clarification 4)

**Decision**: Every request carries two custom headers:
- `X-FlightDeck-Tab`: a random id generated in memory at tab start.
- `X-FlightDeck-Safe-Mode`: `armed` or `disarmed`.

`FlightDeck.API.Router.OnPreDispatch` rejects any `POST`/`PUT`/`PATCH`/`DELETE` whose safe-mode
header is not exactly `disarmed`, with **403** and the §9 message "Safe mode is on. Turn it off to
make changes in this tab." This happens before any `FlightDeck.Admin.Client` call. An explicit
allowlist exempts only `POST /session` (sign-in) and `DELETE /session` (sign-out), which change no
IRIS state. Any request missing `X-FlightDeck-Tab` is rejected with 400.

**Rationale**: This meets FR-015a. Requiring non-simple custom headers also forces a CORS
preflight, and since FlightDeck serves no CORS, cross-site form or fetch CSRF against the
cookie-authenticated API fails.

**Alternatives considered**: A server-side per-tab registry was rejected because it is state the
server would have to expire, it cannot tell a duplicated tab apart, and it adds nothing beyond
the header check.

## R6. Safe-mode state in the browser

**Decision**: A plain in-memory module (a store read through a React hook). It is never written
to `sessionStorage`, `localStorage`, cookies, IndexedDB, URL or `history.state`. A lint rule plus
a unit test forbid storage APIs in `session/safeMode*`.

**Rationale**: Chromium and Firefox copy `sessionStorage` into a duplicated tab, which would carry
a disarmed state across (RN-FD-03). In-memory state always initializes armed.

## R7. Capability map derivation (Constitution III)

**Finding**: 273 unique method+path operations. Every privileged operation's `summary` starts with
`(%Admin_X:U)` or `(%Admin_X:U or %Admin_Y:U)`. `/info` and the four auth operations have no
prefix. `/info.result.privileges` returns one key per `%Admin_*` resource without the prefix
(`Secure`, `Operate`, `FileSystemAccess`, …) with `{use: boolean}` **[observed]**.

**Decision**: At build time, the official spec is copied into the backend as
`FlightDeck.Capability.Spec` (an XData JSON block generated from `docs/sysadmin-api-v2.json` by a
build step and checked for drift in CI). At runtime, `FlightDeck.Capability.Map`:
1. Parses each operation's summary prefix with `^\((%Admin_\w+:U)( or %Admin_\w+:U)*\)`.
2. Crosses it with `/info` privileges: allowed if **any** listed privilege has `use = true`.
3. Returns `missing` as the full list of acceptable resource:permission pairs when not allowed.

An operation whose privilege key is absent from `/info` counts as not allowed, with reason
"Privilege not reported by this instance". No hand-written table exists anywhere.

**Alternatives considered**: Fetching the instance's generated spec from `/api/mgmnt` was
rejected because those auto-generated specs do not carry the privilege summaries. Deriving on
the client was rejected because the backend needs the same map for later server-side checks.

## R8. Glareshield vitals: host metrics (native) and IRIS metrics (SysAdmin API)

**Finding**: The v2 spec has **no host CPU or host memory**:
- `SystemUsageStats`: reference counters.
- `MainDashboardStats`: performance counters and status strings.
- `SharedMemoryUsage`: IRIS shared memory heap.
- `SystemResourcesStats`: seize counters.
- Disk space arrives asynchronously via `POST /v2/database-dir/info` (202) and
  `GET /v2/async-result`.

The contest statement names CPU and memory. Constitution I v2.0.0 lists host CPU/memory as the
second native-provider gap.

**Decision**: four vitals.

| Vital | Label | Source | Computation |
|---|---|---|---|
| Host CPU | `CPU` | **Native** `FlightDeck.Native.HostMetrics` reading `/proc/stat` | The first `cpu` line gives user, nice, system, idle, iowait, irq, softirq, steal. busy = total − (idle + iowait). Percent = Δbusy/Δtotal between the previous sample and now. The previous sample lives in `^||` process memory plus `%session.Data("fd.host.cpu")`; if there is none, or it is less than 1 s old, take a second reading 1 s later |
| Host memory | `MEM` | **Native**, `/proc/meminfo` | `(MemTotal − MemAvailable) / MemTotal` |
| IRIS shared memory | `SHM` | SysAdmin API `GET /v2/monitor/system-usage/shared-memory` | `SMHUsed / SMHAllocated` summed over rows. Shape confirmed by probe 3 |
| Disk | `DSK` | SysAdmin API, async `database-dir/info` plus `async-result` | Fullest mounted local database: `(Size − AvailableSpace) / capacity`, where capacity is `MaxSize` if > 0, else `Size + DiskFree` in MB (probe 4, `verification/README.md`). The last known value is kept while pending |

Rules:
- The native provider reads each file with `%Stream.FileCharacter`, never loads anything else,
  and runs only after `$SYSTEM.Security.Check("%Admin_Operate","USE")`. Otherwise the vital is
  `unavailable` with `requires: "%Admin_Operate:U"`.
- If `/proc/stat` or `/proc/meminfo` is unreadable (`$system.Version.GetOS()` not UNIX, or the
  file is missing), CPU and MEM are `unavailable` with "Host metrics are not readable on this
  platform."
- In a container, `/proc/stat` and `/proc/meminfo` show the **Docker host kernel** (on WSL2 the
  WSL VM), not cgroup limits. The tooltip says "Host CPU (Docker host kernel)" when
  `/.dockerenv` exists or `/proc/1/cgroup` mentions docker/containerd.
- Refresh every 10 s, paused while the tab is hidden.
- Thresholds: caution ≥ 75 %, warning ≥ 90 %.
- Verification (SC-011): compare with `top -bn1` and `free` inside the container.

**Alternatives considered**:
- cgroup-limited metrics (`/sys/fs/cgroup/cpu.stat`, `memory.current`) were rejected for the
  glareshield, which answers "is the machine under pressure". They can be added later as a labeled
  container metric.
- An IRIS `%SYS` utility (`SYS.Stats`/`^mgstat`) was rejected because it does not give host CPU%,
  and anything it does give that the API also exposes would duplicate the API.

## R9. Backend REST structure: hand-written router with its own OpenAPI document

**Decision**: `FlightDeck.API.Router` extends `%CSP.REST` with `UseSession = 1`. `contracts/flightdeck-api.openapi.json`
is served at `GET /api/flightdeck/v1/openapi.json`. A `%UnitTest` asserts that the router's
`UrlMap` and the OpenAPI paths/methods match exactly, so the spec cannot drift.

**Rationale**: Spec-first generation (`%REST.API`) regenerates the `.disp` class on compile and
does not expose `UseSession`, which R4's session model needs. The parity test gives the same
guarantee as spec-first.

**Alternatives considered**: Spec-first with a post-generation patch was rejected as fragile on
every recompile.

## R10. Frontend libraries

| Concern | Choice | Why |
|---|---|---|
| Build | Vite 6, React 18, TypeScript 5 (strict) | Constitution stack. Static output, no runtime server |
| Routing | React Router 6 (`BrowserRouter`, basename `/flightdeck`) | Tab-in-URL (FR-033). Deep links served by the SPA fallback (R12) |
| Server state | TanStack Query 5 | Dedupe and cancel palette searches; later used for revalidation (RN-FD-31) |
| Palette | `cmdk` 1.x on Radix Dialog | Keyboard listbox, groups, async items. Unstyled |
| Primitives | Radix UI (Dialog, Tooltip, Tabs, VisuallyHidden) | WAI-ARIA behavior without styling |
| Styling | **Plain CSS**: every value in `src/theme/tokens.css` as custom properties (both themes, spacing, radius, motion, shadow), and per-component `.css` files that may only reference `var(--…)` | *Changed during implementation (2026-09-17).* Tailwind 4 with defaults removed still accepts arbitrary values and derives spacing from a multiplier, so off-scale values could not be rejected reliably. `npm run check:tokens` now rejects any color literal, any px spacing/radius off the 4/8/12/16/24/32/48 and 0/2/6 scales, and any transition over 200 ms in every file under `src/` |
| Fonts | `@fontsource/ibm-plex-sans`, `@fontsource/ibm-plex-mono` (latin, 400/500), bundled | No CDN (Constitution, Technical Constraints) |
| Unit tests | Vitest + Testing Library + jsdom | |
| E2E | Playwright (dev dependency only) against the Vite dev server proxied to the container | Two-tab, keyboard and axe checks. Never shipped |
| Guards | ESLint rules: no hex/rgb literals in `src/**` except `theme/tokens.css`; no `localStorage`/`sessionStorage` outside `prefs/` | Constitution X and IV made mechanical |

## R11. Day-1 verification script

**Decision**: `scripts/verify/verify_platform.py`, Python 3 standard library only (the host has
`python3`; `jq` is absent). It takes `--base-url`, `--container` and `--product-label`, and reads
the credential from `FD_VERIFY_USER`/`FD_VERIFY_PASSWORD` (defaults `_SYSTEM`/`SYS` for the local
container), never writing it to the report. Probes that need in-instance code (candidates 1 and 3,
probe 7's file paths and interoperability log query) load `FlightDeck.Verify.Probe*` classes
through `docker exec … iris session` and remove them afterward. Each probe runs in its own
`try` with a timeout.

Output:
- `verification/<product>-<version>.json` (schema in `contracts/verification-report.schema.json`)
- a human table on stdout
- exit code 1 if any probe is `inconclusive`, 2 on usage error, 0 otherwise

`scripts/verify/run-both-images.sh` starts each 2026.2 image with the R2 entrypoint, applies R3,
runs the script and removes the containers.

**Classification rules**:
- `confirmed_present`: the capability was exercised end to end with the expected shape.
- `confirmed_absent`: the platform gave a definitive negative (404 on the route, class does not
  exist, `/info` without the key).
- `inconclusive`: anything else (timeout, 5xx, unexpected shape, script exception). The raw error
  or response is recorded for every non-present result.

## R12. Serving the SPA from IRIS

**Decision**:
- Web app `/flightdeck`: dispatch class `FlightDeck.UI.Static` (`%CSP.REST`, no auth,
  `ServeFiles = 0`). It streams files from `<install dir>/web/` with correct content types and
  `Cache-Control: immutable` for hashed assets, and returns `index.html` for any other path (deep
  links).
- API app `/api/flightdeck` (R4).
- Both apps are in the namespace FlightDeck is installed into (`USER` in the container).

**Rationale**: CSP static file serving has no single-page-app fallback, so deep links like
`/flightdeck/security/tls` would 404.

## R13. Installation: one IPM module, two entry paths

**Decision**:
- **Package**: `module.xml` at the repo root, IPM module `iris-flightdeck`.
  - It declares the ObjectScript sources, the prebuilt `web/` directory as a `FileCopy` resource,
    and two `WebApplication` elements: `/flightdeck` (SPA, R12) and `/api/flightdeck` (API, R4).
    Both use `MatchRoles=":FlightDeck_Runtime"`.
  - Its `<Invoke>` runs `FlightDeck.Install.Installer.Run(demo)`, which:
    1. creates the `FlightDeck_Runtime` role (`%DB_<install namespace db>:R`) through
       `PUT /v2/security/role` in-process;
    2. verifies both web apps through `GET /v2/web-app`;
    3. runs demo provisioning only if `demo = 1`.
  - Every step is idempotent. Failures raise `FLIGHTDECK INSTALL FAILED: <step>: <IRIS error
    text>`.
- **Compose** (`docker compose up -d`): one service `iris`.
  - Image built by a single-stage `Dockerfile`: `FROM ${IRIS_IMAGE:-intersystemsdc/iris-community:2026.2-zpm}`
    copies `module.xml`, `backend/`, `docker/` and the **committed prebuilt `frontend/dist`**.
    *Changed during implementation:* a Node build stage timed out fetching from the npm registry
    inside `docker build`. An evaluator's install must not depend on npm, so the static assets are
    committed and `scripts/build/check-dist.sh` rebuilds and compares them.
  - Named volume `flightdeck-data` with `ISC_DATA_DIRECTORY=/durable/iris` (never a bind mount
    from `/mnt/d`).
  - Ports: `${FLIGHTDECK_PORT:-52780}:52773`.
  - Entrypoint override from R2 with `-a /opt/flightdeck/docker/first-start.sh`. That script:
    1. unexpires default passwords (R3);
    2. runs `zpm "load /opt/flightdeck -DDemo=1"` in namespace `USER`;
    3. prints `FlightDeck is ready at http://localhost:${FLIGHTDECK_PORT}/flightdeck/ — sign in
       with the default account documented in the README`.
  - A marker in the durable volume skips reinstall on restart. Compile errors are echoed by IPM
    to stdout, so they show in `docker compose logs iris` (FR-041).
  - IRIS for Health: `IRIS_IMAGE=intersystemsdc/irishealth-community:2026.2-zpm docker compose up
    -d --build`. Same procedure (FR-045).
- **IPM on an existing instance**: `zpm "install iris-flightdeck"` from a registry, or
  `zpm "load <path>"`. Demo is off unless `-DDemo=1` is passed (FR-043).

**Rationale**: One install code path for both entry points. The web apps are declared the way
IPM packages normally declare them, and FlightDeck's own objects (role, demo) go through the
official API.

**Alternatives considered**: A dedicated `FLIGHTDECK` namespace created at first start was
rejected. Creating it through `/v2/namespace` needs FlightDeck's client code loaded somewhere
first (a bootstrap namespace), which adds a second install path for no user benefit.

## R14. Demo provisioning through the official API (Constitution I)

**Decision**: `FlightDeck.Install.Demo` runs as the installing user (`_SYSTEM` in the container).
It creates everything **through `FlightDeck.Admin.Client` in-process calls to `/v2/*`**, never
through `Security.*` or `Config.*` classes:
- Resources `FD_Demo_Reports`, `FD_Demo_Billing` (`PUT /v2/security/resource`).
- Roles `FD_Demo_Operator`, `FD_Demo_Auditor` (`PUT /v2/security/role`).
- Web app `/csp/fd-demo` with unauthenticated access enabled, so later features show the exposure
  warning (`PUT /v2/web-app`).
- Three tasks: daily no-op, weekly no-op, and one no-op that always fails (`POST /v2/task`, class
  `FlightDeck.Demo.NoopTask`).
- Wallet collection `FD_Demo_Vault` with **no secrets** (`PUT /v2/wallet/collection`), skipped with
  a logged reason if `/v2/wallet` is absent.

Objects use the prefix `FD_Demo` / `fd-demo` so palette search can find them (FR-044a). Re-runs
are idempotent: an object is created only when its `GET` returns 404.

**Installer bootstrap (Constitution I v2.0.0 scope; listed in plan Complexity Tracking)**:
- IPM loads and compiles the code.
- IPM declares FlightDeck's own two web applications through `WebApplication` elements, not
  `PUT /v2/web-app`. Creating the portal's own entry points over HTTP before the portal exists
  would add a failure mode to the install path.
- The container path unexpires the image's default passwords (R3). There is no v2 operation for
  this.

Everything else the installer creates goes through the official API: the `FlightDeck_Runtime`
role and every demo object.

## R15. Palette entity search

**Decision**: `GET /api/flightdeck/v1/palette/entities?q=&domain=&limit=`.
`FlightDeck.Palette.Search` derives the searchable set from the capability spec: `GET` list
operations with no required parameters, mapped to a domain by path family (table in
`data-model.md`). For each one the user is allowed to call, it runs an in-process call with
`maxRows` = limit and the `filter` query parameter when the operation declares one, and otherwise
filters `Name` server-side. Disallowed families are returned as a group with `state: "forbidden"`
and the missing privilege. The deadline is 1,500 ms per request: families not finished come back
as `state: "timeout"`, the response gets `degraded: true`, and results already gathered are
kept. Ranking: exact name > prefix > substring, then by domain order. The client debounces
250 ms and cancels stale queries.

Local actions (FR-023) are built on the client from the route table and from mutating operations
in the capability map returned by `GET /session/capabilities`.

## R16. Session expiry and restore (FR-016, FR-017, FR-017a)

**Decision**:
- Any API 401 on a request that previously succeeded marks the session `expired`. The shell
  shows the sign-in overlay above the current screen; the route, tab, selection and form drafts
  stay in memory because the page never navigates.
- On re-authentication, `POST /session` is sent, then the client invalidates **all** cached
  queries and bumps a `computationEpoch`. Any component holding computed state (the fixture form's
  diff now, the UC10 diff later) must recompute and block confirmation until its value carries the
  new epoch.
- The fixture route `/flightdeck/__fixtures__/reauth` is compiled only when
  `import.meta.env.MODE === "fixtures"`, so it is absent from the production bundle, which a build
  test verifies.
