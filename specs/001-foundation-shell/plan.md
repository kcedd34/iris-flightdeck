# Implementation Plan: FlightDeck Foundation and Shell

**Branch**: `001-foundation-shell` | **Date**: 2026-09-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-foundation-shell/spec.md`

## Summary

This feature delivers the frame every later FlightDeck feature sits in, in dependency order:

1. **Day-1 verification script**: 8 ordered probes, three-way classification, raw errors, exit code.
2. **Session**: identity delegated to IRIS with the in-process authentication path, a capability
   map derived from the official spec, and safe mode per tab enforced in both UI and backend.
3. **Command palette**: local actions plus generic entity search across all domains.
4. **Install**: one command via Docker Compose, or IPM, with full UC11 demo provisioning through
   the official API.
5. **Shell**: glareshield, rail, section tabs and list-plus-inspector, in two themes, with every
   domain route rendering an empty state.

**Constitution**: v2.1.0 (was v2.0.0). Principle I is scoped to the running portal and names host
CPU/memory, and disk usage per database on the v1 dialect only, as native-provider gaps. Dialect
scope notes are in Principles I and III.

**Research changed three assumptions** ([research.md](./research.md), all observed on live
containers):
- The Community `latest` images are IRIS 2026.1 with SysAdmin API **v1 only**. FlightDeck pins
  **`2026.2-zpm`** images (R1). *Amended 2026-09-17*: IRIS 2026.1 runs in limited mode through the
  v1 dialect adapter (FR-012a, constitution 2.1.0).
- The images' default entrypoint crashes, and `_SYSTEM`'s password is expired at first boot. The
  install bypasses the first and unexpires the second (R2, R3).
- Probe 2 candidate 1 (**in-process**) works on 2026.2 when calls run in `%SYS`. That becomes the
  session design, and no JWT is ever held (R4).

## Technical Context

**Language/Version**: ObjectScript on InterSystems IRIS 2026.2 (CE and IRIS for Health CE);
TypeScript 5.6 (strict); Python 3.10+ standard library (verification script only).

**Primary Dependencies**:
- Backend: IRIS `%CSP.REST` (hand-written router with OpenAPI parity test, R9); IPM (`zpm`) for
  packaging.
- Frontend (build-time npm, bundled, no CDN): React 18, React Router 6, TanStack Query 5, `cmdk`
  1, Radix UI primitives, plain CSS over design tokens (research R10), `@fontsource/ibm-plex-sans`
  and `@fontsource/ibm-plex-mono`. Resolved versions at implementation: Vite 8, TypeScript 6,
  ESLint 10, Vitest 5.

**Storage**: None owned by FlightDeck. IRIS is authoritative. Per session, the last known disk
vital sits in `%session.Data`. In the browser, only `localStorage` theme and recent actions are
stored, keyed by username. Safe-mode state and tab id live in memory only.

**Testing**:
- Backend: `%UnitTest` via `zpm "iris-flightdeck test"` (capability derivation, domain assignment
  counts, router/OpenAPI parity, safe-mode guard, Admin.Client namespace and response isolation,
  installer idempotency).
- Frontend: Vitest + Testing Library.
- End to end: Playwright (dev only) against the Vite dev server proxied to the container, with
  `@axe-core/playwright`.
- Verification script: Python `unittest` for classification and report building, plus schema
  validation.

**Target Platform**:
- Docker images `intersystemsdc/iris-community:2026.2-zpm` (default) and
  `intersystemsdc/irishealth-community:2026.2-zpm`, linux/amd64.
- Current Chromium, Firefox and Safari at 1280px+ (inspector overlay below).
- Development: WSL2 with native Docker Engine.

**Project Type**: Web application. ObjectScript backend and React SPA, both served by IRIS.

**Performance Goals**:
- Palette opens with focus in under 100 ms.
- Home screen's first useful render under 2 s on a local instance.
- Entity search responds within a 1.5 s server deadline (partial results after that).
- Vitals refresh every 10 s, paused while the tab is hidden.

**Constraints**:
- No credential in any layer (the Basic header is sent once at sign-in, then dropped).
- Safe mode is in memory per tab, with a server guard on every mutating method.
- No hex literals in components; tokens and scales are enforced at compile and lint time.
- No transition over 200 ms.
- No CDN.
- IRIS data lives in a named volume.
- The Vite dev server uses polling watch.

**Scale/Scope**:
- One instance, a handful of concurrent admins.
- 273 official operations in the capability map; about 40 list operations searchable.
- 5 user stories and 51 functional requirements (including FR-012a, FR-015a, FR-017a, FR-031a, FR-044a).
- 6 empty domain routes and 30 empty sections.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Pre-research: PASS. Post-design re-check below reflects research.md and the Phase 1 artifacts.

| # | Principle | Status | Evidence |
|---|---|---|---|
| I | Official SysAdmin API first (constitution v2.0.0) | **PASS** (installer bootstrap and diagnostic tooling exceptions, see Complexity Tracking) | **Running portal**: every IRIS read and write goes through `FlightDeck.Admin.Client` to `%Api.Admin` `/v2/*` in-process (R4); no `Security.*`/`Config.*`/`SYS.*` calls in any handler. **Native providers**: only `FlightDeck.Native.HostMetrics` for host CPU and memory, a gap named in Principle I (R8). IRIS shared memory and disk come from the API. **Installer**: the `FlightDeck_Runtime` role and all demo objects (roles, resources, tasks, sample web app, wallet collection) go through `/v2/*` (R13, R14). The bootstrap items that do not (IPM code load, IPM `WebApplication` declarations for FlightDeck's own two apps, container default-password unexpiry) and the day-1 verification script's probe setup are listed in Complexity Tracking |
| II | Delegated identity, no stored credentials | **PASS** | IRIS authenticates the Basic header once. The IRIS-owned session cookie is the only authenticator afterward. JWT is rejected because refresh tokens are credentials (R4). A credential audit is in quickstart §3. Default login is the image's own and never generated (R3) |
| III | Capabilities derived from spec | **PASS** | Privilege prefixes are parsed from the bundled official spec and crossed with `/info` privileges. Domain assignment is generated from `docs/api-coverage.md`. 273-entry and count drift tests (R7, data-model §3) |
| IV | Safe mode per tab | **PASS** | Memory-only store, with lint and test guards against storage APIs (R6). Server guard on POST/PUT/PATCH/DELETE via `X-FlightDeck-Safe-Mode` (R5, FR-015a) |
| V | Diff before every mutation | **PASS (N/A for IRIS mutations in this feature)** | The UI changes no IRIS state here. Palette mutating actions only navigate. The re-auth recompute hook (`computationEpoch`) is built and proven with the fixture (R16) for UC10 to consume |
| VI | Secrets write-only | **PASS** | No secret-bearing screen. The demo wallet collection has no secrets (R14). Error envelope `raw` is IRIS text, and the Authorization header is redacted in logs and reports |
| VII | Self-protection | **PASS (N/A)** | No destructive operation is exposed. The safe-mode server guard is the first server-side protection layer that UC03/UC05/UC08 checks will extend |
| VIII | Graceful degradation | **PASS** | IRIS 2026.1 runs in limited mode: operations without a v1 route are disabled with the version message and a glareshield indicator; only an instance without any SysAdmin API is refused (FR-012a, amended). CPU vital is unavailable with a reason. Disk keeps its last value while pending. Palette groups report `forbidden`/`timeout` without failing. Empty states give a cause and next action. Inconclusive probes block planning and never reach users (R11) |
| IX | API decides what is allowed | **PASS** | Enabled state comes from `CapabilityEntry.allowed` only. No object-level `Can*` fields are rendered in this feature |
| X | `docs/design.md` binding | **PASS** | Tailwind theme reduced to the design tokens and scales. `check:tokens` gate. Geometry asserted by e2e. Axe and contrast checks in both themes. §7 review checklist (quickstart §5) |
| XI | English | **PASS** | UI strings use the §9 catalog, and all code, comments and commits are in English |
| — | Technical constraints | **PASS** | Served by IRIS (R12). No runtime Node. Fonts bundled. Both editions via one variable. Named volume. Polling watch |
| — | Delivery priorities | **PASS** | README is a tracked deliverable (FR-046). Install verified on both images (quickstart §2) |

**Post-design result: PASS.** One justified exception is below. Two items need the author's
attention but do not block this feature:
1. Pinning to IRIS 2026.2 (R1). The README states the minimum version.
2. CPU and host memory need a constitution amendment before RN-FD-19's instrument cluster (R8).

## Project Structure

### Documentation (this feature)

```text
specs/001-foundation-shell/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── flightdeck-api.openapi.json
│   ├── verification-report.schema.json
│   └── ui-shell.md
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
module.xml                          # IPM module iris-flightdeck (R13)
Dockerfile                          # node build stage → IRIS 2026.2-zpm stage
docker-compose.yml                  # one service, named volume, FLIGHTDECK_PORT, IRIS_IMAGE
docker/
└── first-start.sh                  # unexpire defaults → zpm load (-DDemo=1) → ready line
README.md
LICENSE
.gitignore  .gitattributes  .dockerignore  .editorconfig

backend/
├── cls/FlightDeck/
│   ├── API/Router.cls              # %CSP.REST, UseSession=1, OnPreDispatch guards (R5, R9)
│   ├── API/Session.cls             # POST/GET/DELETE /session
│   ├── API/Capabilities.cls        # GET /session/capabilities
│   ├── API/Vitals.cls              # GET /vitals
│   ├── API/Palette.cls             # GET /palette/entities
│   ├── API/OpenAPI.cls             # XData = contracts/flightdeck-api.openapi.json
│   ├── API/Response.cls            # JSON + error envelope helpers
│   ├── Admin/Client.cls            # in-process %Api.Admin calls in %SYS (R4)
│   ├── Capability/Spec.cls         # generated: XData official spec + domain map (R7)
│   ├── Capability/Map.cls          # derivation
│   ├── Palette/Search.cls          # list-op fan-out with deadline (R15)
│   ├── Vitals/Service.cls          # composes 4 vitals; SHM and async disk via API (R8)
│   ├── Native/HostMetrics.cls      # native provider: /proc/stat CPU delta, /proc/meminfo (R8)
│   ├── UI/Static.cls               # SPA file server with index.html fallback (R12)
│   ├── Install/Installer.cls       # IPM invoke: role, web app check, demo switch (R13)
│   ├── Install/Demo.cls            # UC11 demo set via /v2/* (R14)
│   └── Demo/NoopTask.cls           # %SYS.Task.Definition used by demo tasks
└── test/FlightDeck/Test/           # %UnitTest cases

frontend/
├── index.html  vite.config.ts  tsconfig.json  package.json  eslint.config.js  playwright.config.ts
├── scripts/
│   ├── check-tokens.mjs            # literal color / scale / motion gate
│   └── contrast.mjs                # token contrast in both themes
├── src/
│   ├── main.tsx  App.tsx  routes.tsx
│   ├── theme/tokens.css            # the only file with color values (both themes)
│   ├── theme/ThemeProvider.tsx
│   ├── api/client.ts               # sole fetch; tab and safe-mode headers; 401 → expiry
│   ├── session/                    # SessionProvider, safeMode store, SignIn, ReauthOverlay, capabilities
│   ├── shell/                      # Glareshield, Vitals, SafeModeIndicator, Rail, WorkHeader, SectionTabs, ListInspector, EmptyState, sections.ts, domains.ts
│   ├── palette/                    # CommandPalette, actions.ts, useEntitySearch.ts, recent.ts
│   ├── home/Home.tsx
│   ├── prefs/storage.ts            # only module allowed to touch localStorage
│   └── fixtures/ReauthFixture.tsx  # fixtures mode only
├── test/                           # Vitest
└── e2e/                            # Playwright: session, palette, shell, fixtures

scripts/
├── build/gen-capability-spec.py    # docs/sysadmin-api-v2.json + docs/api-coverage.md → Capability/Spec.cls
├── verify/
│   ├── verify_platform.py          # day-1 script (R11)
│   ├── probes/*.cls                # temporary in-instance probe classes
│   ├── validate_report.py
│   ├── run-both-images.sh
│   └── test_verify_platform.py
└── dev/
    ├── check-safe-mode-enforcement.sh
    └── wait-ready.sh

verification/                        # committed day-1 reports
```

**Structure Decision**: Web application split. `backend/` holds ObjectScript classes packaged by
the root `module.xml`, and `frontend/` is the React SPA whose build output IPM copies into the
install directory. The root holds the one-command install files. `scripts/verify/` is standalone
so it runs before any application code exists (User Story 1 is first).

## Delivery order

1. Setup: repo skeleton, tooling, generated capability spec.
2. **US1 verification script**: run it on both images and commit the reports. Gate for US2.
3. Foundational backend: Router, Admin.Client, error envelope, safe-mode guard. Foundational
   frontend: tokens, theme, API client, safe-mode store.
4. US2 session.
5. US5 shell (needs a session for identity).
6. US3 palette.
7. US4 install and demo, with the README written alongside US4, not after.
8. Polish: design review, both-image install run, credential audit.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| **Installer bootstrap: FlightDeck's own web apps** `/flightdeck` and `/api/flightdeck` declared through IPM `WebApplication` elements in `module.xml`, not `PUT /v2/web-app` (Constitution I v2.0.0, bootstrap exception) | The apps are the portal's own entry points and must exist when installation finishes. IPM's declarative elements are the standard, atomic, package-manager way to do this, and uninstall removes them | Creating them over HTTP/in-process through `/v2/web-app` at install time adds a new failure mode (API availability, privilege, namespace switch) to the path that decides Clarity of Instructions and Developer Experience. The exception is narrow: it covers only these two apps. The demo web app `/csp/fd-demo` goes through `PUT /v2/web-app` |
| **Installer bootstrap: capture routine in `%SYS`** (`Installer.DeployCapture` copies `FlightDeck.Admin.Capture` into `%SYS`) | Official handlers run in `%SYS`; I/O redirection resolves its mnemonic routine in the current namespace. Capturing by switching to a file device leaked `/v2/journal/files` output into HTTP responses | Extended routine references are rejected in mnemonic spaces. `%Z` classes compiled from the install namespace are not stored in IRISSYS on 2026.2. Switching devices is not safe against handlers that return to `$PRINCIPAL` |
| **Installer bootstrap: IPM code load and compile** (`zpm "load"`) | Classes must exist before any API call can be made in-process | None; there is no API for loading code |
| **Diagnostic tooling: day-1 verification script probe setup** (`scripts/verify/verify_platform.py`, T014/T020) loads probe classes and creates temporary web apps via `iris session` with `Security.Applications`, and unexpires default passwords in throwaway containers | The script's purpose is to establish, **before the portal exists**, which authentication path and API shapes work. It cannot depend on FlightDeck code, and it must be able to test the in-process candidate itself | Routing probe setup through `/v2/web-app` would make probe 2 depend on probe 1's outcome and on JWT/Basic access to the API being tested, which confounds the result. The script never ships, never runs against a user's instance and removes what it creates |
| `Security.Users.UnExpireUserPasswords("*")` called directly (Constitution I) in `docker/first-start.sh`, container path only | The image ships `_SYSTEM` with an expired password (R3), so the documented default sign-in fails. No `/v2` operation resets password expiry | Changing the password through `POST /v2/security/user/password` would create a new credential (forbidden by clarification 1). A forced change-password screen is out of scope and adds a manual step |
| **Installer bootstrap on the v1 dialect: code database resource** (`Native.Databases.CodeDatabaseResource` reads `Config.Namespaces`, `Config.Databases`, `SYS.Database`) | `EnsureRuntimeRole` needs the resource of FlightDeck's code database. IRIS 2026.1 exposes none of the namespace, database or database-dir operations used on v2 | There is no official route on v1. On v2 the official operations stay in use; the native result is verified equal to them on 2026.2 (`FlightDeck.Test.NativeDatabases`) |
| Entrypoint override of the Community image (Technical Constraints: "run on both images") | The stock post-start hook crashes and shuts IRIS down on 2026.1 and 2026.2 (R2) | No environment switch disables it (R2). Waiting for a fixed image risks the deadline |
