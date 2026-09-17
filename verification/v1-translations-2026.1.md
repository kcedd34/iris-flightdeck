# SysAdmin API v1 translations, live effect verification (IRIS 2026.1), 2026-09-17

Result of verifying the 28 different-shape translations in `scripts/build/v1-translations.json`
against a live instance. Each translation was called through the adapter
(`FlightDeck.Admin.Client.Call` with the v2 operation), never through a hand-written v1 request.

The effect was then read from a source outside the SysAdmin API wherever one exists. HTTP 200
alone never passes.

Companion to `v1-api-2026.1.md` and `v1-adapter-spike.md`.

**Target**: `intersystemsdc/iris-community:2026.1-zpm`, IRIS 2026.1.0.234.1, container `fd-dev1`,
dialect detected `v1`.

**Test**: `backend/test/FlightDeck/Test/V1Translations.cls`, run with
`FD_DEV_CONTAINER=fd-dev1 scripts/dev/test-backend.sh V1Translations`.
- 14 test methods, 125 assertions (including a coverage guard over all 28 operationIds).
- **14/14 passed in three consecutive runs.**
- On IRIS 2026.2 (dialect `v2`) the class logs a skip for every method; the full backend suite is
  41/41 there.

**Fixtures**, created and removed by the test:
- table `FDTest.Orders`;
- user `fdt_grantee`;
- wallet collection `FDT_Vault`;
- a key file with admin `fdtkeyadmin`, deactivated and deleted at the end;
- task `FDT adapter task`;
- a disposable `job` process;
- async audit-record listings;
- an `OAuth2.Server.AccessToken` row.

## Per operation

"Independent" means the effect source is not the SysAdmin API. For list and get operations, the
source is the stored platform state that the answer must match.

| # | v2 operation | v1 request sent by the adapter | Effect source | Independent | Result |
|---|---|---|---|---|---|
| 1 | `GET /info` | `GET /info` (unversioned) | `apiVersion` = 1 and `username` = `$username` of the caller | Partly (identity only) | Pass |
| 2 | `GET /v2/wallet/collections` | `GET /v1/wallet/` | `FDT_Vault` listed while `%Wallet.Collection.Exists` = 1 | Yes | Pass |
| 3 | `GET /v2/wallet/collection` | `GET /v1/wallet?name=` | `UseResource` equals the stored `%Wallet.Collection` value (`%DB_USER:READ`) | Yes | Pass |
| 4 | `PUT /v2/wallet/collection` | `PUT /v1/wallet?name=` (body unchanged) | `%Wallet.Collection.Exists` 0 → 1 | Yes | Pass |
| 5 | `DELETE /v2/wallet/collection` | `DELETE /v1/wallet?name=` | `%Wallet.Collection.Exists` 1 → 0 | Yes | Pass |
| 6 | `GET /v2/security/encryption/data-element-keys` | `GET /v1/security/encryption/key/data-element/` | The key activated by the test (diff of `$SYSTEM.Encryption.ListEncryptionKeys()` before and after activation) is listed, and every listed id is active | Yes | Pass |
| 7 | `GET /v2/security/sql-admin-privileges` | `GET /v1/security/sql-privilege/admin/` | `%CREATE_TABLE` listed while `Security.SQLAdminPrivilegeSet.CreateTable` = 1 | Yes | Pass |
| 8 | `GET /v2/security/sql-column-privileges` | `GET /v1/security/sql-privilege/column/` | `Amount/UPDATE` listed while `%SQL.Manager.CatalogPriv:UserColumnPrivs` holds it | Yes | Pass |
| 9 | `POST /v2/security/sql-privilege/grant` | `PUT /v1/security/sql-privilege` (same query) | `$SYSTEM.SQL.Security.CheckPrivilege(SELECT)` = 1 | Yes | Pass |
| 10 | `POST /v2/security/sql-privilege/revoke` | `DELETE /v1/security/sql-privilege` | `CheckPrivilege(SELECT)` 1 → 0 | Yes | Pass |
| 11 | `POST /v2/security/sql-admin-privilege/grant` | `PUT /v1/security/sql-privilege/admin` | `Security.SQLAdminPrivilegeSet(USER‖fdt_grantee).CreateTable` = 1 | Yes | Pass |
| 12 | `POST /v2/security/sql-admin-privilege/revoke` | `DELETE /v1/security/sql-privilege/admin` | `CreateTable` 1 → 0 | Yes | Pass |
| 13 | `POST /v2/security/sql-column-privilege/grant` | `PUT /v1/security/sql-privilege/column` | `UserColumnPrivs` contains `Amount/UPDATE` | Yes | Pass |
| 14 | `POST /v2/security/sql-column-privilege/revoke` | `DELETE /v1/security/sql-privilege/column` | `UserColumnPrivs` no longer contains it | Yes | Pass |
| 15 | `POST /v2/security/oauth2/revoke` | `POST /v1/security/oauth2/server/revoke?user=` | `OAuth2.Server.AccessToken.%ExistsId` 1 before → 0 after | Yes | Pass |
| 16 | `POST /v2/task/suspend` | `PATCH /v1/task?id=` `{"Action":"Suspend"}` (`LeaveInQueue` true or absent) or `{"Action":"SuspendAndReschedule"}` (`LeaveInQueue` false) | `%SYS.Task.Suspended` = 1 and = 2 respectively | Yes | Pass |
| 17 | `POST /v2/task/resume` | `PATCH /v1/task?id=` `{"Action":"Resume"}` | `%SYS.Task.Suspended` → 0 | Yes | Pass |
| 18 | `POST /v2/task/manager/suspend` | `PATCH /v1/task/manager` `{"Action":"Suspend"}` | `%SYS.TaskSuper.SuspendGet()` = 1 | Yes | Pass |
| 19 | `POST /v2/task/manager/resume` | `PATCH /v1/task/manager` `{"Action":"Resume"}` | `SuspendGet()` → 0 | Yes | Pass |
| 20 | `POST /v2/task/manager/run` | `PATCH /v1/task/manager` `{"Action":"Run"}` | TASKMGR process terminated first; `%SYS.TaskSuper.TASKMGRStatus()` 0 → 1 | Yes | Pass |
| 21 | `POST /v2/process/suspend` | `PATCH /v1/process?id=` `{"Action":"Suspend"}` | `%SYS.ProcessQuery.State` HANG → SUSP | Yes | Pass |
| 22 | `POST /v2/process/resume` | `PATCH /v1/process?id=` `{"Action":"Resume"}` | `State` SUSP → HANG | Yes | Pass |
| 23 | `POST /v2/process/terminate` | `DELETE /v1/process?id=` | `%SYS.ProcessQuery.%ExistsId` → 0 | Yes | Pass |
| 24 | `POST /v2/async-result/cancel` | `PATCH /v1/async-result?id=` `{"Action":"Cancel"}` | Stored `Api.Admin.v1.Util.AsyncTask.State` Queued → Canceled, `TimeStarted` empty | Stored state of the API's own task record | Pass |
| 25 | `POST /v2/async-result/pause` | `PATCH /v1/async-result?id=` `{"Action":"Pause"}` | 409 with error id `CannotPauseAsyncTask`; stored state unchanged | See note A | Pass (reachability only) |
| 26 | `POST /v2/async-result/resume` | `PATCH /v1/async-result?id=` `{"Action":"Resume"}` | 409 with error id `CannotResumeAsyncTask`; stored state unchanged | See note A | Pass (reachability only) |
| 27 | `POST /v2/ext-lang-server/start` | `PATCH /v1/els?name=` `{"Action":"Start"}` | `$system.external.isServerRunning("%Java Server")` 0 → 1 | Yes | Pass |
| 28 | `POST /v2/ext-lang-server/stop` | `PATCH /v1/els?name=` `{"Action":"Stop"}` | `isServerRunning` 1 → 0 | Yes | Pass |

