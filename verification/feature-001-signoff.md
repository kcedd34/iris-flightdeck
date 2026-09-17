# Feature 001 sign-off (T090), 2026-09-17

Run from the working tree. The repository has no commits yet, so a clean clone was not possible;
the Docker install ran against the files as they will be committed.

## Static gates

| Gate | Result |
|---|---|
| `scripts/build/check-generated.sh` (capability spec and OpenAPI class match their sources) | up to date |
| `python3 -m unittest scripts/verify/test_verify_platform.py` | 11 tests OK |
| `scripts/verify/validate_report.py verification/*-2026.2.json` | both valid |
| `npm run lint` | clean |
| `npm run check:tokens` | ok |
| `npm run contrast` (both themes) | ok |
| `npm run test` (Vitest) | 6/6 |
| `npm run build` (tokens, tsc, vite, check-no-fixtures) | ok; the fixture is absent from the production bundle and present in the fixtures build |
| `scripts/build/check-dist.sh` (committed `frontend/dist` matches a fresh build) | up to date |

## Dynamic gates, clean install on IRIS Community 2026.2

| Gate | Result |
|---|---|
| `docker compose down -v && docker compose up -d --build` | ready line after 12 s (15 s wall clock, base image cached); 9 demo objects created through the SysAdmin API |
| Backend `%UnitTest` in the container | 26/26: AdminClient 4, CapabilityMap 6, HostMetrics 3, InstallerIdempotency 3, PaletteSearch 5, RouterGuards 5 |
| `scripts/dev/check-safe-mode-enforcement.sh` | 67 mutating requests rejected before routing; IRIS unchanged |
| Playwright, all projects | 24/24: session 7, palette 7, shell 9, fixtures 1 |

IRIS for Health 2026.2 was verified separately: install, sign-in, limited users, search, vitals
and 26/26 backend tests (`install-runs.md`).

## Other checks

- **Credential audit (T093, SC-003): 0 findings.** Searched every `*.log` in `mgr/`, the USER,
  IRISSYS and IRISTEMP databases, the journal files and the install tree for:
  - the e2e test password and the wrong password used in e2e;
  - `Authorization: Basic`;
  - Base64 credential fragments.

  In the browser (session e2e scenario 3):
  - no `Authorization` header after sign-in;
  - `localStorage` holds only `flightdeck:theme:*` and `flightdeck:recent:*`;
  - `sessionStorage` is empty;
  - cookies are only the IRIS-owned `CSPSESSIONID*`, `CSPBrowserId` and `CSPWSERVERID`.
- **Design review (T089)**: `specs/001-foundation-shell/checklists/design-review.md`. All 15
  anti-patterns pass in both themes after three fixes.

## Open items that need the author

| Item | Why it is open |
|---|---|
| **T091 Ideas Portal link** | Publishing on ideas.intersystems.com needs the author's InterSystems account. The text is ready in `docs/ideas-portal-idea.md`; the README shows "_link pending publication by the author_" |
| **README repository URL** | `git clone <repository-url>` in the README: the public repository URL is not known yet |
| **T092 cold README walkthrough (SC-005)** | Needs a person who has not seen the project; it cannot be performed by the implementer |
| **Design decision: `text-muted` for readable labels** | The prototype uses it for labels, but it fails WCAG AA (2.84–3.56:1). Readable text was moved to `text-secondary` (see design review) |
| **Constitution follow-up** | `.claude/skills/` still lacks the project skills the constitution references |
