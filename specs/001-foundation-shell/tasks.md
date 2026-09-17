---

description: "Task list for feature 001: FlightDeck Foundation and Shell"
---

# Tasks: FlightDeck Foundation and Shell

**Input**: Design documents from `/specs/001-foundation-shell/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (flightdeck-api.openapi.json,
verification-report.schema.json, ui-shell.md), quickstart.md

**Tests**: Included where a spec success criterion or verbatim Gherkin scenario can only be proven
by an automated check (SC-001 to SC-010, quickstart §1 to §5). No test-first ordering is imposed.

**Organization**: Grouped by user story. Priority order is US1 (P1), US2 (P1), US3 (P2), US4 (P2),
US5 (P3). A minimal routed app frame is foundational, so US3 and US5 can proceed independently
once US2 exists.

**Supersedes**: the previous tasks.md for this directory, which was generated from spec revision 1.
Its `[X]` marks had no code behind them.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on incomplete tasks)
- **[Story]**: US1 to US5 from spec.md
- Paths follow plan.md → Project Structure

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repository skeleton, tooling, generated inputs

- [X] T001 Initialize the git repository (branch `001-foundation-shell`) and create the plan.md directory skeleton: `backend/cls/FlightDeck/{API,Admin,Capability,Palette,Vitals,UI,Install,Demo}`, `backend/test/FlightDeck/Test`, `frontend/`, `scripts/{build,verify/probes,dev}`, `docker/`, `verification/`
- [X] T002 [P] Add root `.gitignore` (node_modules, dist, frontend/test-results, *.log, scratch), `.dockerignore` (node_modules, .git, specs, verification), `.editorconfig` (LF, 2-space for ts/json, tab for .cls), and extend `.gitattributes` so `*.sh`, `*.cls`, `*.py` are `eol=lf`
- [X] T003 [P] Add `LICENSE` (MIT, 2026, Carlos Eduardo Dias Duarte)
- [X] T004 Scaffold `frontend/` with Vite 6 + React 18 + TypeScript 5 strict: `frontend/package.json` (scripts `dev`, `build`, `build:fixtures` = `vite build --mode fixtures`, `test`, `e2e`, `lint`, `check:tokens`, `contrast`), `frontend/tsconfig.json`, `frontend/index.html`, `frontend/vite.config.ts` with `base: '/flightdeck/'`, `server.watch.usePolling: true`, and a proxy of `/api/flightdeck` to `http://localhost:${FLIGHTDECK_PORT:-52780}`
- [X] T005 Install frontend dependencies in `frontend/package.json`: react-router-dom 6, @tanstack/react-query 5, cmdk 1, @radix-ui/react-dialog, @radix-ui/react-tooltip, @radix-ui/react-tabs, @radix-ui/react-visually-hidden, @fontsource/ibm-plex-sans, @fontsource/ibm-plex-mono; dev: vitest, @testing-library/react, @testing-library/user-event, jsdom, @playwright/test, @axe-core/playwright, eslint 9 + typescript-eslint + eslint-plugin-react-hooks
- [X] T006 [P] Configure `frontend/eslint.config.js`: ban `fetch` outside `src/api/client.ts`; ban `localStorage`/`sessionStorage`/`indexedDB`/`document.cookie` outside `src/prefs/storage.ts`; ban hex/rgb/hsl string literals in `src/**/*.{ts,tsx}`
- [X] T007 [P] Create `scripts/build/gen-capability-spec.py`. It reads `docs/sysadmin-api-v2.json` and `docs/api-coverage.md` (domain from each `## N.` heading, operations from the table rows beneath it) and writes `backend/cls/FlightDeck/Capability/Spec.cls` with XData `Operations` (JSON array of `{operationId:"<METHOD> <path>", method, path, domain, summary, requires[], mutating}`). It exits non-zero if any spec operation is unassigned or assigned twice, or if domain counts are not shell 5 / web-apps 8 / permissions 31 / security 89 / tasks 24 / system 102 / logs 14 (total 273). `requires` comes from the summary prefix regex `^\((%Admin_\w+:U)( or %Admin_\w+:U)*\)`. `mutating` is `method != GET` except POST `/v2/security/audit/records`, `/v2/journal/file/records` and `/v2/database-dir/info`
- [X] T008 Run `python3 scripts/build/gen-capability-spec.py` and commit the generated `backend/cls/FlightDeck/Capability/Spec.cls`. Add `scripts/build/check-generated.sh`, which regenerates to a temp file and diffs

---

## Phase 2: User Story 1 - Verify what the platform supports (Priority: P1) 🎯 MVP

> Delivery rule from the spec: the verification script ships **before any screen**, so US1 runs
> before the Foundational phase and depends only on Setup.

**Goal**: One script runs the 8 PRD §14 probes in order, never aborts, classifies each probe, records
raw errors, writes a schema-valid report, and exits 1 on any inconclusive result.

**Independent Test**: `scripts/verify/run-both-images.sh` produces two schema-valid reports; the
fault-injection run still lists 8 probes and exits 1 (quickstart §1).

- [X] T009 [P] [US1] Create probe class `scripts/verify/probes/FDVerify.InProcess.cls` (`%CSP.REST`, `UseSession=1`) with routes `GET /whoami` → `{user, roles, namespace}` and `GET /admin/(.*)`, which runs `new $namespace set $namespace="%SYS"` then `##class(%Api.Admin).DispatchRequest("/"_path,"GET",1)` (research R4)
- [X] T010 [P] [US1] Create probe class `scripts/verify/probes/FDVerify.Loopback.cls` with route `GET /admin/(.*)`, which forwards the incoming `CSPSESSIONID*` cookies through `%Net.HttpRequest` to `127.0.0.1:52773/api/admin/<path>` and returns the upstream status and body verbatim
- [X] T011 [P] [US1] Create probe class `scripts/verify/probes/FDVerify.Files.cls` with class method `Report()`. It writes JSON with: `messages.log` path (`$system.Util.ManagerDirectory()_"messages.log"`) and its last line; `alerts.log` path and existence; whether `Ens.Util.Log` exists; and namespaces where `##class(%Library.EnsembleMgr).IsEnsembleNamespace()` is true
- [X] T012 [US1] Implement `scripts/verify/verify_platform.py` (Python 3 stdlib only):
  - CLI `--base-url`, `--container`, `--label`, `--out` (default `verification/<product>-<version>.json`); credentials from `FD_VERIFY_USER`/`FD_VERIFY_PASSWORD` (default `_SYSTEM`/`SYS`), never written anywhere.
  - Each probe runs in `try/except` with a 30 s timeout, in order 1 to 8, with keys `admin_api`, `auth_path`, `resource_shapes`, `async_db_metrics`, `wallet`, `mgmnt_api`, `log_sources`, `audit_enabled`.
  - `raw` is capped at 8192 chars with `Authorization` values redacted. `raw` is required whenever the classification is not `confirmed_present`.
  - `FD_VERIFY_FAULT=<n>` raises inside probe n.
  - Writes the report per `contracts/verification-report.schema.json` and prints a table.
  - Exit code: 1 if any `inconclusive`, 2 on usage error, else 0.
- [X] T013 [US1] Implement probes 1, 5, 6 and 8 in `scripts/verify/verify_platform.py`:
  - **Probe 1** `GET /api/admin/info`: present if 200 with `apiVersion >= 2`; absent on 404 or `apiVersion < 2` (record `serverVersion`); otherwise inconclusive.
  - **Probe 5** `GET /api/admin/v2/wallet/collections`: 200 present; 404 absent.
  - **Probe 6** `GET /api/mgmnt/`: 200 with a JSON array present, `finding.serviceCount`.
  - **Probe 8** `GET /api/admin/v2/security/audit/enabled`: 200 present with `finding.enabled`.
- [X] T014 [US1] Implement probe 2 in `scripts/verify/verify_platform.py`. Candidates in order `in_process`, `jwt`, `loopback_proxy`:
  - **in_process**: copy and load `FDVerify.InProcess.cls` into `USER` via `docker exec <container> iris session IRIS -U USER`; create web app `/fdverify-inproc` (Password auth, namespace USER) via `iris session -U %SYS`; authenticate once with Basic and a cookie jar; call `/whoami` and `/admin/v2/security/roles?maxRows=1` with the cookie only. Present if both are 200 and whoami's user matches.
  - **jwt**: `POST /api/admin/login` with body `{"user","password"}`, then `GET /info` with Bearer. 404 is absent.
  - **loopback_proxy**: same pattern with `FDVerify.Loopback`.
  - Always delete the probe web apps and classes in `finally`.
  - Probe classification and `finding.selected` per data-model §1.
