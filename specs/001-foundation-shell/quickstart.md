# Quickstart: Validate Feature 001 (Foundation and Shell)

Run these in order. Each block names the spec items it proves. Contracts:
[`flightdeck-api.openapi.json`](contracts/flightdeck-api.openapi.json),
[`verification-report.schema.json`](contracts/verification-report.schema.json),
[`ui-shell.md`](contracts/ui-shell.md).

## Prerequisites

- WSL2 or Linux with Docker Engine 24+ and Compose v2, Python 3.10+, and Node 20+ (development
  checks only).
- Free host port 52780, or set `FLIGHTDECK_PORT`.
- Repository cloned onto any filesystem. IRIS data lives in a named volume, never under `/mnt/*`.

## 1. Day-1 verification (User Story 1: FR-001 to FR-008, SC-001)

```bash
scripts/verify/run-both-images.sh
```

Expected:
- Two reports: `verification/iris-2026.2.json` and `verification/irisforhealth-2026.2.json`.
- Both validate against the schema:
  `python3 scripts/verify/validate_report.py verification/*.json`
- Both contain 8 probes in order. Probe 2 has 3 candidates, and `finding.selected = "in_process"`
  on both images.
- The exit code is 0 only if no probe is `inconclusive`. Otherwise it is 1, and the table on
  stdout names the inconclusive probes.

Robustness check (FR-002, FR-004):

```bash
FD_VERIFY_FAULT=3 python3 scripts/verify/verify_platform.py --base-url http://localhost:52780 \
  --container flightdeck-iris-1 --label fault-test ; echo "exit=$?"
```

`FD_VERIFY_FAULT=<n>` forces probe n to raise. Expected: all 8 probes are still reported, probe 3
is `inconclusive` with the injected error in `raw`, and `exit=1`.

**Gate**: US2 is not marked done until both reports show `selected = "in_process"`.

## 2. One-command install (User Story 4: FR-040 to FR-046, SC-005, SC-010)

```bash
docker compose up -d
docker compose logs -f iris   # wait for: FlightDeck is ready at http://localhost:52780/flightdeck/
```

Expected:
- No file edits and no variables needed.
- Open `http://localhost:52780/flightdeck/` and sign in as `_SYSTEM` / `SYS` (README).
- The log lists each demo object with `created`, `exists` or `skipped (reason)`.

IRIS for Health (FR-045):

```bash
docker compose down -v
IRIS_IMAGE=intersystemsdc/irishealth-community:2026.2-zpm docker compose up -d --build
```

The same sign-in and the same checks pass.

Port conflict (FR-042): with 52780 occupied, `docker compose up -d` prints Docker's
"port is already allocated" error, which the README quotes. Then `FLIGHTDECK_PORT=52790 docker
compose up -d` works.

Compile failure (FR-041): add a syntax error to any class, rebuild, and check that
`docker compose logs iris` shows `FLIGHTDECK INSTALL FAILED: compile: …` with the IRIS error text.

IPM without demo (FR-043, UC11 scenario 3), on a running 2026.2 instance:

```objectscript
zpm "load /path/to/iris-flightdeck"
```

Expected: none of `FD_Demo_*`, `/csp/fd-demo` or `FD_Demo_Vault` exist. With `-DDemo=1` they do.

## 3. Session and safe mode (User Story 2: FR-009 to FR-018, SC-002, SC-002a, SC-003, SC-009)

Automated:

```bash
cd frontend && npm ci && npm run test && npm run e2e -- --project=session
```

The Playwright suite `e2e/session.spec.ts` covers UC01 scenarios 1–6 verbatim:
- sign-in lands on home with "Safe mode" visible;
- users `fd_e2e_operator` (`%Operator`) and `fd_e2e_none` (no admin privilege), created by the e2e
  setup through the API, see disabled actions with "Requires Use on …";
- a disarmed tab, then `context.newPage()` on the same URL and a reload, both come back armed;
- invalid credentials show message 1 for an unknown user and for a wrong password alike.

Manual credential audit (SC-003), after sign-in, use, expiry and sign-out:
- DevTools → Application: `localStorage` holds only `flightdeck:theme:*` and `flightdeck:recent:*`,
  `sessionStorage` is empty, and the cookies are only `CSPSESSIONID-*`, `CSPBrowserId` and `CSPWSERVERID`
  (IRIS-owned).
- `docker compose exec iris grep -ri "SYS" /durable/iris/mgr/messages.log` shows no password
  occurrences tied to FlightDeck requests.

Backend safe-mode enforcement (FR-015a, SC-002a):

