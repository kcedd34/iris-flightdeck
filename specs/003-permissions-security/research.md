# Phase 0 Research: Permissions, Security and Secrets

All findings below come from the official specification shipped in `docs/sysadmin-api-v2.json`
(read offline on 2026-09-17) and from what features 001 and 002 already built. Anything that must be
confirmed against a running instance is marked **to verify**, with the probe that will confirm it;
those probes run as tasks before the code that depends on them, in the manner of feature 002's
spikes.

## R1 — Effective privileges with provenance

**Decision**: compose official reads. `GET /v2/security/user` returns `Roles` and `EscalationRoles`
(arrays of role names). `GET /v2/security/role` returns `GrantedRoles` (inherited roles) and
`Resources` (array of `{Name, Permissions}`, for example `{"Name":"%DB_IRISSYS","Permissions":"RW"}`).
Expand the role graph breadth-first from the user's direct and escalation roles, keeping the path
that reached each role, and emit one row per `resource + permission` with every path that grants it.

**Rationale** (for roles and resources; SQL privileges are different, see R4): the provenance chain
is exactly the traversal path, so provenance is free when the
traversal is done deliberately; computing the union first and explaining it later would be the one
thing RN-FD-10 forbids.

**Bounds**: a cycle guard on visited roles, a depth cap and a role-count cap, both stated in the
response. **Confirmed by probe P2**: `GrantedRoles` is one level deep, so the traversal is required. When a role detail read is refused, the chain says which role it could not expand rather
than dropping it silently.

**Alternatives considered**: reimplementing over `Security.Users` / `%SYS.Security` classes
(rejected: Principle I); asking IRIS for an effective-privilege list (no official operation exists).

## R2 — The last-administrator predicate

**Revised after probes A, B and P1** (`verification/permissions-security-probes-2026.2.md`).

**Decision**: the counted set is the enabled, unexpired users who hold `%Admin_Secure:USE` **or have
`%All` among their roles** (read as a literal name from `User.Roles`; the official API reports no
resources for `%All`, so nothing about it is inferred). The block is affirmative only when that set
was non-empty before the change and is empty after it. Compute it as
`GET /v2/security/roles` → for each role `GET /v2/security/role` → keep the roles whose `Resources`
contain `%Admin_Secure` with `U` (directly or through `GrantedRoles`) → for each kept role
`GET /v2/security/role/owners?name=` → **and, because that operation answers with direct owners that
may themselves be roles (probe finding B), walk those role owners inversely with the same cycle
guard and cap** → for each candidate user `GET /v2/security/user` to read `Enabled` and
`ExpirationDate`. Apply the
proposed change to that set in memory before testing it.

**Modes**: the evaluation records `complete` when every read it needed succeeded, and `partial` when
any read was refused (403) or capped. `partial` never blocks: it produces the reinforced
confirmation with the list of what could not be read (spec FR-010a).

**Expiry** (probe P1, verified): the API normalises `1840-12-31` to an empty string, so "no limit" is
`''`. An expired account is still returned with `Enabled: true`, so the predicate compares the date
and never trusts the flag alone.

**Cost**: roles are few compared with users, so the traversal starts from roles, not from users. The
candidate user reads are capped and the cap turns the mode into `partial`.