- [X] T015 [US1] Implement probe 3 in `scripts/verify/verify_platform.py`: `GET /api/admin/v2/monitor/dashboard/system-resources` and `GET /api/admin/v2/monitor/system-usage/shared-memory`. Record the key sets of the first item as `sampleKeys`, and `matchesSpec` per schema (`SystemResourcesStats` keys `Name, Seize, Nseize, Aseize, Bseize, BusySet`; `SharedMemoryUsage` keys `Description, SMHAllocated, SMHAvailable, SMHUsed, SMTUsed, GSTUsed, AllUsed`). Present when both are 200 arrays; inconclusive when a shape mismatches (raw holds the actual sample)
- [X] T016 [US1] Implement probe 4 in `scripts/verify/verify_platform.py`: `GET /api/admin/v2/database-dirs?maxRows=1` to pick a directory, then `POST /api/admin/v2/database-dir/info` with that directory (expect 202 with a task id), then poll `GET /api/admin/v2/async-result` every 500 ms up to 60 s. Record `pollCount`, `latencyMs` and `resultKeys`. Present when a completed result contains any of `DiskFree`, `AvailableSpace`, `Full`
- [X] T017 [US1] Implement probe 7 in `scripts/verify/verify_platform.py`: load and run `FDVerify.Files` via `docker exec`, and also `docker exec <container> tail -n 1 <path>`. Present when the messages.log path exists and the interop query class exists; absent if `Ens.Util.Log` is missing; clean up afterward
- [X] T018 [P] [US1] Create `scripts/verify/validate_report.py`: a stdlib structural validator for `contracts/verification-report.schema.json` rules (8 probes in order, one classification each, raw present when not confirmed_present, probe 2 has 3 candidates, counts sum to 8, exitCode consistent). Exit 1 on violation
- [X] T019 [P] [US1] Create `scripts/verify/test_verify_platform.py` (unittest). It covers classification aggregation for probe 2, exit code logic, `raw` redaction of `Authorization: Basic …`, and a fault in probe n still yielding 8 results. It uses fake probe functions and needs no container
- [X] T020 [US1] Create `scripts/verify/run-both-images.sh`. For each image `intersystemsdc/iris-community:2026.2-zpm` and `intersystemsdc/irishealth-community:2026.2-zpm`:
  1. `docker run -d --entrypoint /tini <image> -- /iris-main --check-caps false` on a free port (R2);
  2. wait for `iris qlist` to show running;
  3. run `Security.Users.UnExpireUserPasswords("*")` (R3);
  4. run `verify_platform.py`, then `validate_report.py`;
  5. `docker rm -f`.

  Exit with the max exit code
- [X] T021 [US1] Run `scripts/verify/run-both-images.sh` and commit `verification/iris-2026.2.json` and `verification/irisforhealth-2026.2.json`. **Gate**: both show probe 2 `finding.selected == "in_process"`. Record any inconclusive probe and the area it blocks in `verification/README.md`, and update research.md R8 with the probe 3/4 shapes

**Checkpoint**: The platform report exists on both images, and the US2 session design is final.

---

## Phase 3: Foundational (Blocking Prerequisites for US2 to US5)

**Purpose**: Backend router and API client, frontend API client, theme tokens, safe-mode store, routed frame.

**⚠️ CRITICAL**: Starts after T021's gate passes.

- [X] T022 Create `backend/cls/FlightDeck/Admin/Client.cls`, class method `Call(method As %String, path As %String, query As %String = "", body As %DynamicObject = "", Output status As %Integer, Output result As %DynamicAbstractObject, Output raw As %String) As %Status`. It saves `%request`/`%response`, builds a fresh `%CSP.Request` (method, URL `/api/admin<path>`, query data, JSON content stream) and a fresh `%CSP.Response`, sets `new $namespace set $namespace="%SYS"`, redirects output to a `%Stream.TmpCharacter` via `%Library.Device` redirect (or a temp file per research prototype), calls `##class(%Api.Admin).DispatchRequest(path, method, 1)`, parses JSON and returns `status` as an integer. Callers' `%request`/`%response`/`$namespace` are always restored in `finally`
- [X] T023 Create `backend/cls/FlightDeck/API/Response.cls`: `WriteJSON(obj, status=200)`, `WriteError(httpStatus, code, message, raw="", requires="", detectedVersion="")` with the envelope from `contracts/flightdeck-api.openapi.json#/components/schemas/Error` (codes `UNAUTHORIZED`, `INVALID_CREDENTIALS`, `SAFE_MODE_ON`, `MISSING_TAB_ID`, `UNSUPPORTED_VERSION`, `NO_ADMIN_PRIVILEGE`, `UPSTREAM_ERROR`, `BAD_REQUEST`), and `Messages` constants with the exact §9 texts 1, 2, 3, 8, 19
- [X] T024 Create `backend/cls/FlightDeck/API/Router.cls` (`%CSP.REST`, `UseSession=1`, `HandleCorsRequest=0`, `CHARSET="utf-8"`). UrlMap routes: `POST|GET|DELETE /v1/session` → `FlightDeck.API.Session`, `GET /v1/session/capabilities` → `FlightDeck.API.Capabilities`, `GET /v1/vitals` → `FlightDeck.API.Vitals`, `GET /v1/palette/entities` → `FlightDeck.API.Palette`, `GET /v1/openapi.json` → `FlightDeck.API.OpenAPI`. The guard runs in `OnPreDispatch`, which `%CSP.REST.DispatchRequest` calls **before** `DispatchMap` resolves any route (verified in the IRIS 2026.2 source; `DispatchRequest` itself is `Final` and cannot be overridden). A mutating request to an unknown path or method is therefore also rejected with 403, not 404/405. `GuardDecision(method, path, tabHeader, safeHeader)` is a class method:
  - (a) no `X-FlightDeck-Tab` header, except `GET /v1/openapi.json` → 400 `MISSING_TAB_ID`;
  - (b) method in POST/PUT/PATCH/DELETE, not in allowlist {`POST /v1/session`, `DELETE /v1/session`}, and header `X-FlightDeck-Safe-Mode` ≠ `disarmed` → 403 `SAFE_MODE_ON` with message 3, returned before any routing or handler runs.
- [X] T025 Create `backend/cls/FlightDeck/API/OpenAPI.cls` whose XData holds `specs/001-foundation-shell/contracts/flightdeck-api.openapi.json` verbatim, and extend `scripts/build/gen-capability-spec.py` (or a sibling `scripts/build/gen-openapi-cls.py`) to generate it. Route handler returns it with `application/json`
- [X] T026 Create `module.xml` (IPM module `iris-flightdeck`, version 0.1.0). The two `WebApplication` elements are the **installer bootstrap exception** from Constitution I v2.0.0, recorded in plan Complexity Tracking. Nothing else in the module may create IRIS objects outside the official API:
  - resources `FlightDeck.PKG` from `backend/cls`; `FileCopy` of `frontend/dist/` to `${mgrdir}flightdeck/web/`.
  - WebApplication `/api/flightdeck` (DispatchClass `FlightDeck.API.Router`, `AutheEnabled="32"` (Password; IPM ignores `PasswordAuthEnabled`), MatchRoles `:FlightDeck_Runtime`, CookiePath `/api/flightdeck/`).
  - WebApplication `/flightdeck` (DispatchClass `FlightDeck.UI.Static`, `AutheEnabled="64"` (unauthenticated static assets), MatchRoles `:FlightDeck_Runtime`).
  - UnitTest resource `backend/test`.
  - `<Invoke Class="FlightDeck.Install.Installer" Method="Run"><Arg>${Demo}</Arg></Invoke>` with Default `Demo=0`.
