# Quickstart: Validating Feature 003

**Feature**: `003-permissions-security`

Runnable checks that prove the feature end to end. Contracts:
[`contracts/flightdeck-api-003.openapi.json`](./contracts/flightdeck-api-003.openapi.json) and
[`contracts/ui-pattern-delta.md`](./contracts/ui-pattern-delta.md). Data shapes:
[`data-model.md`](./data-model.md). Decisions and probes: [`research.md`](./research.md).

## 0. Prerequisites

- The prerequisites of features 001 and 002 (Docker Engine, Node 20).
- A fresh install with demo data:

```bash
docker compose down -v && docker compose up -d --build && scripts/dev/wait-ready.sh 600
```

- For limited mode, the IRIS 2026.1 install on port 52791; for the second edition, IRIS for Health.
  Each runs under its own compose project, and `wait-ready.sh` must be told which container to read,
  or it reports the default project as ready:

```bash
IRIS_IMAGE=intersystemsdc/iris-community:2026.1-zpm FLIGHTDECK_PORT=52791 \
  docker compose -p fd-v1 up -d --build && FD_CONTAINER=fd-v1-iris-1 scripts/dev/wait-ready.sh 600
IRIS_IMAGE=intersystemsdc/irishealth-community:2026.2-zpm FLIGHTDECK_PORT=52792 \
  docker compose -p fd-health up -d --build && FD_CONTAINER=fd-health-iris-1 scripts/dev/wait-ready.sh 600
```

The container holds its own copy of the repository: after changing backend code, rebuild the image
(`up -d --build`). `scripts/dev/load-backend.sh` only reaches a container that mounts the working
tree.

## 1. Static gates

```bash
scripts/build/check-generated.sh     # capability data, OpenAPI class, descriptors, secret fields
scripts/build/check-dist.sh
cd frontend
npm run lint && npm run check:tokens && npm run check:dialect && npm run check:mutation-boundary \
  && npm run contrast && npm run test && npm run build
```

Expected: all pass, including the new `check-secrets` step, which fails when a field of the official
specification whose name suggests a secret is neither declared secret in a descriptor nor exempted
with a reason.

## 2. Backend tests

```bash
FD_DEV_CONTAINER=iris-flightdeck-iris-1 scripts/dev/test-backend.sh
```

Expected: every class runs (the script fails if one does not) and passes, including the effective
privilege traversal, the last-administrator predicate in both modes, the impact providers, the
policy-declared unavailability and the secret masking.

## 3. End-to-end

```bash
cd frontend && FLIGHTDECK_PORT=52780 FD_CONTAINER=iris-flightdeck-iris-1 npx playwright test
```

`FD_CONTAINER` names the install under test, so the docker-backed checks run instead of skipping.
Run one suite at a time: every run serves the frontend on the same port, so two runs against
different installs answer from whichever dev server started first.

Expected: the projects of features 001 and 002 keep passing, plus `permissions`, `security`,
`secrets` and `last-admin`. Docker-backed checks skip with a stated reason when `FD_CONTAINER` is
unreachable.

## 4. The chain, by hand (UC05-1)

1. Open the permissions domain, users section, and select the demo user that holds a role through an
   inherited role.
2. Read the effective privileges panel.

Expected: each privilege names the resource and permission, and every chain that grants it, including
the inherited step. A privilege with no chain never appears; a chain that could not be expanded says
so.

## 5. Impact before a removal (UC05-2)

1. Disarm safe mode, open the demo role that grants the demo resource, and remove the resource.
2. Read the dry-run's impact block before confirming, then cancel.

Expected: the users who lose access and the objects that become inaccessible are listed; cancelling
changes nothing. With a session that cannot read users, the impact block says it could not be
determined and why, and never shows an empty list.

## 6. Last administrative access (UC05-3, spec FR-010)

```bash
# complete mode: the predicate can read what it needs
curl -s -b "$COOKIE" -H 'X-FlightDeck-Tab: qs' -H 'X-FlightDeck-Safe-Mode: disarmed' \
  -H 'Content-Type: application/json' -X POST http://localhost:52780/api/flightdeck/v1/mutations/apply \
  -d '{"operationId":"PUT /v2/security/role","keys":{"name":"<the only role granting %Admin_Secure>"},
       "proposed":{"Resources":[]},"fingerprint":"<from preview>","confirmation":"<role>"}'
# -> 403, the reason names %Admin_Secure and states that %All, delegated access and LDAP were not counted
```

Then repeat as a user who cannot read users:

Expected: no block. The dry-run states that the check was incomplete, names what it could not read,
and requires the reinforced confirmation. The trail entry of the applied change carries
`checkMode: partial`.

## 7. Secrets never come back (UC06-1, SC-003)

1. Create a wallet collection and a secret in it; reopen the secret.
2. Replace the secret, export the trail, and copy any request the explorer offers.

```bash
grep -riE "the secret value you typed" <trail export> <sessionStorage dump> \
  ; docker exec iris-flightdeck-iris-1 sh -c "grep -rlF '<secret>' /durable/iris/mgr --include='*.log'"
```

Expected: the detail offers only replace and delete and shows no value; 0 findings in the export, the
browser storage and the IRIS logs.

## 8. Expiry and the attention list (UC06-2)

1. Install an X.509 credential whose certificate expires inside the alert window (probe P3).
2. Open the security domain, X.509 section, then the home panel.

Expected: the list shows days remaining and the `expiring` band; the home panel's attention section
lists the same item and opens it in one click. A TLS configuration, whose validity the platform does
not report, shows "validity not reported by the platform" and is not counted as valid.

## 9. A section the instance does not offer (UC06-3)

On the IRIS 2026.1 install, or as a user without `%Admin_Secure`:

Expected: the unavailable sections are disabled with their reason, and every other section works. The
encryption section is readable and its writes are disabled with the policy reason, which names
"System Administration > Encryption".

## 10. Audit writes (spec FR-021)

1. Copy audit records to another namespace: reinforced confirmation naming the destination.
2. Purge audit records: maximum confirmation with the consequence stated.

Expected: both run through the shared dry-run, both appear in the trail, and reading audit records is
absent from this feature.

## 11. Matrix and sign-off

```bash
# IRIS CE 2026.2, IRIS for Health 2026.2, IRIS CE 2026.1 — one install at a time
FD_DEV_CONTAINER=<container> scripts/dev/test-backend.sh
cd frontend && FLIGHTDECK_PORT=<port> FD_CONTAINER=<container> npx playwright test
scripts/dev/check-safe-mode-enforcement.sh http://localhost:<port>
scripts/dev/check-mutation-enforcement.sh http://localhost:<port>
```

Expected: the same backend set on every version, every Playwright project green or skipped with a
stated reason, and the enforcement script refusing every mutating route while armed. Record it in
`verification/feature-003-signoff.md`.
