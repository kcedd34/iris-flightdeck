# Verification records

Evidence for feature 001. The JSON reports are produced by `scripts/verify/run-both-images.sh`
and validated by `scripts/verify/validate_report.py`.

## Day-1 platform verification (User Story 1), 2026-09-17

| Image | Report | Present | Absent | Inconclusive | Exit |
|---|---|---|---|---|---|
| `intersystemsdc/iris-community:2026.2-zpm` (IRIS 2026.2 Build 221U) | `iris-2026.2.json` | 8 | 0 | 0 | 0 |
| `intersystemsdc/irishealth-community:2026.2-zpm` (IRIS for Health 2026.2 Build 221U) | `irisforhealth-2026.2.json` | 8 | 0 | 0 | 0 |

**Gate (T021): passed.** Probe 2 selects `in_process` on both images. Candidate outcomes on both:
- `in_process`: present;
- `jwt`: present, but not used by design (research R4);
- `loopback_proxy`: absent (the official API rejects the forwarded FlightDeck session).

No area is blocked: there are no inconclusive probes.

### Findings used by later tasks

- **Probe 3, shapes match the spec** on both images.
  - `system-resources`: 56 rows, keys `Name, Seize, Nseize, Aseize, Bseize, BusySet`.
  - `shared-memory`: 28 rows, keys `Description, SMHAllocated, SMHAvailable, SMHUsed, SMTUsed,
    GSTUsed, AllUsed`.

  SHM vital = `100 × ΣSMHUsed / ΣSMHAllocated` (T077).
- **Probe 4, async database metrics.**
  - `POST /v2/database-dir/info?dir=…` returns 202 with a `Location` header (upper-case
    `LOCATION`), whose value points at `/api/admin/v1/async-result?id=…` even when called on v2.
    The id is read from it and polled on `/v2/async-result`.
  - The result was ready on the first poll (about 25 ms).
  - Result keys include `Size` (MB), `AvailableSpace` (MB free inside the database), `MaxSize`
    (MB, 0 = unlimited) and `DiskFree` (string with unit, e.g. `799.42GB`).

  DSK vital (T077) = max over mounted local databases of `used / capacity`, where
  `used = Size − AvailableSpace` and `capacity = MaxSize` when `MaxSize > 0`, otherwise
  `Size + DiskFree` (converted to MB). With unlimited databases on a large disk this is close to 0 %,
  which is accurate.
- **Probe 7, log sources.**
  - `messages.log` is at `/usr/irissys/mgr/messages.log`.
  - `alerts.log` exists on IRIS for Health and is absent until the first alert on IRIS CE.
  - `Ens.Util.Log` is queryable in interoperability namespaces: `USER` on CE; `HSCUSTOM`, `HSLIB`,
    `HSSYS` and `USER` on IRIS for Health.
- **Probe 8**: auditing is enabled by default on both images.

### Script bugs found and fixed during the first run

The first run reported probe 4 `inconclusive`, probe 7 `confirmed_absent` and loopback
`inconclusive`. All three were defects in the script, not the platform:
- the `Location` header lookup was case-sensitive;
- `Ens.Util.Log` was checked from `%SYS`, where interoperability classes are not mapped;
- the loopback candidate's first request was proxied upstream before a session existed.

They were fixed and the run repeated (the table above).

## R4 open items (T046), dev container IRIS 2026.2 CE, 2026-09-17

- **(b) No Basic challenge.** `POST /api/flightdeck/v1/session` with bad credentials returns
  `HTTP/1.1 401 Unauthorized`, `Content-Length: 0` and **no `WWW-Authenticate` header** (checked with
  `curl -si`, for an unknown user and for a real user with a wrong password; the status lines are
  identical). No fallback was needed. The browser-dialog check runs in the e2e invalid-credential test.
- **(c) Application role instead of a public grant.** `fd_e2e_operator` (roles: `%Operator` only)
  signs in with 200 and gets `capabilitySummary` 58/273. The only access to the FlightDeck code
  database comes from `MatchRoles=:FlightDeck_Runtime` (`%DB_USER:R`, created through
  `PUT /v2/security/role`). No public permission was changed.
- **No administrative privilege.** `fd_e2e_none` (no roles) cannot read `%SYS`. The in-process call
  raises `<PROTECT>`, which `FlightDeck.Admin.Client` maps to 403. Sign-in returns 403
  `NO_ADMIN_PRIVILEGE` listing all eleven `%Admin_*:U` privileges, and the IRIS session is ended
  (the next request is 401).
- **(a) IRIS for Health 2026.2**: verified in the compose install run (T075); see `install-runs.md`.


## SysAdmin API findings during implementation

- **`PUT /v2/security/resource` cannot create or update a resource with no public permission.**
  `PublicPermission: ""` returns HTTP 400 with an empty `errors` array, on create and on update,
  while system resources such as `%DB_USER` report `PublicPermission: ""`. Omitting the field
  returns `ERROR #40301 Field 'PublicPermission' is required`. Demo resources therefore use the
  least permission the API accepts, `U` (Constitution I forbids falling back to
  `Security.Resources`). Observed on IRIS 2026.2 Build 221U.