```bash
scripts/dev/check-safe-mode-enforcement.sh   # signs in via curl, then sends PUT/POST/DELETE with
                                             # safe-mode armed, missing, and a bogus value
```

Expected: every call gets 403 `SAFE_MODE_ON` (or 400 `MISSING_TAB_ID`), and
`GET /api/admin/v2/security/roles` shows no change.

Limited mode (FR-012a, UC01 scenarios 7 and 8), the reduced IRIS 2026.1 matrix. Run it as a
separate compose project on another port, so the 2026.2 install stays up:

```bash
cat > /tmp/fd-v1.yml <<'EOF'
services:
  iris:
    image: iris-flightdeck:2026.1-test
EOF
IRIS_IMAGE=intersystemsdc/iris-community:2026.1-zpm FLIGHTDECK_PORT=52791 \
  docker compose -p fd-v1 -f docker-compose.yml -f /tmp/fd-v1.yml up -d --build
cd frontend && FLIGHTDECK_PORT=52791 npx playwright test --project limited
```

Backend, in a 2026.1 container with the repository at `/opt/flightdeck`:
`FD_DEV_CONTAINER=<container> scripts/dev/test-backend.sh V1Translations` (then `Dialect`,
`NativeDatabases` and `NativeNamespaces`).

Expected:
- The install log shows `SysAdmin API v1 present (limited mode …)`, and the demo is provisioned.
- e2e: dialect `v1` with 64 of 273 operations unavailable, the glareshield indicator, disabled
  palette actions with the version message (namespace writes and journal with their recorded
  reasons), one "Not searched" note per reason within a domain, namespaces found natively, a native
  Disk value, and a no-privilege user refused for privileges.
- Backend: `V1Translations` 14, `Dialect` 6, `NativeDatabases` 5 and `NativeNamespaces` 4 pass.

Clean up with `docker compose -p fd-v1 -f docker-compose.yml -f /tmp/fd-v1.yml down -v`.
Scenario 7 (no SysAdmin API at all) has no Community image to run against; the e2e suite covers it
with a stubbed response (session test 8).

Session expiry and restore (FR-016, FR-017, FR-017a, UC01 scenario 4):

```bash
cd frontend && npm run e2e -- --project=fixtures   # builds with --mode fixtures
```

Expected: the fixture form's typed text survives cookie deletion and re-authentication in the
overlay, and **Apply** stays disabled until the diff is recomputed (epoch matches).

## 4. Command palette (User Story 3: FR-019 to FR-028, SC-004, SC-010)

```bash
cd frontend && npm run e2e -- --project=palette
```

Covers UC02 scenarios 1–4 verbatim, plus:
- Opening takes under 100 ms (performance mark `palette-open` to `palette-input-focused`).
- `FD_Demo` returns groups for Permissions (roles, resources), Web applications, Tasks and
  Security (wallet), each result with context.
- Entity search forced to fail (route intercept returns 500) shows message 19 while actions
  still work.
- Selecting "Delete a role" while armed offers disarm first.
- Overflow shows the total and "Refine by domain"; no results suggests domains.

## 5. Shell layout and design gates (User Story 5: FR-029 to FR-039, SC-006 to SC-008)

```bash
cd frontend && npm run lint && npm run check:tokens && npm run check:dialect && npm run e2e -- --project=shell
```

- `check:tokens` fails on any hex, rgb or hsl literal outside `src/theme/tokens.css`, any
  off-scale spacing or radius, and any transition over 200 ms.
- The shell e2e checks:
  - glareshield height 44 and rail width 56 (bounding boxes);
  - exactly 6 rail items;
  - tab strips on 5 domains and none on Logs;
  - active tab in the URL;
  - the inspector opens without a URL path change;
  - overlay inspector at 1024 px;
  - axe with zero violations on home and every domain route in dark and light;
  - contrast of every token pair via `scripts/dev/contrast.mjs`;
  - keyboard-only traversal;
  - `prefers-reduced-motion` gives zero transitions;
  - home first useful render under 2 s.
- Host metrics (FR-031a, SC-011), repeated 10 times idle and 10 times under
  `docker compose exec iris sh -c 'yes > /dev/null & yes > /dev/null & sleep 20; kill %1 %2'`:
  compare the glareshield CPU and MEM (or `GET /api/flightdeck/v1/vitals`) with
  `docker compose exec iris sh -c 'top -bn1 | head -5; free'`. They must agree within 5 points. "Shared memory"
  is labeled separately.
- Manual: walk `docs/design.md` §7 anti-patterns screen by screen in both themes and record the
  result in `specs/001-foundation-shell/checklists/design-review.md`.
