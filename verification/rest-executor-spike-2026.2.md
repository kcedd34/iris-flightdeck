# Spike T-EXEC-1: role reduction and in-process dispatch for the REST test executor (IRIS 2026.2), 2026-09-17

Closed-scope spike required by feature 002 research R8 before the REST test executor is designed
into tasks. Nothing was committed. Companion to `specs/002-webapps-explorer-mutations/research.md`.

**Question**: can the executor run a test request as the signed-in user, with privileges never
above those of the FlightDeck request itself, by reducing `$ROLES` inside the real
`/api/flightdeck` web application, and does in-process dispatch return what an HTTP call returns?

## Setup

- **Target**: install `iris-flightdeck-iris-1`, IRIS for UNIX 2026.2 (Build 221U), fresh install
  with demo data.
- **Temporary route**: a copy of `FlightDeck.API.Router` with one extra route,
  `GET /v1/spike/exec-roles`, calling `FlightDeck.Spike.ExecRoles:Run`. It was loaded into the
  container only.
- **Environment**: the request ran through the real web application, so its `MatchRoles` added
  `FlightDeck_Runtime` exactly as in production.
- **Experiment isolation**: every experiment ran in its own method, so `NEW $ROLES` was undone on
  return.
- **Recording**: results were written to `^IRIS.Temp.FDSpike` (IRISTEMP).
- **Users**:

  | User | Login roles | Notes |
  |---|---|---|
  | `_SYSTEM` | `%All` | reference |
  | `fd_e2e_operator` | `%Operator` | holds `%DB_IRISSYS:RW`, no `%DB_USER` |
  | `fdt_spike_dev` | `%Developer` | holds `%DB_USER:RW`, no IRISSYS access; created for the spike |

- **Cleanup, verified**:
  - `FlightDeck.API.Router` was reloaded from the repository, and the spike route now answers 404;
  - the spike classes, the global, the spike user and role, and `/tmp/spike` were removed;
  - `FlightDeck.Test.RouterGuards` passed 5/5 afterwards.
  - A second spike user with a custom minimal role could not be created (the official API answered
    500) and was not needed.

## First attempt, discarded

The first version placed `NEW $ROLES` inside `try` blocks of one method. In ObjectScript, `NEW`
lasts until the method frame exits, not the block. An escalation test therefore leaked into the
later dispatch tests of the same run, and those results were discarded. The run above uses one
method per experiment. The first attempt still showed the escalation reported below, which the
clean run reproduced.

## Results

| # | Experiment | `_SYSTEM` | `fd_e2e_operator` | `fdt_spike_dev` |
|---|---|---|---|---|
| 0 | `$ROLES` at entry | `%All,FlightDeck_Runtime` | `%Operator,FlightDeck_Runtime` | `%Developer,FlightDeck_Runtime` |
| 1 | `NEW $ROLES`, `SET $ROLES=""` | `%All` | `%Operator` | `%Developer` |
| 1b | then call FlightDeck code in `USER` | ok | **`<PROTECT>`** (no `%DB_USER` without the added role) | ok (`%Developer` holds `%DB_USER`) |
| 2 | `SET $ROLES="FlightDeck_Runtime"` (a subset of held roles) | allowed | allowed | **`<PROTECT> 32`** |
| 3 | `SET $ROLES=$ROLES_",%Manager"` (never held) | allowed | **allowed**: `%Manager,%Operator,FlightDeck_Runtime`, `%Admin_Secure` check 1 | `<PROTECT> 32` |
| 4 | `SET $ROLES=$ROLES_",%All"` (never held) | n/a | **allowed**: `%All,%Operator,FlightDeck_Runtime` | `<PROTECT> 32` |
| 1–4 | `$ROLES` after the method returns | restored | restored | restored |
| 5 | in-process `%Api.Monitor` `/metrics` in `%SYS`, login roles | 200, text/plain, ~41 KB | 200, text/plain, ~41 KB | **`<PROTECT> 206` at the namespace switch** |
| 6 | in-process `FlightDeck.API.Router` `/v1/openapi.json` in `USER`, current roles kept (no `SET`) | 200, 11186 B | 200, 11186 B | (not reachable: step 2 `<PROTECT>`) |
| 7 | in-process `%Api.Admin` `/v2/security/roles` in `%SYS`, login roles | 200 | 403, empty errors | `<PROTECT> 206` at the namespace switch |
| 8 | in-process `FlightDeck.API.Router` `/v1/openapi.json`, login roles only | 200 | **`%Status` ERROR #5002 `<PROTECT>` returned by `%CSP.REST`, `%response.Status` still 200** | 200, 11186 B |

