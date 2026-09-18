# Feature 003 probes (P1 to P5), IRIS Community 2026.2, 2026-09-17

Run against the fresh compose install on port 52780 as `_SYSTEM`, and as `fd_e2e_operator`
(`%Operator` only) where a reduced view was needed. All probe objects were created and deleted
inside the run; the install was left as it was (`FDP_*` users, roles, resource, credential and the
`FDProbe.T` table are gone, `/tmp/fdprobe` removed).

Two findings contradict what `specs/003-permissions-security/plan.md` assumed. They are stated first.

## Finding A (blocking) — `%All` is not enumerable, so the narrow predicate can accuse the wrong instance

```
GET /v2/security/role?name=%All   ->  { "GrantedRoles": [], "Resources": [] }
```

The official API reports **no resources and no granted roles** for `%All`: its power is implicit in
the platform, not data. On the default Community install the real administrators hold only `%All`:

```
_SYSTEM     Roles ['%All']       SuperUser Roles ['%All']       irisowner Roles ['%All']
Admin       Roles ['%EnsRole_Administrator', '%EnsRole_Developer', '%Manager']   Enabled true
```

Computing the roles that grant `%Admin_Secure:U`, transitively through `GrantedRoles`, gives
`%Admin_Secure`, `%Manager` and `%SecurityAdministrator`; their direct owners are only `Admin`
(through `%Manager`). So the spec's predicate — "after the change, at least one enabled, unexpired
user still holds `%Admin_Secure:USE`" — counts exactly **one** user on a default install, and counts
zero of the three accounts an administrator would actually use.

Consequences, both reachable by an evaluator:

1. Removing `%Manager` from `Admin` (a normal hardening step) is refused as "the last administrative
   access", while three `%All` accounts remain.
2. On an install where no account holds `%Admin_Secure` outside `%All`, the counted set is empty
   **before** any change, so every protected change is refused, with a reason that is false.

The spec anticipated a false positive here (FR-010b-1) but assumed it would be rare. It is the
default case on IRIS Community. This needs a decision before tasks are generated.

## Finding B (design correction) — `role/owners` reports direct owners only, and they may be roles

Three-level chain `FDP_L1 -> FDP_L2 -> FDP_L3`, resource `FDP_Res:U` on `FDP_L3`, user `FDP_User`
holding `FDP_L1`:

```
FDP_L1: GrantedRoles ['FDP_L2']  Resources []      owners: [('FDP_User','User')]
FDP_L2: GrantedRoles ['FDP_L3']  Resources []      owners: [('FDP_L1','Role')]
FDP_L3: GrantedRoles []          Resources [FDP_Res:U]  owners: [('FDP_L2','Role')]
```

`GrantedRoles` is one level, as the plan assumed (R1 traversal is required). But `role/owners`
answers with the **direct** owners of that role, and an owner may itself be a role
(`Type: 'Role'`). Research R2 and R7 said it reports the users holding the role "including
escalation holders"; that is wrong for indirect holders. Finding the users behind a role needs the
inverse traversal: owners of the role, then owners of any role among them, with the same cycle guard
and cap as R1. Roles are few (40 on this install), so the cost is acceptable, but the tasks must
build the inverse walk rather than one call.

## P1 — Expiry semantics (confirms R2)

```
FDP_Expired  created with ExpirationDate 2020-01-01 -> read back '2020-01-01', Enabled true
FDP_NoLimit  created with ExpirationDate 1840-12-31 -> read back ''          , Enabled true
```

The API normalises the documented sentinel to an empty string, so "no limit" is `''` and nothing
else. An expired account stays `Enabled: true`, so the predicate must compare the date itself; the
`Enabled` flag alone would count an unusable account as an administrator.

## P4 — SQL privileges round trip (improves R4)

Granting `SELECT` on `FDProbe.T` in `USER` to the role `FDP_L3`, then reading the listing for the
**user** three levels below it:

```
grantee=FDP_L3    -> Object FDProbe.T, Action SELECT, GrantedVia 'Direct'
grantee=FDP_User  -> Object FDProbe.T, Action SELECT, GrantedVia 'Role:FDP_L3'
revoke            -> the row disappears for both
```

The official listing already resolves provenance through the role chain and reports it in
`GrantedVia`. FlightDeck does **not** need its own traversal for SQL privileges: it renders what the
API says. `GrantedVia` also carries `Owner Privilege` for privileges that come from object
ownership. Grant and revoke return 200 and are visible immediately; a non-existent table returns 500
with `SQLCODE -30`, the platform's message, which the portal shows verbatim.

## P3 — X.509 validity (refines R10)

A self-signed certificate valid for 10 days, imported as `FDP_Cert`:

```
POST /v2/security/x509-credential  { Alias, CertificateFile, PrivateKeyFile, OwnerList: [] } -> 201
GET  /v2/security/x509-credential/certificate?alias=FDP_Cert ->
     { HasPrivateKey: true, SerialNumber: ..., IssuerDN: 'CN=fd-probe', SubjectDN: 'CN=fd-probe',
       ValidityNotBefore: '2026-09-17 19:15:37', ValidityNotAfter: '2026-09-27 19:15:37' }
GET  /v2/security/x509-credentials -> [{ Alias, OwnerList, PeerNames, HasPrivateKey, CAFile }]
```

Validity is available **per alias only**: the list operation does not carry it. A list of N
credentials therefore needs N certificate reads to show bands, and the same for the home panel's
attention items. The tasks must cache those reads with a stated cap and degrade to "validity not
read" rather than fanning out without bound.

Two more official behaviours worth recording: `OwnerList` must be an array (a string gives
`ERROR #40308`, a clear message), and a missing certificate file gives `ERROR #5005: Cannot open
file`, which the create form shows verbatim.

## P5 — Partial mode (refines R2 and the spec's two modes)

As `fd_e2e_operator` (`%Operator` only), every permissions read is refused:

```
GET /v2/security/roles          -> 403
GET /v2/security/role           -> 403
GET /v2/security/role/owners    -> 403
GET /v2/security/users          -> 403
GET /v2/security/user           -> 403
```

But all 31 permission operations declare the same privilege, `%Admin_Secure:U`, for reads **and**
writes. So inside the permissions domain a session that may change a role may always read roles and
users: partial mode is unreachable by privilege there, and can only come from a cap or a timeout.

Partial mode is reachable, and necessary, in the security domain, where mutations declare different
privileges: `%Admin_Wallet:U` for the wallet collections and secrets, `%Admin_OAuth2_Client:U`,
`%Admin_OAuth2_Server:U` and `%Admin_OAuth2_Registration:U` for the OAuth families. A wallet-only
administrator can delete a collection while being unable to read the users behind its resource: that
is where "incomplete check" and "impact not determined" earn their place, and where the end-to-end
test for partial mode must be written.

## Known defects re-confirmed

- `PUT /v2/security/resource` with `PublicPermission: ""` returns 400; with a value it returns 201.
  The form must state the constraint instead of sending an empty value.
