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