- [X] T027 Create `backend/cls/FlightDeck/Install/Installer.cls` `Run(demo As %Boolean = 0)`, the minimal version for foundational work. First, check the version floor: `Admin.Client` `GET /info`; if `apiVersion < 2`, print `FLIGHTDECK INSTALL FAILED: version: Requires IRIS 2026.2 (detected <serverVersion>)` and return an error before any other step (FR-012a, quickstart §3). Then ensure role `FlightDeck_Runtime` exists with resource `%DB_<routine db of $namespace>:R` via `FlightDeck.Admin.Client` `PUT /v2/security/role` (GET first, idempotent). Print `FlightDeck: role FlightDeck_Runtime <created|exists>`. On any error, write `FLIGHTDECK INSTALL FAILED: role: <IRIS error text>` and return the error status
- [X] T028 [P] Create `backend/cls/FlightDeck/UI/Static.cls` (`%CSP.REST`, `UseSession=0`). `GET /(.*)` serves files from `##class(%File).NormalizeDirectory($system.Util.ManagerDirectory()_"flightdeck/web")` with content types for html/js/css/woff2/svg/json, `Cache-Control: public, max-age=31536000, immutable` for `/assets/*`, `no-cache` for `index.html`, and `index.html` for any path without a matching file. It rejects `..` path traversal with 404
- [X] T029 [P] Create `backend/test/FlightDeck/Test/AdminClient.cls` (%UnitTest). It asserts `Call("GET","/info")` returns status 200 with `result.apiVersion >= 2`, that the caller's `$namespace` and `%response` object identity are unchanged afterwards, and that `/v2/processes?maxRows=1` returns 200 (the namespace switch works)
- [X] T030 [P] Create `backend/test/FlightDeck/Test/RouterGuards.cls` (%UnitTest). It asserts that the router's UrlMap routes, with the leading `/v1` stripped, equal the path+method set in the `FlightDeck.API.OpenAPI` XData, whose server URL is `/api/flightdeck/v1` (parity, R9) and that `GuardDecision(method, path, tabHeader, safeHeader)` returns `SAFE_MODE_ON` for PUT/POST/DELETE with armed, missing or bogus values, allows `POST /v1/session` and `DELETE /v1/session`, returns `SAFE_MODE_ON` for a mutating method on a path that has no route (for example `PATCH /v1/nothing`), and returns `MISSING_TAB_ID` without a tab header
- [X] T031 Create `frontend/src/theme/tokens.css` with the exact `docs/design.md` §3.1 values:
  - Color custom properties on `:root[data-theme="dark"]` and `:root[data-theme="light"]`: surface-canvas/panel/float, line-hairline/strong, text-primary/secondary/muted, and state-actual/commanded/caution/warning/selected using the per-theme variants.
  - Spacing scale 4/8/12/16/24/32/48.
  - Radii 0/2px/6px.
  - Floating shadow `0 16px 48px rgba(0,0,0,.55)`.
  - Motion 120ms/90ms, `cubic-bezier(.2,0,0,1)`.
  - A `@media (prefers-reduced-motion: reduce)` block zeroing durations.
  - Font faces imported from `@fontsource` (latin 400/500).

  No utility framework (research R10): components use per-component CSS referencing only these custom properties
- [X] T032 [P] Create `frontend/scripts/check-tokens.mjs`. It fails if any file under `frontend/src` except `theme/tokens.css` contains `#[0-9a-fA-F]{3,8}\b`, `rgb(`, `rgba(` or `hsl(`; any px value for padding/margin/gap/inset outside 0/4/8/12/16/24/32/48 or border-radius outside 0/2px/6px in `.css` files; any `transition`/`animation` duration over 200ms; any `text-transform: uppercase`
- [X] T033 [P] Create `frontend/src/theme/ThemeProvider.tsx`: sets `data-theme` on `<html>`. Before sign-in it follows `prefers-color-scheme` (live listener). After sign-in it uses `prefs.getTheme(username)` if set. `setTheme` persists via `src/prefs/storage.ts`
- [X] T034 [P] Create `frontend/src/prefs/storage.ts`, the only storage module. It exports `getTheme/setTheme` (key `flightdeck:theme:<username>`, values `"dark"|"light"`) and `getRecent/pushRecent` (key `flightdeck:recent:<username>`, max 8, dedupe by id, most recent first, fields `id,label,domain,kind,usedAt` only). Every access is wrapped in try/catch returning defaults
- [X] T035 Create `frontend/src/session/safeMode.ts`: an in-memory store (module variable plus subscribers) with `getSafeMode(): "armed"|"disarmed"` initialized to `"armed"` at module load, `arm()`, `disarm()`, `subscribe()`, and hook `useSafeMode()`; also `tabId = crypto.randomUUID()` generated at module load. No storage or URL access
- [X] T036 Create `frontend/src/api/client.ts`, the sole `fetch` wrapper:
  - Base `/api/flightdeck/v1`, `credentials: "same-origin"`.
  - Always sends `X-FlightDeck-Tab` and `X-FlightDeck-Safe-Mode` from `safeMode.ts`.
  - Parses the error envelope into `ApiError {status, code, message, raw, requires, detectedVersion}`.
  - A 401 on any call except `POST /session`, while the session state is `active`, invokes the registered `onSessionExpired()` callback.
  - `signIn(username, password)` builds `Authorization: Basic` in a local variable only, never logs it, and never retains the arguments.
  - **Any 401 response to `POST /session` becomes `ApiError{code:"INVALID_CREDENTIALS", message: <§9 message 1>}`, whatever the body** (U1).
- [X] T037 [P] Create `frontend/test/safeMode.test.ts`. It asserts the initial state is `armed` on a fresh module import (`vi.resetModules`), that `disarm()` then a re-import yields `armed`, that the store never touches `window.localStorage`, `sessionStorage` or `document.cookie` (spies), and that `client.ts` sends the headers
- [X] T038 Create `frontend/src/shell/domains.ts` (six domains in fixed order: `web-apps` "Web applications and APIs", `permissions` "Permissions", `security` "Security and secrets", `tasks` "Tasks", `system` "System", `logs` "Logs", each with an icon component name) with the exact section lists (kept in the same module as `DOMAINS`, no separate `sections.ts`) and order from spec.md Assumptions (Logs has a single section `stream`)
- [X] T039 Create the routed frame `frontend/src/main.tsx`, `frontend/src/App.tsx` and `frontend/src/routes.tsx`:
  - `BrowserRouter basename="/flightdeck"`, `QueryClientProvider`, `ThemeProvider`, `SessionProvider` placeholder.
  - Routes `/`, `/:domain` (redirect to the first section), `/:domain/:section`, a not-found empty state, and `/__fixtures__/reauth` only when `import.meta.env.MODE === "fixtures"`.
  - Layout slots `Glareshield`, `Rail`, `Work` rendered as plain containers (styled in US5).

- [X] T040 [P] Create `backend/cls/FlightDeck/Demo/NoopTask.cls` extending `%SYS.Task.Definition` with property `Fail As %Boolean`: `OnTask()` returns `$$$OK`, or `$$$ERROR($$$GeneralError,"FlightDeck demo task failure (expected)")` when `Fail=1`
- [X] T041 Implement `backend/cls/FlightDeck/Install/Demo.cls` `Provision()`. It is foundational because US3's palette e2e (UC02 scenario 2) and US4's install both depend on demo data (analysis I1). Constitution I: no `Security.*`/`Config.*` here. Every create goes through `FlightDeck.Admin.Client`, and each object is `GET` first (404 → create; 200 → `exists`). Objects:
  - resources `FD_Demo_Reports`, `FD_Demo_Billing` (`PUT /v2/security/resource`, public permission none);
  - roles `FD_Demo_Operator` (resources `FD_Demo_Reports:RW`) and `FD_Demo_Auditor` (`FD_Demo_Reports:R`, `FD_Demo_Billing:R`) (`PUT /v2/security/role`);
  - web app `/csp/fd-demo` (namespace = current, enabled, **unauthenticated access enabled**, no dispatch class, description "FlightDeck demo: intentionally unauthenticated") via `PUT /v2/web-app`;
  - tasks "FD Demo daily no-op" (daily 02:00), "FD Demo weekly no-op" (Sunday 03:00) and "FD Demo failing task" (hourly, `Fail=1`), class `FlightDeck.Demo.NoopTask`, namespace current (`POST /v2/task`);
  - wallet collection `FD_Demo_Vault` with **no secrets** (`PUT /v2/wallet/collection`). If `/v2/wallet/collections` returns 404, mark it `skipped` with reason "Wallet API not available on this instance".

  Log one line per object: `FlightDeck demo: <kind> <name> <created|exists|skipped (reason)>`. The run is idempotent

