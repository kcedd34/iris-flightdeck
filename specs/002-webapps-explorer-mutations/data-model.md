# Data Model: Web Applications, REST API Explorer and the Shared Mutation Layer

**Feature**: `002-webapps-explorer-mutations` | **Date**: 2026-09-17

FlightDeck persists no domain data. IRIS owns every administered object; FlightDeck holds the
following in the IRIS session (server) or in one browser tab (client). Official objects keep
their official field names and are never reshaped. FlightDeck metadata sits beside them.

## 1. Descriptors (backend, declared once, versioned with the code)

### 1.1 Entity-type descriptor

| Field | Type | Rule |
|---|---|---|
| `domain` | `DomainId` | One of the six rail domains |
| `entityType` | string | Stable id, e.g. `web-application`, `pct-access` |
| `section` | string | Section tab id from feature 001 `domains.ts` |
| `listOperation` | operationId | MUST exist in the generated capability data (build check) |
| `detailOperation` | operationId | Same |
| `keys` | string[] | Official query parameters identifying one object, e.g. `["name"]`, `["name","allowType","class"]` |
| `displayName` | template | Built from keys, e.g. `{name}`, `{class} ({allowType}) on {name}` |
| `rowFields` | string[] | Official list fields shown in rows |
| `markers` | marker[] | `{id, when: <predicate over official fields and server facts>, text, tone}`; tone ∈ `caution`, `warning`, `neutral`. Web applications: `open-api` (warning), `no-auth` (caution), `static-only` (caution), research R10 |
| `links` | linkProvider[] | Provider ids from §1.3 |
| `mutations` | operationId[] | Mutation descriptors that apply to this entity type |

### 1.2 Mutation descriptor

| Field | Type | Rule |
|---|---|---|
| `operationId` | operationId | Official operation, or a FlightDeck request-mode id (`FLIGHTDECK REST execute`) |
| `kind` | `create` \| `edit` \| `delete` \| `request` | `PUT` resolves to `create` when the fingerprint is "absent" |
| `readOperation` | operationId | The GET that produces the current state; none for `request` |
| `target` | template | Text the user types for reinforced/maximum grade |
| `grade` | rule[] | Ordered `{when, grade, consequence?}`; first match wins; default `simple`. `when` predicates see `current`, `proposed`, `changedFields`, `isSystem`, `isFlightDeck` |
| `secretFields` | string[] | Masked before any response, trail record or log (Constitution VI) |
| `selfProtection` | rule[] | `{when, message}`; any match ⇒ `Blocked` |
| `impact` | providerId? | Impact provider id (§1.3) |
| `fieldSchema` | ref | Generated official schema (e.g. `Application`, `WebAppPctAccess`) |

Validation (build check `check-descriptors`): every referenced operationId exists; no descriptor
contains a privilege; every `delete` kind has a `target`; every rule predicate references only
official fields or the named context values.

### 1.3 Providers (backend)

| Provider | Input | Output | Official operations |
|---|---|---|---|
| `resource-roles` | resource name | roles granting it, permission, via (direct or granted role) | `GET /v2/security/roles`, `GET /v2/security/role` |
| `role-owners` | role names | users per role, counts | `GET /v2/security/role/owners` |
| `resource-public` | resource name | public permission | `GET /v2/security/resource` |
| `rest-service` | web application | discovered service id, has specification | `%REST.API` (R9) |
| `webapp-impact` | web application | affected users and objects, or `undetermined` with reason | composes the above |

## 2. Server session state

| Item | Scope | Lifetime | Content |
|---|---|---|---|
| Link cache | IRIS session | 30 s, invalidated by any `Applied` | provider results per key |
| FlightDeck applications | instance | install time | names and namespace written by the installer (R7) |

No fingerprint, preview or proposed state is stored on the server between requests: `apply`
receives everything it needs and re-reads.

## 3. Wire entities (contract: `contracts/flightdeck-api-002.openapi.json`)

### 3.1 EntityListResponse / EntityDetailResponse

- `entityType`, `operationId`, `items[]` (list) or `object` (detail): official objects unchanged.
- `markers[]` per item: `{id, text, tone}` resolved from the descriptor.
- `capped` (bool), `total` (int).
- Detail adds `displayName`, `isSystem`, `isFlightDeck`, `availableMutations[]` with the capability
  fields (`allowed`, `available`, `reason`) of each mutation operation.

### 3.2 LinksResponse

`groups[]`: `{provider, direction: in|out, label, state: ok|forbidden|unavailable|undetermined,
reason, count, items[{entityType, domain, displayName, keys, detail}]}`.

### 3.3 PreviewRequest → PreviewResponse