**Alternatives considered**: starting from `GET /v2/security/users` and reading every user (rejected:
unbounded on real instances); counting `%All` holders (rejected by the spec's narrow definition).

## R3 — Role origin: delegated, LDAP and external mechanisms

**Decision**: the official user object reports `AutheEnabled` (the authentication methods enabled for
that account) and the instance reports LDAP configurations. The portal marks a user whose enabled
methods include delegated or LDAP authentication, and states beside the roles list that roles may be
assigned by that mechanism at login and are not managed here. It does **not** claim which specific
role came from outside, because no official operation reports that.

**Rationale**: spec scenario US1-3 asks for the origin to be signalled and for the portal to say it
does not manage it there. Marking the account's mechanism is verifiable; attributing individual
roles to LDAP would be invention.

**To verify during implementation**: the bit values of `AutheEnabled` that correspond to delegated
and LDAP, read from the official schema's own documentation rather than assumed.

## R4 — SQL privileges

**Decision**: the three listings require parameters — `sql-privileges` and `sql-admin-privileges`
need `grantee` and `namespace`, `sql-column-privileges` also needs `object` — so they cannot be a
top-level list. They become a parameterised panel inside the user and role inspectors, with a
namespace selector fed by the namespaces the session may read, exactly as spec FR-006 requires. The
returned rows already carry provenance: `GrantedVia` and `GrantedBy`.

Grant and revoke are POSTs whose identifying values are path parameters
(`namespace`, `grantee`, `type`, `object`, `action`, plus `privilege` or `column`), with modifiers as
query parameters (`withGrant`, `cascade`, `asGrantor`).

**Palette**: the action named "SQL privileges" resolves to a user or role and opens its inspector
with the panel open (spec FR-006a), reusing the palette's existing entity targets.

## R5 — Namespaces for the SQL panel

**Decision**: the namespace list comes from the official `GET /v2/namespaces` operation, which the
capability map already carries, and which feature 001 verified as available on both dialects. When
the session may not list namespaces, the panel asks the user to type the namespace instead of
failing, and says why the list is unavailable.

## R6 — Action-kind mutations (pattern change 1)

**Decision**: add a mutation `kind: "action"` to the descriptor mechanism, for official operations
that change state through a verb with path parameters and no editable object: SQL grant and revoke,
audit purge and copy, audit event count clearing, OAuth secret and token operations, MFT token
deletion, OAuth revoke.

An action descriptor declares: the operation, the parameters it takes, an optional `readOperation`
that lists the affected set, the target template, the grade rules and the secret fields. The preview
renders the before state and the commanded state of that set in the existing diff component (for a
grant: the privilege absent → present), or, when no listing exists (audit purge), the request block
already used by the REST explorer's request mode, with the parameters that will be sent.

**Why in the pattern**: every later domain (tasks: run, suspend, resume; system: compact, defragment)
needs the same thing. Building it as a local component here would be the first crack in the rule
feature 002 established.

## R7 — Impact analysis providers

**Decision**: three providers, each composing official reads and reporting a state of
`ok` / `none` / `undetermined` with a reason, as the dry-run's impact block already expects:

- **role change or deletion**: users who lose the role (`role/owners` plus the inverse traversal of
  probe finding B, since an owner may be a role), and the resources the role
  granted (`Role.Resources`), plus the objects those resources protect (R8).
- **resource change or deletion**: roles that grant it (the provider feature 002 already ships) and
  the users behind them, plus the objects it protects.
- **SQL privilege revocation**: the grantee, and when the grantee is a role, the users that hold it.

**Undetermined** is produced whenever a needed read is refused, capped or the platform returns one of
its known defects — never an empty list (spec FR-009).

## R8 — Which objects a resource protects

**Decision**: compose the official lists that reference a resource: web applications
(`Resource` field, already read by feature 002), wallet collections (`EditResource`, `UseResource`),
privileged routine applications (`Resource`), databases (the resource that protects a database, read
through the database list) and services. Each source is capability-gated on its own operation, so a
refusal narrows the answer and is stated, rather than failing the whole panel.

## R9 — Which fields are secret

**Decision**: three sources, merged, with a build check:

1. the official specification's own `writeOnly` markers (`WalletSecret`, the private key password on
   the TLS configuration write, and the encryption admin name and password);
2. request-body fields that exist only on a write and are documented as a password, secret, token or
   credential (`Password` and `NewPassword` for users, `PrivateKeyPassword` on the X.509 create,
   `ClientSecret` and `ClientPassword` for OAuth clients and resource servers, `ServerPassword`,
   `InitialAccessToken`, `LDAPSearchPassword`, `SMPTPPassword` on the web authentication settings);
3. descriptor declarations for anything the first two miss.

`scripts/build/check-secrets.py` scans the official specification for field names matching
password/secret/token/credential and fails the build when one is neither declared secret in a
descriptor nor listed, with a reason, in an explicit exemption file. This keeps Constitution VI
enforceable as the specification changes.

**Platform note**: the web authentication write field is spelled `SMPTPPassword` in the official
specification (a transposition of SMTP). FlightDeck sends what the API declares and records the
defect in `verification/README.md`; it does not silently "fix" the name.

## R10 — Expiry, bands and the attention list

**Decision**: X.509 credentials carry their certificate's validity through
`GET /v2/security/x509-credential/certificate?alias=`, which returns `ValidityNotBefore`,
`ValidityNotAfter`, `SerialNumber`, `IssuerDN`, `SubjectDN` and `HasPrivateKey`. Days remaining and
the band are computed as server-side **facts**, so lists, inspectors and the attention list agree.

TLS configurations name a certificate **file** (`CertificateFile`); the official API reports no
validity for it. They therefore show "validity not reported by the platform" and are not counted as
valid (spec FR-024), with the defect noted in the coverage document.

