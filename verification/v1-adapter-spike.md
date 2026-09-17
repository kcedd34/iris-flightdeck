# SysAdmin API v1 adapter spike (IRIS 2026.1), 2026-09-17

Closed-scope spike to measure the real cost of translating v2 operations to v1 before deciding on an
adapter. Nothing in the spec, tasks, constitution or application code changed. Companion to
`v1-api-2026.1.md`.

**Target**: `intersystemsdc/iris-community:latest` (2026.1.0.234.1). A throwaway container was used,
with entrypoint override and default passwords unexpired, then removed.

**Fixtures** created for the spike:
- table `Spike.Orders` in `USER`;
- user `spike_grantee`;
- task class `Spike.Noop`;
- task id 1000 (created with `POST /v1/task` and the full v2 body, which v1 accepted unchanged:
  201).

**Timing method**: wall clock between the first and last tool call for each operation in this
session. It includes command latency and the reasoning between attempts. Effect verification
(checking that the change really happened, not just HTTP 200) is included, because an adapter is
not done until that is known. Total spike, fixtures to last restore: **241 s**.

## Operations

All five come from the 28 "different shape" operations in `v1-api-2026.1.md`: three from
permissions, two from tasks. Each was chosen for a request that is not a plain CRUD body.

| # | v2 operation | v1 route | Working v1 request | Attempts | Time | Effect verified by |
|---|---|---|---|---|---|---|
| 1 | `POST /v2/security/sql-privilege/grant` | `PUT /v1/security/sql-privilege` | Same query params as v2: `namespace, grantee, type, object, action` (no body) | **1** | 46 s | `$SYSTEM.SQL.Security.CheckPrivilege("spike_grantee",1,"Spike.Orders","s","USER")` = 1; the v1 list shows `SELECT` `Direct` |
| 2 | `POST /v2/security/sql-column-privilege/grant` | `PUT /v1/security/sql-privilege/column` | Same query params as v2 plus `column` | **1** | 13 s | `GET /v1/security/sql-privilege/column/` lists `Amount UPDATE Direct` |
| 3 | `POST /v2/security/sql-admin-privilege/revoke` | `DELETE /v1/security/sql-privilege/admin` | Same query params as v2: `namespace, grantee, privilege` | **1** | 14 s | Granted first with `PUT` (appeared in list), `DELETE` removed it (list empty) |
| 4 | `POST /v2/task/suspend` | `PATCH /v1/task?id=` | Body `{"Action":"Suspend"}` (`Resume` restores) | **5** | 66 s, plus about 70 s resolving a list/detail disagreement (below) | `%SYS.Task.Suspended` = 1; `GET /v1/task/info` → `Suspended: true` |
| 5 | `POST /v2/task/manager/suspend` | `PATCH /v1/task/manager` | Body `{"Action":"Suspend"}` (`Resume`, `Run` also accepted) | **3** | 18 s | `GET /v1/task/manager` → `Status: Suspended`, back to `Running` after `Resume`. A direct check of internal state was attempted and did not work, so this is the API's own report |

**Summary**
- 3 of 5 worked on the first attempt: every SQL privilege operation takes the same query parameters
  as v2; only method and path differ.
- 2 of 5 needed trial and error. Both were `PATCH` action routes with an undocumented `Action`
  body.
- 0 of 5 were left without a clear answer.

**How trial and error converged.** The v1 request validator is informative:
- sending the v2 body names the unexpected field (`#40307 Field 'RunNow' was not expected`);
- `{}` names the required field (`#40301 Field 'Action' is required`);
- an invalid value lists the allowed values (`#40303 … must equal 'Resume', 'Suspend', or
  'SuspendAndReschedule'`).

No operation needed more than one guess once these three messages were read. The two extra
attempts on #4 were: no body (415, JSON content type required) and case variants of `run`.

## What the spike found beyond the five calls

1. **One mapping assumption in `v1-api-2026.1.md` was wrong and only a live call exposed it.**
   - The different-shape table mapped `POST /v2/task/run` to `PATCH /v1/task`. That route has **no
     run action** (`Resume`, `Suspend`, `SuspendAndReschedule` only).
   - Running a task is `POST /v1/task/run`, which the coverage count had already classed as
     same shape. The totals (173 / 28 / 72) are unaffected, but the unused `PATCH` entries for
     `task/run` and `process/broadcast` in the JSON's `differentShapeRoutes` are wrong.
   - **Consequence for an adapter**: each of the 28 mappings needs a live call with effect
     verification, not a table built from route names.
2. **"Same shape" does not guarantee the same body.** `POST /v1/task` accepted the complete v2 body.
   `POST /v1/task/run` was not exercised, so whether it takes v2's `RunNow`/`Datetime` is unknown.