- **IPM `WebApplication` attributes are `Security.Applications` property names.** `AutheEnabled`
  is honored; `PasswordAuthEnabled`/`UnauthenticatedEnabled` are silently ignored, and the app is
  then created unauthenticated (`AutheEnabled=64`). Caught during the first dev install and fixed in
  `module.xml`.
- **`%CSP.REST.DispatchRequest` is `Final`**, and `OnPreDispatch` runs before `DispatchMap`, so the
  safe-mode guard lives in `OnPreDispatch` and still runs before routing.
- **`%CSP.Request.ContentType` has a private setter**, and official handlers return 415 without it.
  `FlightDeck.Admin.Request` subclasses `%CSP.Request` to set it.
- **Declared privilege vs actual behavior: `GET /v2/database-dirs`.** The spec declares
  `(%Admin_Manage:U or %Admin_Operate:U)`, but a user whose only role is `%Operator` (which holds
  `%Admin_Operate:U`) gets HTTP 403 with an empty error. `POST /v2/database-dir/info` for the same
  user returns 202. The capability map follows the spec (Constitution III), so the Disk vital
  reports the API's refusal instead of claiming a requirement the user already meets. Observed on
  IRIS 2026.2 Build 221U.
- **procfs and streams.** `%Stream.FileCharacter` reads nothing from `/proc/stat` and
  `/proc/meminfo` (size 0). `FlightDeck.Native.HostMetrics` reads them through a sequential device.
  Host CPU/memory matched `top`/`free` inside the container (1.8 % vs 2.4 % CPU idle load; 14.9 % vs
  14.9 % memory).
- **`GET /v2/security/ldap/configurations` fails for an `%Operator`-only user** with HTTP 500
  `ERROR #5002 <INVALID OREF>AppendStatementResult+5^%Api.Admin.Util.ClassQuery.1`, although the spec
  declares `(%Admin_Operate:U or %Admin_Secure:U)` and `_SYSTEM` gets 200. The palette shows the
  IRIS error text for that group and marks the search degraded; the other groups are unaffected.
  Observed on IRIS for Health 2026.2 Build 221U.

## SysAdmin API v1 dialect (IRIS 2026.1)

- `v1-api-2026.1.md` / `.json`: coverage of v1 against the v2 specification (173 same shape,
  28 different shape, 72 absent).
- `v1-adapter-spike.md`: cost spike over 5 of the 28 translations.
- `v1-translations-2026.1.md`: the 28 translations verified live by effect through the adapter,
  14/14 test methods in three consecutive runs (`FlightDeck.Test.V1Translations`), with two
  limits:
  - pause and resume of async results are verified as reachable only, because no v1 async task
    supports them;
  - external language server start/stop is verified for `%Java Server` only. **`%Python Server`
    is NOT VERIFIED** (it timed out in the image).
- `v1-native-gaps-2026.1.md`: native providers on v1 and the T101 decision.
  - Disk per database: verified equal to `database-dir/info` on 2026.2 for all 10 databases.
  - Namespace reads: native, verified equal to the official API on 2026.2 over 21 requests;
    writes withheld.
  - Journal: deliberately not native (authorization stays in IRIS).

### Test matrix, 2026-09-17 (fresh compose installs of the final code, after T101)

| Install | Backend | Playwright | Other gates |
|---|---|---|---|
| IRIS CE 2026.2 (`2026.2-zpm`, port 52780) | 56/56 (all classes; v1-only tests log a skip) | 24 passed, 8 skipped (`limited` project skips on v2) | safe-mode enforcement ok |
| IRIS CE 2026.1 (`2026.1-zpm`, port 52791, limited mode) | reduced set 29/29: `V1Translations` 14, `Dialect` 6, `NativeDatabases` 5, `NativeNamespaces` 4 | `limited` project 8/8 | install and demo complete on v1 |

One test guard was corrected during this run. `NativeDatabases.TestCodeDatabaseResourceMatchesApi`
compared against the official lookup whenever `GET /v2/namespace` was available, which on v1 is now
true through the native provider, but `/v2/database-dir` is not. The guard now requires the database
operations; the installer code already did. It was rerun on both installs: 5/5.

Static gates on the same tree: `check-generated`, `check-dist`, verification script unit tests,
`lint`, `check:tokens`, `contrast`, `vitest` (6), `build`.

Findings while installing on 2026.1:
- **The IPM `SystemRequirements` pin (`>=2026.2`) refused the install**; it is now `>=2026.1`.
- **`POST /v1/task` rejects a start date and time already in the past** ("ERROR #7432: Start Date
  and Time must be after the current date and time"); 2026.2 accepted it. The demo tasks now start
  tomorrow on both versions.
- **A user without privileges cannot read `%SYS`**, so the v1 dispatcher cannot be detected for
  them. Detection reports "unknown", the call returns the API's 403, and sign-in refuses for
  privileges, not for the version (e2e on both versions).
