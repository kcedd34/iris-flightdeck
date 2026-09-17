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

## 2. Namespaces: recommend native reads only

**On v1**: all 18 `/v2/namespace` operations are absent (7 reads, 11 writes).

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

## 3. Journal: recommend no native provider

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

**Recommendation**:
- On v1 the journal source of the log stream shows **unavailable** with the version reason.
- The other four sources (audit via the API; `messages.log`, alerts and interoperability via native
  providers) are unaffected.
- Nothing is added to the native gap list.

## Decision needed

Constitution 2.1.0 lists only "Disk usage per database, v1 dialect only". Namespace reads (section
2) would add a second v1-only native gap, as a PATCH or MINOR amendment of the gap list. Journal
(section 3) needs no amendment.
