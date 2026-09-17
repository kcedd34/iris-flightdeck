# Quickstart: Validating Feature 002

**Feature**: `002-webapps-explorer-mutations`

Runnable checks that prove the feature end to end. Contracts:
[`contracts/flightdeck-api-002.openapi.json`](./contracts/flightdeck-api-002.openapi.json),
[`contracts/ui-pattern.md`](./contracts/ui-pattern.md). Data shapes:
[`data-model.md`](./data-model.md).

## 0. Prerequisites

- Feature 001 prerequisites (Docker Engine, Node 20 for the frontend checks).
- A fresh install with demo data:

```bash
docker compose down -v && docker compose up -d --build && scripts/dev/wait-ready.sh 600
```

- For the limited-mode matrix, the 2026.1 install from feature 001 quickstart (port 52791).

## 1. Static gates

```bash
scripts/build/check-generated.sh          # capability data, OpenAPI class, v1 routes, descriptors
scripts/build/check-dist.sh               # versioned bundle rebuilt after frontend changes
cd frontend
npm run lint && npm run check:tokens && npm run check:dialect && npm run check:mutation-boundary \
  && npm run contrast && npm run test && npm run build
```

Expected: all pass. `check:mutation-boundary` is then probed: add a file under
`src/domains/web-apps/` that imports `@radix-ui/react-dialog`, and one that writes
`sessionStorage`; the gate fails naming both; remove them.

## 2. Backend tests

```bash
FD_DEV_CONTAINER=iris-flightdeck-iris-1 scripts/dev/test-backend.sh
```

Expected: every class passes, including descriptor validation, grade resolution, fingerprint and
masking, self-protection, executor path confinement, role reduction (spike T-EXEC-1), and REST
discovery merge.

## 3. End-to-end on IRIS 2026.2

```bash
cd frontend && FLIGHTDECK_PORT=52780 npx playwright test
```

Expected: the 12 PRD scenarios of UC03, UC04 and UC10, the spec's additional scenarios, and feature
001's suites pass; the `limited` project skips. Projects added by this feature: `webapps`,
`mutation`, `rest` (explorer and confinement), `audit` (credential audit and axe) and, in
`fixtures`, the pattern catalog.

Three specs use `docker exec` for checks that have no HTTP surface on purpose: the container's
connection table (`rest-confinement`), the IRIS logs (`audit`) and the pattern catalog switch
(`pattern`). They use the container named by `FD_CONTAINER` (default `iris-flightdeck-iris-1`); for
another install pass both, for example
`FLIGHTDECK_PORT=52792 FD_CONTAINER=fd-health-iris-1 npx playwright test`. Without Docker access the
connection-table and log checks skip with a stated reason.

## 4. Server-side enforcement without the UI (SC-003, SC-004)

With a signed-in session cookie from the browser devtools (never a stored password):

```bash
# armed tab: every mutation refused
curl -s -b "$COOKIE" -H 'X-FlightDeck-Tab: qs' -H 'Content-Type: application/json' \
  -X POST http://localhost:52780/api/flightdeck/v1/mutations/apply \
  -d '{"operationId":"PUT /v2/web-app","keys":{"name":"/csp/fd-demo"},"proposed":{"Description":"x"},"fingerprint":"any"}'
# → 403 SAFE_MODE_ON

# disarmed tab: FlightDeck's own application cannot be disabled
curl -s -b "$COOKIE" -H 'X-FlightDeck-Tab: qs' -H 'X-FlightDeck-Safe-Mode: disarmed' \
  -H 'Content-Type: application/json' -X POST http://localhost:52780/api/flightdeck/v1/mutations/apply \
  -d '{"operationId":"PUT /v2/web-app","keys":{"name":"/api/flightdeck"},"proposed":{"Enabled":false},"fingerprint":"<from preview>","confirmation":"/api/flightdeck"}'
# → 403 SELF_PROTECTION with "This web application serves FlightDeck. Disabling it would lock you out."
```

`scripts/dev/check-mutation-enforcement.sh` automates both, for every mutating route this feature
adds, and for `POST /v1/rest/execute` with POST, PUT, PATCH and DELETE.

## 5. Concurrent change (SC-005)

1. In the UI, disarm, open `/csp/fd-demo`, edit Description, open the dry-run.
2. From a shell: `curl -u _SYSTEM:SYS -H 'Content-Type: application/json' -X PUT
   'http://localhost:52780/api/admin/v2/web-app?name=/csp/fd-demo' -d '{"Timeout":901}'`
3. Click `Apply`.

Expected: §9 message 17, the diff now shows `Timeout` current 901, the typed confirmation (if any)
is cleared, nothing was written; confirming again applies only Description, and Timeout stays 901.

## 6. REST executor confinement (SC-009)

`frontend/e2e/rest-confinement.spec.ts` posts, through the executor, paths such as
`http://example.com/`, `//example.com/x`, `/api/../../etc`, `/%2e%2e/`, `\\host\share`, and a
`Host` header override. Expected: every path is refused with 400 `TARGET_OUTSIDE_INSTANCE`, the
header with 400 `CREDENTIAL_HEADER`, and no network connection leaves the container (checked with
the container's connection table before and after).

## 7. Credential audit extended (SC-010)

After a session that edits applications, runs test requests, exports the trail and copies `curl`:
grep the export, the clipboard text, `sessionStorage`, browser cookies and
`/durable/iris/mgr/messages.log` for the test password and `Authorization`. Expected: 0 findings;
the copied `curl` contains `-u '<user>:<password>'` literally.

## 8. Trail lifetime

1. Apply one change; reload the tab. Expected: the trail still lists it.
2. Duplicate the tab. Expected: the duplicate shows the same entries, starts in safe mode; a new
   change in the duplicate does not appear in the original.
3. Sign out and back in. Expected: the trail is empty.
4. Force expiry (feature 001 quickstart). Expected: after re-authentication the trail is empty and
   an open dry-run is restored with recomputed rows.

## 9. Limited mode on IRIS 2026.1

```bash
cd frontend && FLIGHTDECK_PORT=52791 npx playwright test --project limited
FD_DEV_CONTAINER=fd-v1-iris-1 scripts/dev/test-backend.sh
```

Expected: web application reads and writes work (all 8 operations are available there, decided by
the capability map), and the explorer discovers services.

## 10. Design review

Feature 001's design review checklist in both themes, plus `contracts/ui-pattern.md` §4 against
`docs/prototype.html`'s dry-run, and axe with no violations on the three web-apps sections, the
dry-run, the trail and the pattern catalog (fixture build).