HTTP baselines, same users, same instance:

| Request | `fd_e2e_operator` | `fdt_spike_dev` |
|---|---|---|
| `GET /api/monitor/metrics` | 200 | **200** |
| `GET /api/flightdeck/v1/openapi.json` | 200 (11186 B) | 200 |
| `GET /api/admin/v2/security/roles` | 403 | 403 |

`/api/monitor` is `AutheEnabled` 64 (unauthenticated) with `MatchRoles` `[{"MatchRole":"",
"TargetRoles":["%DB_IRISSYS"]}]`: over HTTP the application itself adds `%DB_IRISSYS`, which the
in-process dispatch with login roles does not have.

## Findings

1. **Only a full reduction is available to ordinary users.** `SET $ROLES=""` (back to login roles)
   works for every user. Setting `$ROLES` to any non-empty value, even a subset of the roles
   already held, raises `<PROTECT>` for a user without IRISSYS write access. The "keep only the
   target application's roles" design in R8 step 4 is **not implementable** for ordinary users.
2. **Users with `%DB_IRISSYS` write can set `$ROLES` to anything, including `%All`**, from code in
   a user database, inside a web application. This is platform semantics (IRISSYS write is
   effectively full control), not a FlightDeck defect. FlightDeck code must therefore **never** set
   `$ROLES` to a non-empty value: for such users it would escalate, and for others it fails.
3. **In-process dispatch matches HTTP when roles match** (rows 5–7 for `fd_e2e_operator` and row
   6): same status, content type and body, where live metrics make exact sizes differ.
4. **In-process dispatch diverges from HTTP when the target application adds roles** (`MatchRoles`
   or application escalation). `/api/monitor` answers 200 over HTTP but `<PROTECT>` in-process for
   `%Developer`. The divergence is always toward **less** privilege.
5. **`<PROTECT>` arrives in two forms**:
   - as a thrown exception, for example at the namespace switch;
   - as an error `%Status` returned by `%CSP.REST.DispatchRequest`, with `%response.Status` left at
     200.

   The existing `Admin.Client` mapping only handles the first; the executor must handle both.

## Consequence for feature 002 (research R8 revised)

- **Roles.** The executor never sets `$ROLES` to a non-empty value. For each test request it
  chooses one of two modes, and both only ever keep or remove privilege:
  - **Current roles kept**: when every role added to the current FlightDeck request is among the
    roles the target application's `MatchRoles` would grant this user. The request then already has
    exactly what an HTTP call would add, or less. FlightDeck's own API is always in this mode.
  - **Login roles only** (`NEW $ROLES`, `SET $ROLES=""`): in every other case.
- **Stated divergence.** When the target application grants roles beyond the user's login roles
  (`MatchRoles` targets not held, or escalation roles), the response panel states before and after
  the request that application role grants are not applied to test requests, and that a real call
  may succeed where the test is refused. A refusal is never reported as the application's own
  answer without that note.
- **`<PROTECT>` mapping.** Both forms (finding 5) map to 403 with the platform text, plus the reason
  "your login roles cannot read <database or namespace>".
- **Gate.** A backend test fails if any FlightDeck class sets `$ROLES` to a non-empty value.

This keeps Constitution II (no credential) and never widens privilege. The cost is honest
divergence for applications that grant roles, which the UI states.