The home panel's attention section (already present and empty since feature 001) is fed by a new
read-only endpoint on FlightDeck's own API that aggregates expiring and expired items the session
may read; it degrades to a stated reason when the underlying operation is refused.

**Probe P3 confirmed** the fields and one cost: validity comes from the per-alias certificate read,
and the credentials listing does not carry it. A list of N credentials therefore needs N reads, which
are cached with a stated cap; beyond the cap, or on a refusal, the item shows "validity not read".
A missing certificate file gives `ERROR #5005: Cannot open file` on create, shown verbatim, and
`OwnerList` must be sent as an array (`ERROR #40308` otherwise).

## R11 — Singleton and parameterised sections (pattern changes 2 and 3)

**Decision**: several security families are single objects, not lists: encryption settings, web
authentication, the OAuth 2.0 authorization server, auditing enabled, and the LDAP configuration for
a chosen name. The entity-type descriptor already allows a type with only a `detailOperation`
(feature 002 uses it for read-only roles); this feature adds the section form that renders a
singleton without a list, and the parameterised panel used by R4, both in `src/pattern/`.

## R12 — Policy-declared unavailability (pattern change 4)

**Decision**: add `FlightDeck.Capability.Policy`, an XData table of operation ids that FlightDeck
declines to offer, each with a reason and the native path that performs it. The capability map
merges it into its entries as `available: false` with that reason, so every consumer — the action
bar, the palette, the mutation service, the router — refuses them through the mechanism that already
exists, with no new client rule and no version check.

The encryption writes of spec FR-020 are its first entries: create key file, add and remove key file
administrator, add key, activate and deactivate a key, and change encryption settings. The recorded
reason states the danger and names "System Administration > Encryption" in the platform's own
management portal.

**Rationale**: policy and version are different reasons for the same observable state. Keeping both
in the map means screens keep asking one question — is this available, and why not — which is the
invariant the project already enforces.

## R13 — Audit split and its grades

**Decision**: this feature carries `GET`/`PUT /v2/security/audit/enabled`, `POST
/v2/security/audit/event/clear-count`, `POST /v2/security/audit/record/copy` (body:
`AuditCopyNamespace`, `DeleteAfterCopy`, `BeginDateTime`, `EndDateTime`) and `POST
/v2/security/audit/record/purge` (body: `BeginDateTime`, `EndDateTime`). Purge is graded **maximum**
with the consequence stated; copy is **reinforced** and its target names the destination namespace;
`DeleteAfterCopy` set to true grades the copy as maximum too, because it is a purge by another name.
`POST /v2/security/audit/records` (the record listing) belongs to the logs feature.

## R14 — Known platform defects to work around visibly

- `GET /v2/security/ldap/configurations` returns 500 `<INVALID OREF>` for a user holding only
  `%Admin_Operate` (recorded in feature 001). The section shows the official message and stays
  usable; the defect is repeated in this feature's verification notes.
- `PUT /v2/security/resource` rejects an empty `PublicPermission`. The form states the constraint
  from the official schema rather than sending an empty value and reporting the platform's error as
  if it were the user's mistake.
- `GET /v2/database-dirs` returning 403 for `%Admin_Operate` affects the resource-to-database link
  (R8): that source degrades to "could not be determined" with the official message.

## R15 — Verification probes (executed 2026-09-17, before tasks)

All five ran against the fresh IRIS Community 2026.2 install and are recorded in
`verification/permissions-security-probes-2026.2.md`. Findings A and B changed the design and are
folded into R2 and R7 above; P1, P3 and P4 refined R2, R10 and R4. One result decides where a test
lives: every permission operation declares `%Admin_Secure:U` for reads and writes, so partial mode is
unreachable by privilege inside permissions; the end-to-end test for it uses a wallet-only
administrator in the security domain.

### Original probe list

1. **P1 — expiry semantics**: create a user with a past `ExpirationDate` and one with `1840-12-31`;
   confirm how the official read reports them (R2).
2. **P2 — role graph**: build a three-level role chain on the demo instance and confirm the
   traversal and provenance (R1).
3. **P3 — X.509 certificate read**: install a credential whose certificate expires soon and confirm
   the validity fields, and the behaviour when the file is missing (R10).
4. **P4 — SQL grant round trip**: grant and revoke one table privilege through the official
   operations and confirm the listing reflects it, including `GrantedVia` (R4).
5. **P5 — last-administrator**: on a scratch instance, confirm the predicate blocks in complete mode
   and degrades to partial for a session that cannot read users (R2).

Each probe is recorded in `verification/` like the spikes of feature 002, and the code that depends
on it is written after it, not before.