**Checkpoint**: The backend router answers with guards, the SPA serves routes, tokens compile, and safe mode is in memory.

---

## Phase 4: User Story 2 - Authenticate and start every session in safe mode (Priority: P1)

**Goal**: Sign in with an IRIS credential through the in-process path. The session opens armed, capabilities come from the spec, nothing is stored, and expiry restores in place.

**Independent Test**: quickstart §3. `npm run e2e -- --project=session`, the fixtures project, `scripts/dev/check-safe-mode-enforcement.sh`, and the manual storage audit.

- [X] T042 [US2] Implement `backend/cls/FlightDeck/API/Session.cls`:
  - **POST**: call `Admin.Client` `GET /info`.
    - 403 from upstream (no %Admin privilege) → call `%session.Logout()`, set `%session.EndSession=1`, respond 403 `NO_ADMIN_PRIVILEGE` with `requires` = every `%Admin_*:U` and message 2.
    - `apiVersion < 2` → end the session and respond 403 `UNSUPPORTED_VERSION` with message 8 "…Requires IRIS 2026.2." and `detectedVersion`.
    - Otherwise 200 Session per data-model §2: `authPath:"in_process"`, `instance.version` parsed from `serverVersion` with `/\d{4}\.\d+/` for display only, `instance.namespace` = the current `$namespace`, privileges normalized to `%Admin_<Key>`, `capabilitySummary` from `FlightDeck.Capability.Map`.
  - **GET**: same body.
  - **DELETE**: `%session.Logout()`, `EndSession=1`, 204.

  IRIS rejects invalid credentials **before** dispatch, so the handler cannot shape that response and does not try to. The contract is that **any** 401 on `POST /v1/session` means invalid credentials; the frontend maps it (T036, T048). Verify with `curl -si -u nobody:wrong -X POST …/session -H 'X-FlightDeck-Tab: t' -H 'X-FlightDeck-Safe-Mode: armed'` and with a real user plus a wrong password: both return 401, and the status line and headers are identical apart from Date. Record in `verification/README.md`.
  - **FR-012a**: when `/info` reports `apiVersion < 2`, or `GET /v2/web-apps` through `Admin.Client` returns 404, end the IRIS session (`%session.Logout()`, `EndSession=1`) and return 403 `UNSUPPORTED_VERSION`, message 8 "Not available on this IRIS version or edition. Requires IRIS 2026.2.", and `detectedVersion` = `/info.serverVersion` verbatim.
- [X] T043 [US2] Implement `backend/cls/FlightDeck/Capability/Map.cls`: `Build(privileges As %DynamicObject) As %DynamicArray` over `FlightDeck.Capability.Spec` XData.
  - `allowed` = `requires` empty OR any `requires[i]` has `privileges.<%Admin_X>.use = true`.
  - `reason` = null if allowed, else "Requires Use on %Admin_Secure. Ask your instance administrator for access." or, for OR lists, "Requires Use on %Admin_Manage or %Admin_Operate. Ask your instance administrator for access.".
  - A privilege key absent from `/info` counts as not held.
  - `Summary()` returns `{allowed,total}`.
- [X] T044 [US2] Implement `backend/cls/FlightDeck/API/Capabilities.cls` `GET /v1/session/capabilities` → `{entries: CapabilityEntry[]}` using a fresh `/info` call
- [X] T045 [P] [US2] Create `backend/test/FlightDeck/Test/CapabilityMap.cls` (%UnitTest). It asserts 273 entries; unique operationIds; domain counts 5/8/31/89/24/102/14; `GET /v2/security/roles` not allowed for `{%Admin_Operate:{use:true}}` with the exact reason text; `GET /v2/databases` allowed with only Operate (OR semantics); `/info` always allowed; `mutating=false` for `POST /v2/security/audit/records`
- [X] T046 [US2] Verify research R4 open items on a running container and record the results in `verification/README.md`:
  - (a) in-process session and privileges on IRIS for Health 2026.2;
  - (b) no `WWW-Authenticate: Basic` on 401 from `/api/flightdeck/v1/session` (`curl -si`), and no native browser auth dialog in Chromium/Firefox during the e2e invalid-credential test. **If the header is present**, apply the fallbacks in order and re-check after each:
    1. set the `/api/flightdeck` web app's `LoginPage` to a class that returns the JSON 401 without a challenge;
    2. add an unauthenticated pre-check route in a third minimal web app (`/api/flightdeck-auth`, `UnauthenticatedEnabled`, no data access) that validates credentials by in-process `$SYSTEM.Security.Login` into the target session group and returns a JSON 401 without a challenge.

    **If neither removes the dialog, stop and ask the author.**
  - (c) a `%Operator`-only user reaches `GET /api/flightdeck/v1/session` with 200 via `MatchRoles=:FlightDeck_Runtime`, with no public DB grant.

  Fix `module.xml`/`Installer.cls` if (c) fails
- [X] T047 [US2] Create `frontend/src/session/SessionProvider.tsx`:
  - State machine per data-model §2 (`signed_out` | `active` | `expired`).
  - On mount, `GET /session` (200 → active, 401 → signed_out).
  - `signIn(u,p)` → `client.signIn`, then fetch `/session/capabilities`. The username is kept; the password is never stored.
  - Registers `onSessionExpired` → `expired`.
  - `reauthenticate(u,p)`: on the same username, increment `computationEpoch` and `queryClient.invalidateQueries()`; on a different username, full reset including `safeMode.arm()`.
  - `signOut()` → `DELETE /session`, `safeMode.arm()`, clear memory.
  - Exposes `useSession()`, `useCapabilities()`, `useCapability(operationId)`.
- [X] T048 [US2] Create `frontend/src/session/SignIn.tsx`:
  - Full-page sign-in: instance hint text, username and password fields (`autocomplete="username"`/`"current-password"`), Sign in button (achromatic primary).
  - The password field is cleared right after the request resolves.
  - Error mapping: `INVALID_CREDENTIALS` (any 401) → message 1; `NO_ADMIN_PRIVILEGE` → message 2 listing required privileges; `UNSUPPORTED_VERSION` → message 8 followed by "Detected: <detectedVersion>" (FR-012a); other errors show the raw IRIS text verbatim.
  - No spinner (disabled button with "Signing in" label).
