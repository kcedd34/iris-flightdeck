# Native gaps on the v1 dialect (IRIS 2026.1), 2026-09-17

Item 5 of the v1 adapter decision:
- RN-FD-19 does not become an exception;
- disk usage per database becomes a native provider;
- namespaces and journal are evaluated the same way.

Scope confirmed by the user: native providers for these gaps apply to the **v1 dialect only**. On
2026.2 the official endpoints stay in use (Constitution 2.1.0, Principle I).

Companion to `v1-api-2026.1.md` and `v1-translations-2026.1.md`.

## 1. Disk usage per database: implemented

**Why a gap on v1**:
- v1 has none of the 15 `database-dir` operations, nor the 4 `database` operations;
- the Disk vital (RN-FD-19) on v2 uses `GET /v2/database-dirs` and `POST /v2/database-dir/info`.

**Provider**: `FlightDeck.Native.Databases`.
- Reads `Config.Databases:List` (local, deduplicated directories), `SYS.Database` (`Mounted`,
  `Size`, `MaxSize`), `SYS.Database.GetFreeSpace` and `%File.GetDirectorySpace` (MB).
- These are the figures `database-dir/info` reports as `Size`, `MaxSize`, `AvailableSpace` and
  `DiskFree`, and the percent rule is the same one the API vital uses.

**Selection**:
- `FlightDeck.Vitals.Service.Disk` asks `FlightDeck.Admin.Client.Has(...)` for both official
  operations and uses the native provider only when the instance lacks them.
- There is no version check outside the Admin layer.
- The vital reports `source: "native"`.

**Privilege**: the provider requires what `POST /v2/database-dir/info` declares in the v2
specification: `%Admin_Manage:U` or `%Admin_Operate:U`. It reads that declaration through
`FlightDeck.Capability.Map.Requires`, never from a hand-written table.

**Evidence** (`FlightDeck.Test.NativeDatabases`):
- IRIS 2026.2, native vs official, for all 10 mounted databases:
  - `Size` and `MaxSize` equal;
  - `AvailableSpace` equal (tolerance 1 MB; observed differences 0);
  - `DiskFree` 816798.18 MB vs `797.65GB` (0.0 % apart after unit conversion).
- IRIS 2026.1: Disk vital `source: native`, state `ok`, value present; 10 databases read.
- 5/5 on both versions.

**Installer bootstrap**: `Installer.EnsureRuntimeRole` needs the resource of FlightDeck's code
database.
- On v2 it still uses `GET /v2/namespace`, `/v2/database` and `/v2/database-dir`.
- On v1, where none exist, `Native.Databases.CodeDatabaseResource` reads `Config.Namespaces`,
  `Config.Databases` and `SYS.Database`.
- Verified equal to the API route on 2026.2 (`TestCodeDatabaseResourceMatchesApi`).
- It is bootstrap scope, like `DeployCapture`, and needs a Complexity Tracking entry.

## 2. Namespaces: native reads only (decided and implemented)

**On v1**: all 18 `/v2/namespace` operations are absent (8 reads, 10 writes).

**Who depends on it**:
- UC08 (System), namespaces section;
- the namespace context used across domains:
  - web application dispatch namespace (UC03);
  - SQL privileges, which take `namespace` (UC04);
  - task `NameSpace` (UC06);
  - log correlation to entity (RN-FD-26).

On v1 those screens would otherwise have no namespace list to offer.

**Native source, probed on 2026.1**:
- `Config.Namespaces:List` (3 namespaces);
- `Config.MapGlobals:List`, `Config.MapPackages:List` and `Config.MapRoutines:List` for `USER`
  (77, 4 and 1 rows).

All read configuration directly and have no side effects.

**Recommendation**:
- **Reads** (`GET /v2/namespaces`, `/namespace`, `/global-mappings`, `/global-mapping`,
  `/package-mappings`, `/package-mapping`, `/routine-mappings`, `/routine-mapping`): native
  provider, v1 only, gated by `%Admin_Manage:U` from the spec. The response is shaped like the v2
  schema, so screens do not branch.
- **Writes** (namespace create/edit/delete, mapping create/edit/delete, `copy-mappings`,
  `enable-interop`): **stay unavailable** on v1, with the version reason.
  - Doing them natively would reimplement the API's validation and side effects. For example,
    deleting a namespace also deletes its web apps, and enabling interoperability creates
    mappings and databases.
  - That is exactly what Principle I forbids in spirit, and the RN-FD-04 diff would describe an
    operation FlightDeck invented.

