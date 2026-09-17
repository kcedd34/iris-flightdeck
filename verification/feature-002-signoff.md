# Feature 002 sign-off (T085 to T087), 2026-09-17

Web applications, REST API explorer and the shared mutation layer. Run from the working tree: the
changes are not committed yet, so a clean clone was not possible; every Docker install was built
from the files as they stand.

## Static gates

| Gate | Result |
|---|---|
| `scripts/build/check-generated.sh` (capability data, OpenAPI class, v1 routes, descriptors) | up to date; `check-descriptors` ok (4 entity types, 5 mutations) |
| `scripts/build/check-dist.sh` | up to date |
| `npm run lint` | clean |
| `npm run check:tokens` | ok |
| `npm run check:dialect` | ok (5 declared exceptions) |
| `npm run check:mutation-boundary` | ok (3 declared exceptions); probed with four violating files, all named (`verification/README.md`) |
| `npm run contrast` | ok |
| `npm run test` (Vitest) | 14/14 |
| `npm run build` (includes the three gates, tsc, vite, `check-no-fixtures`) | ok |
| `python3 -m unittest scripts/verify/test_verify_platform.py` | OK |

## Fresh installs

Each was `docker compose down -v` then `up -d --build`, with the demo.

| Install | Ready | Backend `%UnitTest` | Playwright | Enforcement scripts |
|---|---|---|---|---|
| IRIS CE 2026.2 (`iris-community:2026.2-zpm`, port 52780) | 15 s | 115/115, 25 classes | 64 passed, 10 skipped (`limited` skips: nothing is unavailable) | safe mode ok; mutation ok |
| IRIS for Health 2026.2 (`irishealth-community:2026.2-zpm`, port 52792) | 15 s | 115/115 | 64 passed, 10 skipped | safe mode ok; mutation ok |
| IRIS CE 2026.1 (`iris-community:2026.1-zpm`, port 52791, limited mode) | 11 s | 115/115 after one test fix (below) | `limited` 10/10; `webapps`, `mutation`, `rest` 30/30 | not run |

The Playwright runs include the docker-backed checks with `FD_CONTAINER` set to the install under
test: no outbound connection from the executor (`rest-confinement`), no credential in the IRIS logs
(`audit`), and the pattern catalog (`pattern`).

## Limited mode on IRIS 2026.1 (T085, SC-013)

- `limited.spec.ts` gained two tests that follow the capability map, never the version: web
  applications are listed with exposure markers, inspected with links, and the REST tab discovers
  `/api/flightdeck`; one web application edit goes through the shared dry-run and is confirmed by
  reading the official object back. On 2026.1 the map offers these operations, and both passed.
- The whole backend suite ran on 2026.1, not only a reduced set. `EntityReads`, `WebAppLinks`,
  `MutationService`, `SelfProtection`, `RestDiscovery` and `RestExecutorRoles` all pass.
- **Test fixed:** `CapabilityMap.TestOrSemantics` (feature 001) assumed `GET /v2/databases` is
  offered. On 2026.1 it is not, so the version reason correctly takes precedence over the privilege
  reason. Feature 001's 2026.1 matrix ran a subset that did not include this class. The test now
  picks an available operation that declares several privileges from the map itself. It passes on
  2026.1 and 2026.2.

## Credential audit (T083, SC-010)

`e2e/audit.spec.ts` signs in as a dedicated `%All` test user and then:
- edits a web application;
- runs a GET and a POST test request, the POST through the dry-run;
- copies `curl` and exports the trail.

It then searches the export, the clipboard text, `sessionStorage`, `localStorage`, cookies and every
`*.log` under `/durable/iris/mgr` for the password, its Basic token and `Authorization`. Result on
CE 2026.2 and IRIS for Health 2026.2: **0 findings**. The copied `curl` carries
`-u '<user>:<password>'` literally.

## Quickstart (T087)

- Commands in §0 to §3, §6, §7, §9 and §10 ran as written, or as the Playwright projects that
  automate them.
- §4: both `curl` flows returned the documented answers, 403 `SAFE_MODE_ON` and 403
  `SELF_PROTECTION` with §9 message 4. The session cookie came from `POST /v1/session` into a
  temporary cookie jar, deleted afterwards.
- §5 and §8 steps 1, 3 and 4 are covered by `mutation.spec.ts`.
- **§8 step 2 (duplicated tab) was not run.** Playwright cannot duplicate a tab the way a browser
  does. By decision, there is no extra rule for duplicated tabs.
- **Corrected:**
  - §3 now names the new projects and `FD_CONTAINER`.
  - §6 said a `Host` header is "ignored". The executor refuses it with 400 `CREDENTIAL_HEADER`,
    and the confinement spec asserts that.

## Defects found and fixed during polish

- Secret fields were returned in list rows (pattern catalog, `verification/README.md`).
- A mutation blocked at preview was not recorded as `Blocked` (same).
- The dry-run diff region was not keyboard-scrollable; the search field, password inputs and an
  acronym had styling defects (`checklists/design-review.md`).