- [X] T049 [US2] Create `frontend/src/session/ReauthOverlay.tsx`: a Radix Dialog floating layer (radius 6px, `surface-float`, `line-strong` border, the single shadow) shown when state is `expired`, above the current route without unmounting it. Title "Your session expired". Fields and messages as in SignIn. Focus is trapped, and Escape does not dismiss (the session must be restored or the user signs out)
- [X] T050 [US2] Create `frontend/src/session/SafeModeControl.tsx`: arm/disarm actions (`Turn off safe mode` requires one explicit click in a confirmation popover stating "Changes will be allowed in this tab only."; `Turn on safe mode` is immediate), exported for the glareshield (US5) and the palette (US3)
- [X] T051 [US2] Create `frontend/src/session/CapabilityGate.tsx`: `<CapabilityGate operationId>` renders its child control with `aria-disabled`, tooltip and inline text showing `CapabilityEntry.reason` when not allowed; the child is never hidden
- [X] T052 [US2] Create `frontend/src/home/Home.tsx`, the initial dashboard: instance identity (product label "IRIS" or "IRIS for Health", version, namespace), signed-in user, capability summary "N of 273 operations available to you", a list of the six domains each with its allowed/total count and a `CapabilityGate` example action ("Open"), and the attention-items region as an `EmptyState` ("No attention items yet." / "Attention items appear here as domain screens are added.")
- [X] T053 [US2] Create `frontend/src/fixtures/ReauthFixture.tsx` (fixtures mode only): current `{description}` from the session username; a text input bound to `draft.description` (component state); a computed diff `[{field:"description",before,after}]` stamped with `diffEpoch = computationEpoch`; an **Apply** button disabled while `diffEpoch !== computationEpoch` or the diff is empty; a "Recompute" effect that runs automatically when the epoch changes; and a visible text "Differences recomputed" when that happens (FR-017a)
- [X] T054 [P] [US2] Create `scripts/dev/check-safe-mode-enforcement.sh`: curl sign-in with a cookie jar, then `PUT /api/flightdeck/v1/session`, `POST /api/flightdeck/v1/vitals`, `DELETE /api/flightdeck/v1/palette/entities` and `PATCH /api/flightdeck/v1/nothing` with safe mode armed, missing, and `bogus`. It asserts 403 `SAFE_MODE_ON` (or 400 without a tab), **not** 404/405; this is valid because the guard runs before routing (T024). It exits non-zero otherwise
- [X] T055 [US2] Create `frontend/playwright.config.ts` (projects `session`, `palette`, `shell`, `fixtures`; baseURL `http://localhost:5173/flightdeck/`; webServer `npm run dev` or `dev -- --mode fixtures` per project) and `frontend/e2e/setup/users.ts`, which creates users `fd_e2e_operator` (roles `%Operator`) and `fd_e2e_none` (no roles) through `PUT/POST /api/admin/v2/security/user` with `_SYSTEM`, idempotently
- [X] T056 [US2] Create `frontend/e2e/session.spec.ts` with UC01 scenarios verbatim as test titles:
  1. After sign-in, home shows "Safe mode" in the glareshield indicator, and it is still visible after navigating to 3 routes.
  2. As `fd_e2e_operator`, a Security action on home is `aria-disabled` with "Requires Use on %Admin_Secure".
  3. No `Authorization` header after sign-in (request log); `localStorage` keys only match `flightdeck:(theme|recent):`; `sessionStorage` is empty.
  4. Covered by the fixtures project.
  5. Disarm, then a new page on the same URL shows "Safe mode", and a reload shows "Safe mode". **Parameterized over 20 trials** (SC-002), each alternating new page, reload and a page opened from the disarmed page via `window.open` (the closest Playwright analogue of tab duplication); all 20 must be armed.
  6. Unknown user and wrong password produce identical message 1.
  7. `fd_e2e_none` sees message 2 and no session.
  8. (FR-012a, scenario 7) A route intercept makes `POST /session` return the 403 `UNSUPPORTED_VERSION` body with `detectedVersion` "IRIS for UNIX … 2026.1 (Build 234U)…": message 8 and the detected version are shown, and no shell renders. A live check against `intersystemsdc/iris-community:latest` (2026.1) is recorded manually in `verification/README.md`.
- [X] T057 [US2] Create `frontend/e2e/fixtures.spec.ts`: open `/__fixtures__/reauth`, type "draft text", note "Apply" enabled, `context.clearCookies()`, trigger a request (click "Check server") → the overlay appears, the typed text is still in the input, re-authenticate → "Differences recomputed" is visible, Apply is disabled until recompute completes and then enabled, and the route is unchanged
- [X] T058 [US2] Add a production-bundle check in `frontend/scripts/check-no-fixtures.mjs` (grep `dist/assets/*.js` for `ReauthFixture` and `__fixtures__` → must be absent) and wire it into `npm run build`

**Checkpoint**: UC01 scenarios 1–7 pass; the server rejects mutations from armed tabs.

---

## Phase 5: User Story 3 - Find and act on anything by typing its name (Priority: P2)

**Goal**: The Ctrl/Cmd+K palette on every screen, with local actions and generic server entity search grouped by domain, degrading gracefully and respecting safe mode.

**Independent Test**: quickstart §4, `npm run e2e -- --project=palette`.

- [X] T059 [US3] Implement `backend/cls/FlightDeck/Palette/Search.cls` `Run(q, domain, limit) As %DynamicObject`:
  - Searchable operations are `GET` entries of `FlightDeck.Capability.Spec` whose path has no required parameters and whose response is a list; derive at class compile into a parameter list and keep a unit-tested table of `entityType` labels per list path.
  - Skip families whose capability is not allowed → group `{state:"forbidden", reason}`.
  - Otherwise call `Admin.Client` with `maxRows=limit*4`, plus `filter=q` when the operation declares a `filter` parameter; filter and rank by `Name` (exact > prefix > substring, case-insensitive).
  - Stop at a 1500 ms total deadline; unfinished families → `{state:"timeout"}`, `degraded:true`, `reason:"Some domains did not respond in time."`.
  - Upstream errors → `{state:"error", reason:<IRIS text>}`, `degraded:true`.
  - Each result gets `context` (namespace when present, otherwise entityType) and `target.route` from the domain's first section for that entity type.
- [X] T060 [US3] Implement `backend/cls/FlightDeck/API/Palette.cls` `GET /v1/palette/entities`: validate `q` (1–128 chars) and `limit` (1–20, default 5) → 400 `BAD_REQUEST`; respond `{groups, degraded, reason, totalResults}`
- [X] T061 [P] [US3] Create `backend/test/FlightDeck/Test/PaletteSearch.cls` (%UnitTest). With demo objects present, `Run("FD_Demo",,5)` returns ok groups for roles, resources and wallet collections, each result with non-empty `context` and `target.route`. A simulated forbidden family yields `forbidden` with a reason. Ranking puts an exact match first
- [X] T062 [US3] Create `frontend/src/palette/actions.ts`, `buildActions(capabilities, sections)` returning `ActionEntry[]` per data-model §5a:
  - `nav:home`, `nav:<domain>/<section>` for all sections ("Go to <Domain> / <Section>").
  - `shell:theme-dark`, `shell:theme-light`, `shell:safe-mode-disarm`, `shell:safe-mode-arm`, `shell:sign-out`.
  - `op:<operationId>` for every `mutating` capability, labeled with the official summary, `context` = path, `enabled`/`disabledReason` from the capability, `target` = the owning domain's first section.
- [X] T063 [US3] Create `frontend/src/palette/useEntitySearch.ts`: TanStack Query keyed by `[q, domain]`, 250 ms debounce, AbortController cancellation of stale queries, `enabled` when `q.trim().length >= 1`. Errors or network failures return `{unavailable:true}` and never throw to the UI
- [X] T064 [US3] Create `frontend/src/palette/CommandPalette.tsx` (cmdk inside a Radix Dialog floating layer, 6px radius):
  - Global keydown listener for `Ctrl+K`/`Meta+K` (capture phase, works while other dialogs are open), with the input auto-focused and `performance.mark("palette-open")`/`("palette-input-focused")`.
  - Empty query shows "Recent" from `prefs.getRecent(username)`.
  - Results are grouped by domain in rail order, local actions first and then entity groups. Each item shows label, context (mono for paths and identifiers) and a disabled reason.
  - Entity groups in `forbidden`/`timeout`/`error` state render a one-line reason row.
  - When entity search is unavailable, show message 19 at the top while actions keep working.
  - Overflow: each group shows the top 5 plus "N more — refine to <Domain>", which sets a domain filter chip; the header shows the total result count.
  - No results: "No matches for “q”." plus suggestions listing the six searchable domains and "Keyboard shortcuts: Ctrl+K opens this palette; arrows move; Enter runs; Esc closes."
  - Enter on a disabled item does nothing but announce the reason.
  - Every executed item goes to `prefs.pushRecent`.
- [X] T065 [US3] Implement the safe-mode chaining in `frontend/src/palette/CommandPalette.tsx`: selecting an `op:` entry while `armed` replaces the list with the step "Safe mode is on. Turn it off to make changes in this tab." and two actions, "Turn off safe mode and continue" (calls `safeMode.disarm()` then runs the action) and "Cancel". The action never runs while armed
- [X] T066 [US3] Implement entity selection in `frontend/src/palette/CommandPalette.tsx`: navigate to `target.route` with `?inspect=<entityType>:<name>` (URL-encoded) and close the palette. Mount `<CommandPalette/>` once in `frontend/src/App.tsx` inside the session-active tree
- [X] T067 [US3] Create `frontend/e2e/palette.spec.ts` with UC02 scenarios verbatim as titles:
  1. On home, a domain route and the inspector overlay, Ctrl+K opens with focus in the input, and marks show under 100 ms.
  2. "FD_Demo" gives groups for Permissions and Security with context text on every item.
  3. `page.route('**/palette/entities**', r => r.fulfill({status:500}))` → message 19 visible, and "Go to Tasks" still runs.
  4. Armed + "Delete a role" → disarm step shown; the action does not navigate until "Turn off safe mode and continue".

  Plus: a no-result query shows the suggestions; a forced overflow (limit) shows "more" and the refine chip; recent actions appear on reopen

