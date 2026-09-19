# Functional coverage: what is implemented, and what has actually run

**Final measurement, 2026-09-19, after the full matrix on all three supported installs.**
The stage-1 measurement that started this work is kept at the end of the document, unedited, because
the distance between the two numbers is the point.

## The number

| | |
|---|---|
| Operations implemented across the six domains | **268** |
| Executed by a test that then read the result back through the official API | **138** |
| Exempt by name, each with its own written reason | **91** |
| No such test yet | **39** |

138 + 91 + 39 = 268. Nothing is rounded, nothing is regrouped, and there is no "other" bucket.

**The gate is red on purpose.** `scripts/build/check-functional-coverage.py` exits non-zero and names
all 39. It is not muted, not marked as a warning and not given a tolerated-gaps list. A gate that goes
green while 39 operations have never been exercised would be the fourth instance of the defect this
project keeps producing — verification that cannot fail — and this file exists because of the first
three.

## What "verified" means here, and what it does not

An operation counts as verified only when a test **made FlightDeck perform it** and then **read the
object back through the official SysAdmin API directly**, asserting on what came back. The recording
is in `frontend/e2e/setup/effect.ts`: the entry is appended after the read-back returns without
throwing, so a failed assertion records nothing. A 2xx status records nothing. A screen rendering rows
records nothing.

It does not mean the operation is correct in every case. It means it was executed once, against a real
instance, and the instance afterwards reported the state the operation claimed to produce.

## The matrix

Run on 2026-09-19, one full Playwright suite per install, each against its own container.

| Install | Port | Result | Operations effect-verified |
|---|---|---|---|
| IRIS Community Edition 2026.2 (`latest-cd`) | 52780 | 267 passed, 36 skipped, 0 failed | **138** |
| IRIS for Health Community Edition 2026.2 | 52792 | 265 passed, 38 skipped, 0 failed | **138** |
| IRIS Community Edition 2026.1 (`latest`, limited mode) | 52791 | 151 passed, 152 skipped, 0 failed | — |

The backend suite (189 methods) passes on all three.

**Why 2026.1 records no effect number.** The functional tests prove an effect by reading back through
the official API *directly*, deliberately not through FlightDeck. On 2026.1 the official API is v1,
whose paths are not the v2 paths — FlightDeck reaches them through its own translation table
(`FlightDeck.Admin.V1Routes`, 208 operations). For the read-back to find the same object on 2026.1 the
test harness would have to use that table too, and a read-back that goes through the thing under test
is not an independent read: it would confirm the translation against itself. So the whole `functional`
project skips on a v1 instance, stating that reason (`frontend/e2e/setup/dialect.ts`), and IRIS 2026.1
stays covered by the `limited` project, which asserts on the capability map's own answers.

The effect numbers published here are therefore **v2 numbers**, and are labelled as such everywhere
they appear.

### Two defects the matrix itself found

1. **The harness set the fixtures switch on the wrong container.** `frontend/e2e/setup/iris.ts` reads
   `FD_CONTAINER`, defaulting to the 2026.2 compose service. Running the matrix against another
   install with only `FLIGHTDECK_PORT` set enabled the pattern catalog on the *default* container, so
   ten `pattern.spec.ts` tests timed out against an install where the catalog was never switched on.
   The fix is in the command, not in the code: every matrix run now passes `FD_CONTAINER` beside
   `FLIGHTDECK_PORT`. Recorded because the failure looked like a product defect and was not one.
2. **The functional project was failing on 2026.1 for a reason that was not a product defect**, which
   is the v1 read-back problem described above. Fourteen tests failed; none of them said anything
   about FlightDeck. They now skip with the reason.

## The 91 exemptions

Every exemption names one operation and carries its own sentence, in
`scripts/build/functional-exemptions.json`. There is no generic entry and no wildcard; the gate fails
if an exemption names an operation that is not shipped, and fails again if an exempted operation turns
out to be verified after all, so the list cannot quietly outlive its reason.

| Category | Count | What it means |
|---|---|---|
| `infrastructure` | 46 | Needs something a stock container does not have: a mirror, an ECP partner instance, an MFT provider, a real OAuth partner, an external language runtime |
| `no safe target` | 34 | Destroys, purges or reconfigures something the live instance needs, with no throwaway subject that can be created and removed |
| `declined` | 11 | FlightDeck refuses to perform it on every version, by decision, with a native path stated in the interface |

LDAP was the one infrastructure case taken rather than exempted: three of its four operations need no
directory server at all, because the configuration is stored on the instance whether or not anything
answers at the other end. They are verified. The fourth,
`POST /v2/security/ldap/test`, authenticates against the directory and is exempt by name. Standing up
an OpenLDAP container would have proved that IRIS can reach a container on the same docker network,
which is not what a user points this at.

## The 39 with no test yet