**Implementation** (after the decision below):
- `FlightDeck.Native.Namespaces` answers the 8 reads. The v1 dialect table
  (`scripts/build/v1-translations.json`, section `native`) names it, so the Admin client dispatches
  to it and no caller sees a dialect.
- Each read mirrors the IRIS 2026.2 handler (`%Api.Admin.Endpoints.Namespace.*`, source read on
  2026.2): same `Config` query or `Exists` call, column renames and exclusions, `filter`, `names`,
  `maxRows` (default 1000), 400 `#40300` for a missing parameter, 404 with IRIS's own status, and
  the official envelope.
- Privilege: what the v2 operation declares (`%Admin_Manage:U`), refused like the API with 403 and
  no errors.
- The 10 writes are **withheld**: unavailable on v1, with the version message followed by
  "FlightDeck reads namespaces on this version but does not change them: a native write would copy
  platform side effects FlightDeck does not control."

**Evidence** (`FlightDeck.Test.NativeNamespaces`, 4/4 on 2026.2 and on 2026.1):
- On 2026.2, 21 requests compared with the official API: status, result, and each error's text,
  code and params are identical. The requests cover list, filter, `maxRows`, items, not found,
  missing parameters, and all three mapping kinds (list, `names`, item, unknown namespace). The
  error `id` field is not produced natively and is not compared.
- On both versions, a user with `%Operator` (no `%Admin_Manage`) gets `403 0 {}` from the provider
  itself.
- On 2026.1, reached through the Admin client: the list contains `USER` and `%SYS`, and a namespace
  write returns 501 with the recorded reason.
- e2e on 2026.1: the palette finds namespace `USER` under System; for `fd_e2e_operator` the group
  shows "Requires Use on %Admin_Manage".

## 3. Journal: no native provider (decided)

**On v1**: all 9 `/v2/journal` operations are absent.

**Who depends on it**: UC09. The journal is one of the five log sources (RF09), and the only
journal screens are the log stream and its settings.

**Native source, probed on 2026.1**:
- `%SYS.Journal.System.GetCurrentFileName()` and `GetPrimaryDirectory()`;
- `%SYS.Journal.File:ByTimeReverseOrder` (1 file);
- `%SYS.Journal.File.FirstRecord`.

All work.

**Why not**:
- `POST /v2/journal/file/records` and `GET /v2/journal/file/record` are declared to **exclude
  records of databases the user cannot read** (docs/api-coverage.md).
- A native provider would have to reimplement that per-record authorization filter in FlightDeck.
- That moves an authorization decision out of IRIS, against Principle II (identity and
  authorization are delegated to IRIS), and a mistake leaks data.
- File list and settings could be read safely, but without records the journal log source carries
  almost no value.
- The writes (`switch-file`, `switch-dir`, `PUT settings`, `integrity-check`) are operational
  actions with the same objection as namespace writes.

**Outcome**:
- On v1 the journal source of the log stream shows **unavailable** with the recorded reason
  (Decision, below); the 9 journal operations are withheld in the v1 dialect table.
- The other four sources (audit via the API; `messages.log`, alerts and interoperability via native
  providers) are unaffected.
- Nothing is added to the native gap list.

## Decision (author, 2026-09-17, task T101)

Both recommendations approved.

- **Namespaces: native provider for reads only, v1 dialect only.** Writes stay unavailable, with
  their reason in the capability map. Recorded justification: reimplementing a write would copy
  platform side effects FlightDeck does not control.
- **Journal: not implemented natively.** Filtering records by the databases the user can read is
  authorization, and deciding it outside IRIS violates Principle II. On v1 the journal source shows
  unavailable with that reason: the version message followed by "FlightDeck does not read the
  journal natively: filtering records by the databases you can read is an authorization decision
  that belongs to IRIS."

  **This is a decision of rigor, not a gap.** FlightDeck could read the journal files (section 3
  shows the native sources work) and deliberately does not, because the only safe owner of that
  filter is the platform.

Constitution 2.1.0 records both decisions in Principle I: namespace and mapping reads as a named
v1-only gap with writes never native, and the journal as a deliberate non-gap.