**Checkpoint**: The palette works on every screen, independently of domain screens.

---

## Phase 6: User Story 4 - Install with one command and land on a populated instance (Priority: P2)

**Goal**: `docker compose up -d` gives a reachable portal with full UC11 demo data on both images; IPM installs without demo by default; errors are legible; README complete.

**Independent Test**: quickstart §2.

- [X] T068 [US4] Extend `backend/cls/FlightDeck/Install/Installer.cls` `Run(demo)`: after the role step, verify both web apps exist through `GET /v2/web-app?name=…`. If `demo=1`, call `Demo.Provision()` (implemented in Foundational). Wrap every step so a failure prints `FLIGHTDECK INSTALL FAILED: <step>: <IRIS error text>` and returns the error (IPM fails loudly). Print `FlightDeck: install complete (demo=<0|1>)`
- [X] T069 [P] [US4] Create `backend/test/FlightDeck/Test/InstallerIdempotency.cls` (%UnitTest). Running `Demo.Provision()` twice gives all `exists` on the second run, with no duplicate tasks (count of tasks named `FD Demo*` is 3) and zero secrets in `FD_Demo_Vault`
- [X] T070 [US4] Create `Dockerfile`:
  - Single stage: `ARG IRIS_IMAGE=intersystemsdc/iris-community:2026.2-zpm`, `FROM ${IRIS_IMAGE}`, `COPY --chown=irisowner` `module.xml`, `backend/`, `docker/` and the committed prebuilt `frontend/dist` to `/opt/flightdeck`. No Node stage: install must not depend on the npm registry (research R13). `scripts/build/check-dist.sh` verifies the committed dist matches a fresh build.
  - `ENV ISC_DATA_DIRECTORY=/durable/iris`.
  - `ENTRYPOINT ["/tini","--","/iris-main","--check-caps","false","-a","/opt/flightdeck/docker/first-start.sh"]`.
  - `HEALTHCHECK` curl of `/flightdeck/`.
- [X] T071 [US4] Create `docker/first-start.sh` (bash, `set -euo pipefail`, LF):
  1. If `/durable/iris/flightdeck.installed` exists, print "FlightDeck already installed." plus the ready line, and exit 0.
  2. Otherwise run `iris session IRIS -U %SYS` with `Security.Users.UnExpireUserPasswords("*")`.
  3. `iris session IRIS -U USER` with `zpm "load /opt/flightdeck -v -DDemo=1"`; detect failure from output (`ERROR`/`FLIGHTDECK INSTALL FAILED`) or exit status and print `FLIGHTDECK INSTALL FAILED: compile/install: <captured lines>`, then exit 1.
  4. Touch the marker.
  5. Print `FlightDeck is ready at http://localhost:${FLIGHTDECK_PORT:-52780}/flightdeck/ — sign in with the default account documented in the README (local evaluation only).`

  Pass `FLIGHTDECK_PORT` through the compose env
- [X] T072 [US4] Create `docker-compose.yml`: service `iris` builds `.` with build arg `IRIS_IMAGE: ${IRIS_IMAGE:-intersystemsdc/iris-community:2026.2-zpm}`, `container_name` not set, `ports: ["${FLIGHTDECK_PORT:-52780}:52773"]`, `environment: [FLIGHTDECK_PORT=${FLIGHTDECK_PORT:-52780}]`, `volumes: [flightdeck-data:/durable]`, `restart: unless-stopped`, named volume `flightdeck-data`. No bind mounts
- [X] T073 [US4] Run the full install on a clean Docker state for both images (`docker compose down -v`, then `docker compose up -d --build`, with `IRIS_IMAGE` set for Health), wait with `scripts/dev/wait-ready.sh` (poll logs for the ready line, 10 min timeout, fail on `FLIGHTDECK INSTALL FAILED`), sign in via curl, and query `GET /api/flightdeck/v1/palette/entities?q=FD_Demo`. Record in `verification/install-runs.md` the timings, the demo object outcomes and whether all 5 kinds were found (SC-005, SC-010)
- [X] T074 [US4] Verify the failure paths and record the outputs in `verification/install-runs.md`: (a) port 52780 busy → capture Docker's exact error line; (b) a deliberate syntax error in a copy of a class → `docker compose logs iris` shows `FLIGHTDECK INSTALL FAILED` with the IRIS compiler text; (c) IPM load on a clean 2026.2 container without `-DDemo=1` → no `FD_Demo*` objects exist
- [ ] T075 [US4] Write `README.md` (English, FR-046):
  - what FlightDeck is (3 lines), with a screenshot placeholder path `docs/img/shell.png`;
  - requirements (Docker 24+, Compose v2, IRIS 2026.2 minimum, and why);
  - Quick start (`git clone`, `docker compose up -d`, the ready line, open the URL, sign in with `_SYSTEM` / `SYS`, a local-evaluation warning);
  - IRIS for Health (one command);
  - port conflict (the exact Docker error from T074 and `FLIGHTDECK_PORT=52790 docker compose up -d`);
  - IPM install (`zpm "install iris-flightdeck"` / `zpm "load <path>"`, demo off by default, `-DDemo=1`);
  - demo objects list;
  - day-1 verification script (purpose, `scripts/verify/run-both-images.sh`, report location, exit codes);
  - safe mode and credentials (nothing stored, per-tab safe mode, server enforcement);
  - troubleshooting (install failure line, `docker compose logs iris`);
  - link to the Ideas Portal idea (the published URL from T091);
  - license

**Checkpoint**: A one-command install works on both images, and the README is complete apart from the idea link.

---

## Phase 7: User Story 5 - Move through a consistent shell (Priority: P3)

**Goal**: Glareshield, rail, tabs, list-plus-inspector and empty states exactly per `docs/design.md` §4/§4.1, in both themes.

**Independent Test**: quickstart §5, `npm run e2e -- --project=shell`, plus the manual §7 review.

- [X] T076 [P] [US5] Implement the native provider `backend/cls/FlightDeck/Native/HostMetrics.cls` (Constitution I v2.0.0 gap, research R8):
  - `CPU(Output pct, Output asOf) As %Status` reads the first `cpu` line of `/proc/stat` with `%Stream.FileCharacter`, where busy = total − (idle + iowait). It compares against the previous sample in `%session.Data("fd.host.cpu")`; if none exists or the sample is younger than 1 s, it takes a second reading after `hang 1`.
  - `Memory(Output pct, Output asOf) As %Status` computes `(MemTotal − MemAvailable)/MemTotal` from `/proc/meminfo`.
  - `Scope()` returns `"Docker host kernel"` when `/.dockerenv` exists or `/proc/1/cgroup` contains `docker`/`containerd`, otherwise `""`.
  - Unreadable file or non-UNIX OS → an error the service maps to reason "Host metrics are not readable on this platform."
  - Callers must check `$SYSTEM.Security.Check("%Admin_Operate","USE")` first.
  - Add `backend/test/FlightDeck/Test/HostMetrics.cls`: values are within 0..100, two consecutive `CPU()` calls both succeed, and the parser handles a fixture `/proc/stat` line.
- [X] T077 [US5] Implement `backend/cls/FlightDeck/Vitals/Service.cls` and `backend/cls/FlightDeck/API/Vitals.cls` `GET /v1/vitals` → exactly **four** Vitals in order per data-model §8:
  - **cpu** and **memory** (`source:"native"`, `scope` from `HostMetrics.Scope()`): without Use on `%Admin_Operate` → unavailable with `requires:"%Admin_Operate:U"`.
  - **shm** (`source:"api"`): `GET /v2/monitor/system-usage/shared-memory`, value = `100*sum(SMHUsed)/sum(SMHAllocated)` using the shape confirmed by probe 3 (T021); 403 → unavailable with `requires:"%Admin_Operate:U"`.
  - **disk** (`source:"api"`): return `%session.Data("fd.vitals.disk")` `{value, asOf}` immediately with `pending:true` while a refresh runs. Refresh = for each `/v2/database-dirs` entry, start `POST /v2/database-dir/info` (async), store task ids in `%session.Data`, and on later calls collect completed results from `GET /v2/async-result`; value = max percent used per the formula fixed by probe 4 (T021); a database with MaxSize 0 uses disk free space.
  - State thresholds: caution ≥ 75, warning ≥ 90, one decimal.