Request: `operationId`, `keys`, `proposed` (changed fields only for edit; full for create; none for
delete), or for request mode `request{method, path, query, headers, body}`; `tab`.

Response:

| Field | Rule |
|---|---|
| `kind` | create, edit, delete, request |
| `target` | display name |
| `rows[]` | `{field, label, current, commanded, changed, secret}`; `secret` rows carry no values, only `changed` |
| `noChange` | true ⇒ §9 message 18, `apply` never offered |
| `grade` | `simple` \| `reinforced` \| `maximum`, plus `confirmText` (what to type) and `consequence` |
| `impact` | `{state: ok|undetermined|none, summary, users[], objects[], reason}` |
| `blocked` | `{message}` when self-protection matches (§9 message 4) |
| `fingerprint` | opaque string; `absent` for create |
| `requestMode` | for `request`: the exact request, headers masked, `reason` for no current state |

### 3.4 ApplyRequest → ApplyResponse

Request: `operationId`, `keys`, `proposed` or `request`, `fingerprint`, `confirmation` (typed text,
empty for simple), `acknowledged` (bool, maximum grade), `tab`.

Responses:

| Status | Code | Meaning | Client behavior |
|---|---|---|---|
| 200 | — | Applied; `result` is the re-read official object (or the test response for request mode); `trail` is the masked record | Notice `Applied`, append `trail` |
| 403 | `SAFE_MODE_ON` | Router guard or executor | Offer disarm; nothing recorded |
| 403 | `SELF_PROTECTION` | §9 message 4 | Show; append `trail` (`Blocked`) |
| 409 | `STATE_CHANGED` | Fingerprint mismatch; body carries a fresh `PreviewResponse` | §9 message 17, show new diff, require new confirmation |
| 422 | `CONFIRMATION_REQUIRED` | Typed text or acknowledgement missing/wrong | Keep dialog |
| 4xx/5xx | `UPSTREAM_REJECTED` | Official API rejection; `raw` is the IRIS text; `validation` true for R2 input errors | Keep form, show verbatim; append `trail` (`Failed`) |

### 3.5 Trail record (produced by the server, stored by the client)

| Field | Rule |
|---|---|
| `id` | UUID |
| `time` | ISO 8601 UTC |
| `operationId`, `kind`, `target` | from preview |
| `rows[]` | as displayed; secrets as `changed` only |
| `request` | request mode only; headers and body masked |
| `result` | `Applied` \| `Failed` \| `Blocked` |
| `status` | HTTP status of the official call or test request |
| `message` | IRIS text or block reason |
| `concurrency` | `checked` plus the residual-window note |

Client trail document (`sessionStorage["flightdeck.trail.v1"]`):
`{version: 1, notice: "This trail is local to this browser tab and does not replace IRIS auditing.", entries: TrailRecord[] (max 500), dropped: int}`.
Export is this document, pretty-printed, named `flightdeck-trail-<ISO time>.json`.

State transitions of a dry-run (client):

```text
closed → previewing → ready(grade) → applying → applied
                         │  ↑            │
                         │  └─ stateChanged (409: recompute, re-confirm)
                         ├─ noChange (message 18)
                         ├─ blocked (message 4)
                         └─ rejected (keep form)          applying → expired → re-auth → previewing
```

### 3.6 REST explorer

- **RestService**: `webApplication`, `namespace`, `dispatchClass`, `enabled`, `kind`
  (`specification-first` | `hand-coded`), `hasSpecification`, `specificationSource`
  (`specification-first` | `published` | none), `routesReportedByPlatform` (bool).
- **SpecificationResponse**: `format` (`openapi-2.0` | `openapi-3.0`), `document`, or `routes`
  (metadata) when no specification.
- **ExecuteRequest**: `method`, `path` (starts with `/`), `query{}`, `headers{}`, `body` (string),
  `tab`. Validation: see research R8.1; `Authorization` and `Cookie` headers are rejected (400
  `CREDENTIAL_HEADER`), because the request runs as the signed-in user.
- **ExecuteResponse**: `status`, `elapsedMs`, `headers{}`, `body` (≤ 1 MB), `bodySize`,
  `truncated`, `contentType`, `resolved{webApplication, namespace, dispatchClass}`,
  `rolesMode` (`current-kept` | `login-only`), `grantsNotApplied` (roles the target application would
  grant to a real call and the test did not receive; non-empty ⇒ the divergence note is shown),
  `curl` never included (built by the client).

## 4. Composite capabilities (derived)

`CompositeCapability`: `id` (e.g. `web-apps.links.resource-roles`, `rest.execute`), `requires`
(union of the declared privileges of its operations, AND semantics across operations, each
operation's own OR preserved), `allowed`, `available`, `reason`. Computed from descriptors and the
generated capability data at session build (Constitution III).
