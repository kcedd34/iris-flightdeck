# Feature 003 sign-off (T079, T080), 2026-09-17

Permissions and security: the privilege chain with provenance, impact analysis inside the shared
dry-run, the last-administrative-access predicate, and secret material that is never displayed.
Run from the working tree: the changes are not committed, so every Docker install was built from the
files as they stand.

## Static gates

| Gate | Result |
|---|---|
| `scripts/build/check-generated.sh` | up to date; `check-descriptors` ok (21 entity types, 62 mutations); `check-secrets` ok (54 candidate fields, 20 declared, 42 exempted) |
| `scripts/build/check-dist.sh` | up to date |
| `npm run lint` | clean (one unused import in `e2e/security.spec.ts` removed) |
| `npm run check:tokens` | ok |
| `npm run check:dialect` | ok (9 declared exceptions) |
| `npm run check:mutation-boundary` | ok (3 declared exceptions) |
| `npm run contrast` | ok, both themes |
| `npm run test` (Vitest) | 14/14 |
| `npm run build` (gates + `check:secrets` + tsc + vite + `check-no-fixtures`) | ok |
| `python3 -m unittest scripts/verify/test_verify_platform.py` | OK (11 tests) |

`check-secrets.py` runs inside `check-generated.sh` **and** in the npm build chain, so the 12 real
secrets this feature introduces cannot reach a build without being declared or exempted.

## Fresh installs

Each was `docker compose down -v` then `up -d --build`, with the demo, then the whole backend suite,
every Playwright project and both enforcement scripts.

| Install | Ready | Backend `%UnitTest` | Playwright | Enforcement |
|---|---|---|---|---|
| IRIS CE 2026.2 (`iris-community:2026.2-zpm`, port 52780) | 15 s | 151/151, 33 classes | 93 passed, 12 skipped | safe mode ok; mutation ok |
| IRIS for Health 2026.2 (`irishealth-community:2026.2-zpm`, port 52792, project `fd-health`) | 15 s | 151/151 | 93 passed, 12 skipped | safe mode ok; mutation ok |
| IRIS CE 2026.1 (`iris-community:2026.1-zpm`, port 52791, project `fd-v1`, limited mode) | 15 s | 151/151 | 100 passed, 5 skipped | safe mode ok; mutation ok |

The Playwright runs carry `FD_CONTAINER` set to the install under test, so the docker-backed checks
run rather than skip: no outbound connection from the executor (`rest-confinement`), no credential in
the IRIS logs (`audit`), the pattern catalog (`pattern`) and the secret sweep (`secrets`).

Every install ran the same backend set (`test-backend.sh` fails when a test class in the repository
did not run) and the same Playwright projects. The skips are the tests whose precondition the
install does not present, each with its reason: on 2026.2 the `limited` project skips because
nothing is unavailable; on 2026.1 the wallet secret write is withheld, so the secret tests and the
user-listing part of `last-admin` skip with the platform's message.

The gates and the unit tests were re-run after the last test change: lint, tokens, dialect (10
declared exceptions), mutation-boundary, secrets and Vitest 14/14.

## Defects found by the matrix and fixed

1. **A fresh install failed outright.** `backend/cls/FlightDeck/Mutation/secret-exemptions.json`, the
   build data behind `check-secrets`, sat inside the class tree, and the ZPM module imports that tree
   whole: `ERROR! Unable to import file ... as this is not a supported type`, then
   `FLIGHTDECK INSTALL FAILED`. The developer instance survived because it was already installed, so
   only a clean install could show it. The file moved to `scripts/build/secret-exemptions.json`.
   Nothing under `backend/cls` may be anything but a class.
2. **The sign-in refusal lost its actionable line.** The account-focused message introduced for the
   `%Admin_Wallet` 404 replaced the privilege message for the 403 case too, dropping PRD message 2's
   "Ask your instance administrator for access." It is back, after the sentence that names the
   account rather than the instance.
3. **`scripts/dev/wait-ready.sh` read the wrong install.** It always ran `docker compose logs iris`
   in the default project, so waiting for the 2026.1 or IRIS for Health install reported the 2026.2
   one as ready in 0 s. It now reads `docker logs $FD_CONTAINER` when that is set.
4. **The last-administrator line of `check-mutation-enforcement.sh` asserted nothing.** It printed
   `ok` with `blocked=False notice=False` whatever came back, because it only tested whether the keys
   existed. It now fails unless the preview answers 200 with the declared grade, a fingerprint, no
   block and no incomplete-check notice; probed by pointing it at a role that does not exist
   (`FAIL ... HTTP 404`). The affirmative block and the partial-mode notice stay in the `last-admin`
   and `security` projects, which are allowed to change roles.