3. **Errors differ in status, not in content.** Invalid input on v1 SQL privilege routes returns
   **HTTP 500** with the SQL error text:
   - `SQLCODE -118 Unknown or non-unique user or role`;
   - `SQLCODE -60 An action … expected`;
   - `#514 Invalid privilege`.

   Revoking a privilege the grantee does not hold returns **200** silently. An adapter that
   branched on status codes would misclassify these. Passing the IRIS error text through, as
   FlightDeck already does, is unaffected.
4. **List vs detail disagreement exists on both versions.** After a successful suspend, `GET /task/`
   (v1) and `GET /v2/tasks` (2026.2) still report `Suspended: false`, while `task/info` reports
   `true`. This is a platform defect, not adapter cost. Screens must read suspension from
   `task/info`.
5. **Finding for the current v2 implementation, unrelated to v1.** On 2026.2,
   `POST /v2/task/suspend?id=` without a body returns **415**; it needs
   `Content-Type: application/json` with `{}`, although the v2 spec declares no request body.
   `FlightDeck.Admin.Client` sends a content type only when a body is passed. The Tasks domain
   feature must pass `{}` for these action operations. Not changed here (out of scope).

## Extrapolation to the remaining 23 operations

Measured on 5, not guaranteed for the rest:
- **Parameter-only operations**: about 13–46 s each. Likely the remaining SQL list operations
  (2) and the data-element keys list (1).
- **`PATCH` action operations** with an undocumented `Action` body: about 20–70 s each. Remaining:
  - `task` resume (1);
  - `task/manager` run and resume (2);
  - `async-result` cancel, pause and resume (3);
  - `els` start and stop (2);
  - `process` suspend and resume (2).
- **Operations whose effect is hard to set up safely**:
  - `DELETE /v1/process` (terminate) and `PATCH /v1/process` need a disposable process;
  - `async-result` actions need a running async task;
  - `els` start/stop needs a configured external language server.

  Fixtures, not request discovery, dominate these.
- **Wallet collection** get/put/delete/list at `/v1/wallet`, plus
  `POST /v1/security/oauth2/server/revoke`: path-only differences expected.

A defensible estimate for verifying all 28 live, with fixtures and effect checks, is **a working
half day**. The larger cost is not discovery; it is the items below, which the spike does not
remove.

## Adapter shape: where the conditional lives

One translation point on the backend, plus data-driven availability. **No screen branches on API
version.**

```text
Screens / palette ──> FlightDeck API (unchanged contracts)
                          │
            FlightDeck.Capability.Map ── availability per operationId (v1: 72 absent → disabled with
                          │                reason "Requires IRIS 2026.2"; privileges: see cost 1)
            FlightDeck.Admin.Client.Call("POST", "/v2/task/suspend", query, body)
                          │
            dialect = session-scoped, read once from /info.apiVersion
                          │
         ┌────────────────┴────────────────┐
     apiVersion 2                     apiVersion 1
   %Api.Admin, path as is        FlightDeck.Admin.V1Dialect.Translate(operationId, query, body)
                                   → method, path (/v1, singular list + "/", /els, /wallet),
                                     query (unchanged where measured), body ({"Action": …}),
                                     dispatcher Api.Admin (no %)
```

**Contained in the backend (no leak):**
- **Request translation.** One table keyed by v2 `operationId` in a `V1Dialect` class, called from
  `Admin.Client.Call`. Every caller already goes through that method, so handlers, the installer
  and the palette search are untouched.
- **Response shapes.** 31 of 33 probed lists are identical, so no response translation is needed
  for reads. `services.EnabledBoolean` is the only v1-only gap seen.
- **Dispatcher name.** `%Api.Admin` (2026.2) vs `Api.Admin` (2026.1), in the same class.

**Reaches the UI, through mechanisms that already exist (no version conditional in screens):**
- **Availability.** The 72 absent operations become capability entries marked unavailable with the
  version reason. Screens already render "disabled with reason" from the capability map
  (FR-014), and palette search already skips operations the map disallows. Whole sections with no
  available operation (namespaces, databases, ECP, locks, file system access, journal) need a
  section-level "not available on this version" empty state, derived from the same map.
- **Vitals.** Disk becomes `unavailable` with a reason in `Vitals.Service`, which already returns
  that state.
- **Session.** One visible indicator that the instance runs in limited API v1 mode, set in the
  glareshield from `Session.instance.apiVersion`.

**Costs the spike does not remove (the decision points):**
1. **Privilege source for v1** (Constitution III). v1 publishes none. The options are to reuse the
   v2 declarations for the 201 mapped operations (sampled values matched) or to read
   `ResourcesOR()` from internal classes. Either needs an explicit amendment.
2. **Source of truth for 28 translations** (Constitution I). The table encodes undocumented
   behavior discovered by calling the server. It would need its own regression check against a
   2026.1 container, as `verify_platform.py` does for v2.
3. **RN-FD-19.** The disk-per-database instrument cannot exist on v1. That is a requirement change,
   not a degradation.
4. **Test matrix.** Every domain feature would need its e2e run on 2026.1 as well as on the two
   2026.2 images.