- [X] T078 [P] [US5] Create `frontend/src/shell/EmptyState.tsx`: props `cause` (required), `nextAction` (required, text plus optional action button), `title`; `surface-panel`, radius 0; no illustration, no emoji, no spinner. A dev assertion throws if `cause` or `nextAction` is empty
- [X] T079 [US5] Create `frontend/src/shell/Glareshield.tsx`:
  - Fixed top, height exactly 44px, `surface-panel`, 1px `line-hairline` bottom border, `z-index` above Radix layers.
  - Left: identity "IRIS 2026.2 CE · USER" in 13px (product `iris` → "IRIS", `irisforhealth` → "IRIS for Health"; edition "CE").
  - Center: `<Vitals/>`.
  - Right: `<ThemeToggle/>`, `<SafeModeIndicator/>`, user menu (username, Sign out).
- [X] T080 [US5] Create `frontend/src/shell/SafeModeIndicator.tsx`:
  - Wording and geometry follow `docs/prototype.html`, which prevails over design §4's text for this component (design §10): armed shows a dot + "Safe mode" in `text-secondary` with a `line-strong` 2px-radius border; disarmed shows a `state-warning` dot + "Live — changes enabled" with a `state-warning` border, plus a full-width 2px `state-warning` rule along the glareshield bottom.
  - Clicking opens `SafeModeControl`.
  - `aria-live="polite"` announces changes.
- [X] T081 [US5] Create `frontend/src/shell/Vitals.tsx` and `frontend/src/shell/ThemeToggle.tsx`:
  - Vitals: TanStack Query on `/vitals` every 10 s, `refetchIntervalInBackground:false`, `placeholderData: keepPreviousData`.
  - Four vitals in order CPU, MEM, SHM, DSK. Each vital shows its label (12px `text-secondary`) and value (13px, `tabular-nums`, `text-primary`; caution/warning color plus icon when crossing a threshold). Tooltips: "Host CPU in use", "Host memory in use", "IRIS shared memory heap in use", "Fullest database", each suffixed " (Docker host kernel)" when `scope` is set. SHM is never labeled as host memory.
  - Pending shows the previous value unchanged; the first load shows a fixed-width skeleton bar.
  - Unavailable shows "—" in `text-muted` with a tooltip giving the reason.
  - ThemeToggle: an icon button (sun/moon) with aria-label "Switch to light theme"/"Switch to dark theme".
- [X] T082 [US5] Create `frontend/src/shell/Rail.tsx`:
  - Fixed left below the glareshield, width exactly 56px, `surface-panel`, 1px `line-hairline` right border.
  - Six icon `NavLink`s in `domains.ts` order, each 56×48, SVG icons drawn inline with `currentColor` (no icon font, no emoji).
  - Active item: 2px `state-selected` bar on the inner (right) edge, no background fill.
  - Radix Tooltip label on hover and focus (side right, 6px radius), `aria-label` = domain label.
  - Focus ring 2px `state-selected` offset 2px.
- [X] T083 [US5] Create `frontend/src/shell/WorkHeader.tsx` (the section tab strip is part of it):
  - Title 24px/500 sentence case.
  - SectionTabs render only when `sections.length > 1`: Radix Tabs as links, fixed order, active tab with a 2px `state-selected` bottom rule, no fill, no pill, 13px labels, keyboard arrows.
  - The active section comes from the URL segment.
- [X] T084 [US5] Create `frontend/src/shell/ListInspector.tsx`:
  - At ≥1280px: two columns, list `min-width:480px` flex 1 and inspector 420px with a 1px `line-hairline` left border, radius 0.
  - Below 1280px: the inspector renders as an overlay floating layer (Radix Dialog non-modal, right aligned, 420px, 6px radius, `line-strong` border, the single shadow).
  - Inspector content reads `?inspect=` via `useSearchParams` and updates without a path change.
  - Inspector label column fixed at 96px.
  - Close clears `inspect` from the query only.
- [X] T085 [US5] Create `frontend/src/shell/PlaceholderSection.tsx` per `contracts/ui-shell.md`: the list area renders `EmptyState` with title "Not available in this build yet", cause "The <Section> section ships with the <Domain> screens." and next action "Open the command palette (Ctrl+K) to find entities across the instance." (button opens the palette). When `inspect` is set, the inspector shows Type / Name / Domain rows (96px labels; name in Plex Mono 13px) and "Detail view for <entityType> arrives with the <Domain> screens.". Register it for all 30 sections in `frontend/src/routes.tsx`, and add a not-found `EmptyState` ("This page does not exist." / "Use the rail or press Ctrl+K.")
- [X] T086 [US5] Wire the layout in `frontend/src/App.tsx`: glareshield (44px) + rail (56px) + work area (`WorkHeader` + `ListInspector`); home route uses the work area without tabs. Apply global styles in `frontend/src/theme/base.css`: body `surface-canvas`, `text-primary`, Plex Sans 15px/1.5; `font-variant-numeric: tabular-nums` utility on numeric cells and vitals; `:focus-visible` ring 2px `state-selected` offset 2px never removed; transitions only 120ms layers / 90ms controls
- [X] T087 [P] [US5] Create `frontend/scripts/contrast.mjs`: parse `src/theme/tokens.css` for both themes and compute WCAG ratios for text-primary/secondary/muted and each state color on surface-canvas/panel/float. Fail if text pairs are below 4.5 (text-muted is checked at 3.0 as disabled/UI) or UI-element pairs (line-strong, state-selected ring) are below 3.0. Print a table
- [X] T088 [US5] Create `frontend/e2e/shell.spec.ts`, for dark and light (`page.emulateMedia({colorScheme})` plus the toggle):
  - glareshield `boundingBox().height === 44`, rail width 56, rail has exactly 6 links in order;
  - for each domain, the tab strip is present iff the domain is not `logs`, the active tab is reflected in the URL, and deep-link reload works;
  - selecting a palette entity keeps `location.pathname` while the inspector shows the name;
  - at viewport 1024×768 the inspector is a dialog overlay;
  - axe on home and all 6 domain routes reports 0 violations;
  - keyboard-only: Tab from the page start reaches the glareshield, then rail, then header, then list, and every focused element has a visible outline (computed style);
  - `emulateMedia({reducedMotion:'reduce'})`: every computed `transition-duration` is 0s;
  - home first useful render (identity text visible) under 2000 ms from navigation start;
  - the glareshield shows exactly four vitals labeled CPU, Memory, Shared memory, Disk, with numeric CPU and MEM values on the Linux container; a mocked `/vitals` with cpu `unavailable` shows "—" and the reason tooltip; a mocked disk pending response keeps the previous number.
- [X] T089 [US5] Create `specs/001-foundation-shell/checklists/design-review.md` with every `docs/design.md` §7 anti-pattern as a row × {home, each domain route, palette, sign-in, re-auth overlay} × {dark, light}, then perform the review and fix defects until all rows pass. Record **once**, at the top of the file, the precedence applied: `docs/prototype.html` wording ("Safe mode", "Live — changes enabled", "CPU", "Memory", "Disk") prevails over design §4's all-caps mock text (design §10), which also removes any conflict with §7's all-caps prohibition. "CPU" is an acronym, not an all-caps label