Named, by domain. Seven of them were attempted during this work and withdrawn rather than forced; the
reason is written in the spec file at the point where the test would have gone.

### 2. Permissões — 7

- `POST /v2/security/sql-privilege/grant`, `POST /v2/security/sql-privilege/revoke` — **attempted and
  withdrawn.** On this instance the grant was already in place and FlightDeck answered "nothing to
  apply", which is the mutation layer working correctly and the operation not being exercised. The
  backend `V1Translations` suite drives both; what is missing is the recorded read-back.
- `POST /v2/security/sql-admin-privilege/grant`, `POST /v2/security/sql-admin-privilege/revoke`
- `POST /v2/security/sql-column-privilege/grant`, `POST /v2/security/sql-column-privilege/revoke`
- `GET /v2/security/sql-column-privileges` — **a test exists and never runs.** It omits the required
  `object` query parameter, the instance answers 400, and the test's own skip takes the failure out of
  sight. This is exactly the pattern the gate was built to catch, and it was the gate that surfaced it.

### 3. Segurança e segredos — 5

- `PUT /v2/wallet/secret`, `DELETE /v2/wallet/secret` — **attempted and withdrawn.** Their action maps
  `name` to the collection while the official operation reads it as the secret, and no parameter shape
  tried satisfied both. `secrets.spec.ts` exercises them through the interface; what is missing is the
  recorded read-back.
- `POST /v2/security/audit/record/copy`
- `PUT /v2/security/web-auth`, `POST /v2/security/web-auth/smtp-password`

### 4. Tarefas — 4

- `POST /v2/task/suspend`, `POST /v2/task/resume`, `POST /v2/task/run` — **attempted and withdrawn.**
  Suspension is reported on the list row and did not move within ten seconds of the apply on this
  instance, which is a question about the platform's scheduler rather than about the mutation layer.
  `tasks.spec.ts` exercises all three through the interface.
- `POST /v2/task/manager/run`

### 5. Sistema operacional — 19

- `PUT /v2/device/settings`, `PUT /v2/device/subtype`, `DELETE /v2/device/subtype`
- `PUT /v2/doc-db`, `DELETE /v2/doc-db`
- `PUT /v2/ext-lang-server`, `DELETE /v2/ext-lang-server`, `POST /v2/ext-lang-server/start`,
  `POST /v2/ext-lang-server/stop`, `GET /v2/ext-lang-server/activity` — the destructive test for
  `DELETE` is written; its own setup was refused by this instance, so it skipped and recorded nothing.
- `PUT /v2/fs-access-purpose`, `DELETE /v2/fs-access-purpose`, `PUT /v2/fs-access-purpose/path`,
  `DELETE /v2/fs-access-purpose/path`, `GET /v2/fs-access-purpose/paths`
- `PUT /v2/license/key`, `POST /v2/license/key/validate`, `PUT /v2/license/server`
- `DELETE /v2/web-session`

### 6. Logs — 4

- `POST /v2/journal/switch-dir`, `POST /v2/journal/file/integrity-check`
- `GET /v2/journal/file/record`
- `GET /v2/security/audit/record`

### 1. Web apps e APIs — 0

All eight operations of the domain are effect-verified.

## Coverage by domain

| Domain | Implemented | Effect-verified | Exempt | No test yet |
|---|---|---|---|---|
| 1. Web apps e APIs | 8 | 8 | 0 | 0 |
| 2. Permissões | 31 | 24 | 0 | 7 |
| 3. Segurança e segredos | 89 | 29 | 55 | 5 |
| 4. Tarefas | 24 | 17 | 3 | 4 |
| 5. Sistema operacional | 102 | 51 | 32 | 19 |
| 6. Logs | 14 | 9 | 1 | 4 |
| **Total** | **268** | **138** | **91** | **39** |

## What executing these operations for the first time found

Nothing here was found by reading code. Every item below was found by making FlightDeck perform the
operation against a live instance and then asking the instance what had happened.

### Defects in FlightDeck, fixed

- **Creates with an instance-assigned key were unreachable.** `FlightDeck.Mutation.Service` demanded
  every key of the entity type before applying, but for a create the instance assigns the key, so the
  request was refused with `MISSING_KEY` before it was ever sent. It affected `POST /v2/task`,
  `POST /v2/database-dir`, `POST /v2/security/oauth2/server/client` and
  `POST /v2/security/oauth2/client/server-definition` — four operations that could not be performed at
  all through the portal, on any version, and that every existing test reported as covered.
- **Web sessions were listed with no name and no key.** `FlightDeck.Domain.EntityTypes` declared the
  key field of `system/web-session` as `SessionId`; the instance returns `ID`. Every row rendered
  blank and no row could be opened.

### Findings in IRIS, not in FlightDeck

Reported here rather than worked around:

- `PUT /v2/security/service` silently ignores `Description`: it answers 200 and the value does not
  change. The test asserts on a field the operation does change.
- `PUT /v2/security/ldap/configuration` with an empty body throws `<UNDEFINED>` inside
  `Security.LDAPConfigs`.

### Fixture shapes that were wrong because nothing had ever used them

`%Service_Console` does not exist (`%Service_Terminal` does); `%Service_CacheDirect` is not licensed on
Community; a service's `Description` is read-only; audit events are a fixed catalogue addressed by
`Source`/`Type`/`Name` rather than created freely; a task create needs about thirty-five fields with
word enumerations and a `StartDate` in the future; `allowType` is `AllowClass`, not `0`; the `name` key
of a percent-class-access grant is the **web application**, not the class; a wallet collection is
defined by `EditResource`/`UseResource`; a wallet secret's `Type` must be `%Wallet.KeyValue`; a task's
`Suspended` flag lives on the list row and not on the detail; `LDAPHostNames` is an array and
`LDAPBaseDNForGroups` is required.

---

# Appendix: the stage-1 measurement, unedited

**Stage 1 measurement, 2026-09-18. Nothing was fixed and no test was written to produce this.**

`check-coverage.py` answers "is every shipped operation reachable?" and the answer is yes: 268 of 268.
This document answers a different question — **how many of them has anything ever executed against a
real instance** — and the answer is very different.

## The number

| | |
|---|---|
| Operations shipped across the six domains | **268** |
| Executed through FlightDeck against a live instance during the full suite | **103** |
| **Never executed at all** | **165** |

Of the 103 that did run:

| | |
|---|---|
| Reads | 83 |
| Mutations | 20 |
| Called but never answered 2xx | 1 (`POST /v2/security/ssl-configuration/test`, which is only ever pointed at a server that is not there) |

## How this was measured

Not by scanning text. `FlightDeck.Admin.Client.Call` is the single point every official API call
passes through, and it receives the operation as `method _ " " _ path` — the same form the coverage
document uses. A temporary probe recorded every operation it dispatched, and its HTTP status, into a
global. The full backend suite (189 methods) and the full Playwright suite then ran against a live
IRIS CE 2026.2 instance, and the global was read back.

The probe was added for this measurement only and the class was restored from git afterwards, so
nothing in the product carries it. **Only calls made by FlightDeck are counted.** The end-to-end
harness also talks to the SysAdmin API directly to build fixtures; those calls do not go through the
client and are deliberately not counted, because a fixture creating a user is not FlightDeck
exercising "create a user".

**Two caveats on the number, both making 103 an over-count rather than an under-count:**

1. Two tests failed during the measuring run (`webapps` privilege refusal, `security` partial-mode).
   Whatever they would have exercised beyond that point did not run. The same suite passed 140/0 on
   the same container earlier, so this is state left by previous runs rather than a regression; it is
   listed here because it was not investigated, per the instruction not to fix anything at this stage.
2. The v1 dialect was not measured. A handful of operations are exercised only by the `limited`
   project on IRIS 2026.1, which skips on 2026.2.

## Effect verification, which is the harder half of the question

"Executed" is not "verified". For the 20 mutations that ran, the question is whether any test reads
the result back independently instead of trusting the response:

| | |
|---|---|
| Mutations whose test file performs an independent read-back through the official API | **13 of 20** |
| Mutations verified only by what the screen says, or by the status alone | **7 of 20** |

The seven: `DELETE /v2/security/resource`, `DELETE /v2/security/user`, `DELETE /v2/wallet/secret`,
`POST /v2/security/sql-privilege/grant`, `POST /v2/security/sql-privilege/revoke`,
`POST /v2/task/resume`, `PUT /v2/security/resource`.

**This 13 is an upper bound, and should be read as one.** It is measured at file granularity: the
test file that fires the operation contains an independent read somewhere. It does not prove the read
is of that object, after that mutation. A per-assertion measurement is what the stage-2 gate has to
do properly; this number exists to size the problem, not to close it.

The 83 reads are "verified" in the sense that the screens assert on their content rather than on a
status code. That is real but weaker than it sounds: a list rendering rows proves the operation
answered something shaped correctly, not that the values are right.

## Why this matters here specifically

This project has now had three defects of exactly one kind — something counted as done that had never
actually run:

- the canvas series that never drew and passed every assertion about it;
- `tasks.spec.ts`, whose correlation assertion named an element that did not exist and a string no
  code produced, and which had never executed because its skip was always taken;
- the double-encoded assets, which no test could reach because every project pointed at the Vite dev
  server rather than at the server real installs use.

All three share a shape: **verification that cannot fail.** 165 operations that have never been
executed are 165 more opportunities for the same thing, and the coverage gate reports them as covered
because a descriptor exists.