## Quickstart (T080)

Run as written on IRIS CE 2026.2 unless stated.

- §0 to §3 ran as written, after the corrections below.
- §4, §5, §8 and §10 are the `permissions`, `security` and `audit` Playwright projects, which drive
  the same screens and assert the same outcomes; both themes were checked by hand in T077.
- §6 complete mode (the affirmative block) is the `last-admin` project, which narrows the live
  instance to a single administrative access, reads the refusal, and restores it; partial mode is
  the `security` project's wallet-only administrator. The curl form in §6 was exercised through
  `check-mutation-enforcement.sh`, which signs in to a cookie jar and previews the same operation.
- §7 ran by hand as well: `docker exec ... grep -rlF '<secret>' /durable/iris/mgr --include='*.log'`
  found nothing, and the `secrets` project asserts the same for the export, the clipboard and browser
  storage.
- §9 is the `limited` project on the 2026.1 install, including the encryption writes declared
  unavailable with the policy reason naming "System Administration > Encryption".

**Corrected in the quickstart:**
- §0 now gives the full command for the second and third installs, each under its own compose
  project, and tells `wait-ready.sh` which container to read. It also states that the container
  carries its own copy of the repository, so backend changes need `up -d --build`; `load-backend.sh`
  reaches only a container that mounts the working tree. Two hours of the matrix were spent on a
  reload that could not take effect.
- §3 now sets `FD_CONTAINER` so the docker-backed checks run instead of skipping, and warns that two
  Playwright runs cannot be in flight at once: they share the frontend dev server's port, so a second
  run answers from the first run's install. That is how a first 2026.1 run reported eight failures
  that did not reproduce.
- §11 now runs the installs one at a time and includes `check-safe-mode-enforcement.sh`.

## What the 2026.1 matrix changed (the first run of every project on that version)

Features 001 and 002 ran only a subset of the Playwright projects on IRIS 2026.1. Running all of
them there for the first time found five things, all of them fixed:

1. **The fixtures spoke v2 paths to a v1 instance.** `e2e/setup/users.ts` called
   `/security/users`, `/wallet/collections` and `/security/ssl-configurations`; on the v1 dialect a
   collection is the singular path with a trailing slash (`/security/user/`, `/wallet/`), so the
   fixtures created nothing and six tests failed as if the feature were broken. The helper now maps
   those paths, in the file already declared as a dialect-boundary exception.
2. **The test helper repeated the expiry-sentinel bug.** `last-admin` counted administrators with
   `new Date(ExpirationDate) < new Date()`, and IRIS 2026.1 reports "never expires" as
   `1840-12-31`, so every account looked expired and no administrator was counted. The helper now
   honours the sentinel, as `FlightDeck.Domain.Facts.Expired` does.
3. **Wallet secret writes are withheld on the v1 dialect.** That version's API wants a different
   body (`Secret` an object, plus `AllowedHosts`, `RequireTLS` and an object `Usage`), probed field
   by field and recorded in `verification/README.md`. FlightDeck does not guess the shape of a
   secret: the operation is withheld with the platform's own words and the native path, the demo
   installer skips the demo secret with the same message, and the `secrets`, `security` and `audit`
   tests skip or take the other path by asking the capability map. `gen-v1-dialect.py` now lets a
   deliberate withhold override route discovery (the route exists; FlightDeck declines it).
4. **Two tests asserted a full instance.** `session` hard-coded "58 of 273" and `shell` asserted the
   limited-mode indicator was absent. Both now read the install's own capability summary.
5. **A test that presumes an operation exists is a red run on an install that does not offer it,**
   which reads as a broken application. Every such test now skips with the reason, in the shape
   `rest-confinement`, `audit` and `pattern` already used for Docker.

## Defect 5, found on the 2026.1 install

`scripts/dev/check-mutation-enforcement.sh` read the final "nothing changed" state through
`/api/admin/v2/...`, which a v1 instance answers 404. It reported `FAIL permissions state changed`
and `FAIL IRIS state changed` on an install where nothing had changed — a false alarm in the one
check whose job is to prove nothing changed. It now asks `/api/admin/info` for the version and reads
the same objects under the dialect the install speaks. Verified on all three installs.

## Result

Feature 003 is complete: 80 of 80 tasks. The matrix is green on IRIS CE 2026.2, IRIS for Health
2026.2 and IRIS CE 2026.1, from fresh installs, with the same backend suite and the same Playwright
projects on each. Nothing is committed; the working tree carries the changes.