## Notes

**A. Pause and resume cannot succeed on v1, so only reachability is verified.** On 2026.2 the
generic `%Api.Admin.Util.AsyncTask.Pause` and `Resume` always answer 409 (source read on 2026.2).
Only `AsyncTaskSysBackground` overrides them, and that class is used by the `database-dir`
maintenance operations: compact, defragment, expand-volume, integrity-check, modify-size and
truncate.

v1 has no such subclass: the async classes are `AsyncTask`, `AsyncTaskEndpoint`, `AsyncTaskList`
and `RecordListTask`. The `database-dir` operations are also absent on v1. Every v1 async task
therefore refuses pause and resume.

The test proves the translated request reaches the task's own `Pause` and `Resume`: it gets the
specific error id, not a validator error, and the state of a terminal (Finished) task is
unchanged. On v1 FlightDeck has no async task it could offer to pause, so no screen depends on a
successful pause.

**B. Cancel succeeds only while a task is Queued.** This matches the v2 source of
`AsyncTask.Cancel`. The fixture floods the async queue with audit-record listings until one is
still `Queued` (typically after 3 submissions). A queued task can start between the state read and
the cancel. The test then accepts a 409 only if the stored state shows the task left `Queued`, and
tries the next queued task.

**C. Task manager Run** answers 409 `TASKMGR is already running` when it is running. The fixture
terminates the TASKMGR process (found in `%SYS.ProcessQuery` by routine `%SYS.TaskSuper`) and
confirms status 0 before the call.

**D. External language servers**: only `%Java Server` was exercised. `%Python Server` start timed
out (504) in this image on both manual attempts; that is an environment limit of the container,
not the translation, which is identical apart from `name`.

**E. OAuth2 revoke** answers 200 whether or not anything was revoked. That is exactly why the
fixture token row is checked before and after. No authorization server is configured in the
container, so the row is inserted directly as a test fixture.

**F. Test tooling reads platform classes** (`Security.*`, `%SYS.*`, `$SYSTEM.*`) to verify effects.
This is outside the portal: Constitution I forbids those classes in place of an endpoint in the
running portal, not as an independent oracle in tests.

## Corrections to earlier records

None of the 28 routes changed. The spike's operation 5 ("a direct check of internal state was
attempted and did not work") is now verified independently with `%SYS.TaskSuper.SuspendGet()`,
which must run in `%SYS`.