**Checkpoint**: The shell matches the binding geometry and design gates in both themes.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T090 Run every gate end to end on a clean clone and record the results in `verification/feature-001-signoff.md`: `scripts/build/check-generated.sh`, `python3 -m unittest scripts/verify/test_verify_platform.py`, `zpm "iris-flightdeck test"` inside the container, `npm run lint && npm run check:tokens && npm run contrast && npm run test && npm run build`, all four Playwright projects, `scripts/dev/check-safe-mode-enforcement.sh`
- [ ] T091 Ideas Portal link (contest requirement, `docs/contest.md` §2.3). The idea text is drafted in `docs/ideas-portal-idea.md`; the author publishes it on ideas.intersystems.com under their own account **on 2026-09-16**, then the URL replaces the placeholder in `README.md` and in `docs/ideas-portal-idea.md`. Blocking for T075 sign-off
- [ ] T092 Cold README walkthrough (SC-005): a person who has not seen the project follows only `README.md` on a clean machine or VM (fresh clone, empty Docker cache) through to a signed-in home screen on the default image. Record in `verification/feature-001-signoff.md` elapsed time from clone to sign-in (target under 10 min), every question they asked, and every README fix made as a result
- [X] T093 Credential audit per quickstart §3 (SC-003): after sign-in, use, forced expiry, re-auth and sign-out, inspect browser storage and cookies and `grep -ri` the container's `messages.log` and `/durable/iris/mgr/*.log` for the test password and `Authorization`. Record "0 findings" or fix
- [X] T094 Update `docs/api-coverage.md`/README notes where research changed facts: minimum IRIS 2026.2 (with the observed `iris --version` table from spec Assumptions), `/login` body uses `user` (spec says `username`); and update `docs/prd.md` RN-FD-30 and §10.1 so native providers list logs **and** host CPU/memory, matching constitution v2.0.0

---

## Phase 9: SysAdmin API v1 dialect, limited mode on IRIS 2026.1 (FR-012a amended)

Author decision of 2026-09-17, taken before feature 002, in this order. Constitution 2.1.0.

- [X] T095 Bodyless POST/PATCH sends `{}` as `application/json` (spike finding 4) in `backend/cls/FlightDeck/Admin/Client.cls`; test `AdminClient.TestPostWithoutBodySendsJson`
- [X] T096 Constitution 2.1.0 (MINOR): dialect scope notes in Principles I and III; native gap "Disk usage per database, v1 dialect only"
- [X] T097 Dialect selected once per session (`backend/cls/FlightDeck/Admin/Dialect.cls`), translation keyed by v2 operation (`Admin/V1Dialect.cls`, generated `Admin/V1Routes.cls` from `scripts/build/v1-translations.json` via `scripts/build/gen-v1-dialect.py`, added to `check-generated.sh`); no version check outside `FlightDeck.Admin` (callers ask `Client.Has`, `ApiPresent`, `Limited`)
- [X] T098 Verify all 28 translations live by effect on 2026.1: `backend/test/FlightDeck/Test/V1Translations.cls`; record `verification/v1-translations-2026.1.md`
- [X] T099 Native disk per database, v1 only: `backend/cls/FlightDeck/Native/Databases.cls`, `Vitals/Service.NativeDisk`; privilege from the v2 spec (`Capability.Map.Requires`, `CurrentUserMay`); parity with `database-dir/info` on 2026.2 in `Test/NativeDatabases.cls`; installer code-database resource on v1 (Complexity Tracking)
- [X] T100 Evaluate namespaces and journal as v1-only native gaps: `verification/v1-native-gaps-2026.1.md` (recommendation: namespace reads native, writes unavailable; journal unavailable)
- [X] T101 Author decision on T100 (2026-09-17): namespace reads native on v1, writes withheld with their reason; journal deliberately not native (authorization stays in IRIS, Principle II). Constitution 2.1.0 gap list amended; decision recorded in `verification/v1-native-gaps-2026.1.md`
- [X] T107 Native namespace reads on v1: `backend/cls/FlightDeck/Native/Namespaces.cls`, dialect table sections `native`/`withheld`/`reasons` in `scripts/build/v1-translations.json` and `gen-v1-dialect.py`, `Client.UnavailableReason` used by the capability map and palette; parity with the official API on 2026.2 and provider 403 in `Test/NativeNamespaces.cls`; palette note per reason; limited e2e (64 unavailable, withheld reasons, namespace found natively)
- [X] T108 Mark `%Python Server` start/stop NOT VERIFIED in `verification/v1-translations-2026.1.md` (timeout in the image; no deduction from `%Java Server`)
- [X] T102 Capability map `available` + version reason, summary `unavailable`; session `instance.dialect`/`limited`, refusal only without any SysAdmin API (`MSGNOAPI`); palette groups `unavailable`; contract `flightdeck-api.openapi.json` and generated `API/OpenAPI.cls`; `Installer.CheckVersion`; `module.xml` `>=2026.1`; demo task start date valid on both dialects
- [X] T103 Frontend: `src/shell/LimitedModeIndicator.tsx` in the glareshield; `available` in `CapabilityGate`, palette actions and home counts; one "Not searched" note per domain; version refusal text from the server; types
- [X] T104 Dialect detection for callers who cannot read `%SYS` ("unknown" → the API's 403, never a version refusal); `Test/Dialect.cls`
- [X] T105 Test matrix: full e2e and backend on 2026.2; reduced 2026.1 set = backend `V1Translations`, `Dialect`, `NativeDatabases` and the Playwright `limited` project (`frontend/e2e/limited.spec.ts`), run against a compose install on 2026.1; quickstart §limited mode
- [X] T106 Spec (FR-012a, UC01 scenarios 7 and 8, version floor), plan, research R1 note, README requirements and troubleshooting

---

## Dependencies & Execution Order

### Phase Dependencies

```text
Phase 1 Setup
   └─> Phase 2 US1 (verification script)  ── gate T021 ──┐
                                                          v
                                   Phase 3 Foundational (T022–T041)
                                                          │
                                         Phase 4 US2 (session)
                                         ┌────────┼─────────┐
                                         v        v         v
                                  Phase 5 US3  Phase 6 US4  Phase 7 US5
                                         └────────┼─────────┘
                                                  v
                                           Phase 8 Polish
```

### User Story Dependencies

- **US1**: needs Setup only. Must finish, with the T021 gate, before Foundational.
- **US2**: needs Foundational. Blocks US3, US4 and US5 (all need a session).
- **US3**: needs US2. Its e2e scenario 2 uses demo data provisioned by the foundational `Demo.Provision()` task.
- **US4**: needs US2 (sign-in check) and the foundational demo provisioning.
- **US5**: needs US2. T076's memory/disk formulas depend on T021's probe 3/4 findings.

### Within Each Story

Backend class → API handler → unit test → frontend store/component → e2e.

### Parallel Opportunities

- Setup: T002, T003, T006, T007 in parallel.
- US1: T009, T010, T011, T018, T019 in parallel; then T012 → T013–T017 (same file, sequential) → T020 → T021.
- Foundational: T028, T029, T030, T032, T033, T034, T037 in parallel once T022–T024 exist.
- After US2: US3, US4 and US5 can proceed in parallel (different directories), except the shared `frontend/src/App.tsx` (T066, T086; do them sequentially).
- US5: T076, T078, T087 in parallel (T077 after T076).

---

## Parallel Example: User Story 1

```bash
# Probe classes and support tooling together:
Task: "T009 FDVerify.InProcess.cls"   Task: "T010 FDVerify.Loopback.cls"
Task: "T011 FDVerify.Files.cls"       Task: "T018 validate_report.py"
Task: "T019 test_verify_platform.py"
# Then sequentially: T012 → T013 → T014 → T015 → T016 → T017 → T020 → T021
```

## Parallel Example: User Story 5

```bash
Task: "T076 HostMetrics native provider"   Task: "T078 EmptyState"   Task: "T087 contrast.mjs"
```

---

## Implementation Strategy

### MVP First

1. Phase 1, then Phase 2 (US1). **Stop and validate**: both reports are committed and the gate
   holds. This alone answers the project's critical-path risk (PRD risk 1).
2. Phase 3, then Phase 4 (US2). **Stop and validate**: sign-in, safe mode and capabilities work
   end to end.

### Incremental Delivery

3. US4 install (demo data unblocks realistic palette tests), with the README written now.
4. US3 palette.
5. US5 shell polish and design gates.
6. Polish: the signoff run on both images.

### Stop conditions

- T021 shows probe 2 without `in_process` on either image → stop. Session design returns to the
  author (spec edge case: no workaround that stores credentials).
- T046(c) application-role access fails and has no fix without a public grant on a shared
  database → stop and ask the author.

---

## Notes

- `[P]` means different files and no incomplete dependencies.
- Commit after each task or logical group, in English, ending with the attribution trailer from the session.
- Never mark a task `[X]` without the file existing and its check having run.
