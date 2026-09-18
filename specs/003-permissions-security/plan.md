# Implementation Plan: Permissions, Security and Secrets

**Branch**: `003-permissions-security` | **Date**: 2026-09-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-permissions-security/spec.md`

## Summary

Two domains on the pattern delivered by feature 002. Permissions (31 official operations) adds
users, roles, resources, services and privileged routines as descriptor-declared entity types, plus
two computed capabilities that are the point of the feature: effective privileges with the chain
that grants each one, and impact analysis of a removal, both computed on the server and rendered by
components that already exist (the links panel and the dry-run's impact block). Security (88 of the
89 operations) adds one section per family — TLS, X.509, OAuth 2.0 in its three roles, wallet,
encryption (read-only), LDAP, MFT, audit, superserver, web authentication — where every secret field
is write-only in every layer and items with a reported expiry carry days remaining, a band and a
place on the home panel's attention list.

The work is mostly declarative: new descriptors, facts, markers, link providers, grade and
self-protection rules. Five things the pattern cannot express today are changed **in the pattern**
and its contract, not locally: an action-kind mutation (grant and revoke are POSTs with path
parameters), a parameterised inspector panel (SQL privileges need a namespace), singleton entity
types with no list, a policy-declared unavailable operation with a native path, and two extra fields
in the trail record for the last-administrator check mode.

## Technical Context

**Language/Version**: InterSystems ObjectScript (IRIS 2026.2 and 2026.1) for the backend; TypeScript
5 with React 18 and Vite 5 for the frontend, as delivered by features 001 and 002.

**Primary Dependencies**: the official SysAdmin API (`/api/admin/v2`, `/v1` through the existing
dialect adapter); FlightDeck's own layers: `FlightDeck.Admin.Client`, `FlightDeck.Capability.*`,
`FlightDeck.Domain.*` (descriptors, entity reads, facts, links), `FlightDeck.Mutation.*` (preview,
apply, grade, mask, self-protection, trail); on the frontend `src/pattern/*` and `src/mutation/*`.

**Storage**: none of its own. Everything is read from and written to IRIS through official
operations; the session trail stays in the tab's session storage.

**Testing**: `%UnitTest` classes under `backend/test/FlightDeck/Test` (the whole suite runs on every
version, enforced by `scripts/dev/test-backend.sh`), Vitest for pure frontend logic, Playwright
projects per domain, plus the static gates.

**Target Platform**: IRIS Community 2026.2, IRIS for Health 2026.2 and IRIS Community 2026.1
(limited mode), served by IRIS itself, no external runtime.

**Project Type**: web application inside the existing repository (ObjectScript backend plus a React
frontend compiled into a versioned `frontend/dist`).

**Performance Goals**: an entity list or inspector answers within the interaction budget already
used by feature 002 (no perceptible wait on a demo instance); effective privileges, the
last-administrator check and the per-alias certificate reads are bounded by a stated cap and cached,
never unbounded traversals or fan-outs (probes P3 and finding B).

**Constraints**: no credential or secret in any layer; no version or dialect check outside
`FlightDeck.Admin`; every mutation through the single shared layer; tokens only in CSS; both themes;
`frontend/dist` rebuilt and `check-dist.sh` passing.

**Scale/Scope**: 119 official operations owned by this feature (31 permissions + 88 security and
wallet), roughly 15 entity types, 2 domains, around 15 sections, on instances with up to a few
thousand users and roles.

## Constitution Check

*GATE: passed before Phase 0, re-checked after Phase 1.*

| Principle | How this feature satisfies it |
|---|---|
| **I. Official API first** | Every read and write is an official operation from `docs/api-coverage.md`. Effective privileges and impact are **compositions** of official reads, never a reimplementation over ObjectScript security classes. No native provider is added. |
| **II. Delegated identity** | No credential is stored or cached. Password and secret writes pass through and are never read back. |
| **III. Capabilities from the spec** | Availability and permission come from the capability map. The new policy-declared unavailability (encryption writes) is data attached to the map's entry, carrying a reason; it never becomes a hand-coded privilege or a version check. |
| **IV. Safe mode per tab** | No change: mutations are refused by the router while armed. |
| **V. Diff before every mutation** | Every write in both domains goes through the existing preview/apply service. Grant and revoke actions, which have no editable object, render the before/after privilege rows in the same component (see research R6). |
| **VI. Secrets are write-only** | Secret fields are declared per operation, removed from reads, masked in previews, trail and errors. The build check of research R9 fails when a field whose name looks like a secret is neither declared secret nor explicitly exempted with a reason. |
| **VII. Self-protection** | The last-administrator predicate (spec FR-010 to FR-010c) is evaluated on the server against re-read state, with its baseline, its two modes and the expiry comparison, and the trail records which mode ran. It counts `%Admin_Secure:USE` holders and `%All` members by name — role membership read from `User.Roles`, never an inference about what `%All` grants. |
| **VIII. Graceful degradation** | A section whose operations the instance does not offer, or that the user may not call, appears disabled with the reason; known platform defects are worked around visibly. |
| **IX. The API decides** | Object capability fields the schema declares (for example `AllowDelete` on resources) govern control state directly. |
| **X. design.md is binding** | Sections, markers, bands and the attention list use existing tokens and components; the design review and axe run over both themes. |
| **XI. English everywhere** | UI text, code comments and commits in English. |

**Scope note on Principle V (plan-level, not an amendment)**: a grant or revoke has no editable
object, but it does have a prior state: the set of privileges the grantee holds. The requirement is
satisfied by showing that set before and after the action, in the same component and with the same
confirmation grading. This delimits the principle's applicability; it does not create an exception.

**Scope note on Principle I (plan-level)**: encryption writes are available in the official API but
are declared unavailable by policy here (spec FR-020). Principle I requires using the official
endpoint *where FlightDeck offers the operation*; it does not require offering every operation. The
declaration is explicit, carries its reason and the native path, and is recorded in the coverage
document and the project's gap list, like the journal origin in feature 001.

**Post-Phase 1 re-check**: the five pattern changes listed in the Summary are changes to the shared
pattern and its contract, applied once and reusable by later domains; none of them puts a dialog, a
diff or a trail write outside `src/mutation/`. No violation remains; Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/003-permissions-security/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── flightdeck-api-003.openapi.json
│       (the UI pattern delta was folded into the feature 002 contract by T073)
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
backend/cls/FlightDeck/
├── Capability/
│   └── Policy.cls                  # NEW: operations declared unavailable by policy, with reason and native path
├── Domain/
│   ├── EntityTypes.cls             # EXTENDED: permissions and security entity types
│   ├── Facts.cls                   # EXTENDED: expiry facts (days remaining, band), user account facts
│   ├── LinkProviders.cls           # EXTENDED: registry of the new providers
│   └── Links/
│       ├── UserRoles.cls           # NEW: user -> roles -> inherited roles
│       ├── EffectivePrivileges.cls # NEW: privileges with provenance (RN-FD-10)
│       ├── RoleResources.cls       # NEW: role -> resources granted
│       ├── ResourceObjects.cls     # NEW: resource -> web applications, wallet collections, databases it protects
│       ├── RoleHolders.cls         # NEW: inverse traversal, owners of a role may be roles (probe finding B)
│       ├── WalletUsers.cls         # NEW: collection -> resource -> roles -> users
│       └── SqlPrivileges.cls       # NEW: parameterised panel (namespace) for a user or role
├── Mutation/
│   ├── Descriptors.cls             # EXTENDED: permissions and security mutations, grades, self-protection
│   ├── Action.cls                  # NEW: action-kind mutations (grant/revoke and other POST verbs)
│   ├── LastAdmin.cls               # NEW: the predicate, its baseline and its two modes (spec FR-010 to FR-010-2)
│   └── Service.cls                 # EXTENDED: action kind, check-mode fields in the trail record
├── Domain/Impact/
│   ├── RoleImpact.cls              # NEW
│   ├── ResourceImpact.cls          # NEW
│   └── SqlPrivilegeImpact.cls      # NEW
├── Security/
│   └── Validity.cls                # NEW: per-alias certificate reads with a cap and a cache (probe P3)
├── API/
│   ├── Attention.cls               # NEW: aggregated attention items for the home panel (RN-FD-15)
│   └── Router.cls                  # EXTENDED: new routes
└── Test/…                          # one test class per new provider, the predicate, and the policy

frontend/src/
├── domains/
│   ├── permissions/                # users, roles, resources, services, privileged routines
│   └── security/                   # tls, x509, oauth2, wallet, encryption, ldap, mft, audit, superserver, web-auth
├── pattern/                        # EXTENDED: parameterised panel, singleton entity support
├── mutation/                       # EXTENDED: action kind rows, check-mode in the trail entry
└── home/                           # EXTENDED: attention items

frontend/e2e/                       # permissions.spec.ts, security.spec.ts, secrets.spec.ts, last-admin.spec.ts
scripts/build/                      # EXTENDED: check-secrets.py, coverage ownership check
```

**Structure Decision**: the repository already has the layout features 001 and 002 established, so
this feature adds directories only under `backend/cls/FlightDeck/Domain/Links`, a new
`Domain/Impact`, and two frontend domain folders. Everything else is an extension of a file that
exists.

## Probe results folded into this plan

The five probes of research R15 ran before tasks were generated and are recorded in
`verification/permissions-security-probes-2026.2.md`. Two changed the design:

- **`%All` is not enumerable** and the default install's administrators hold only it, so the
  predicate counts `%All` membership by name and requires a baseline before it may block
  (spec FR-010, FR-010-1). Without this the portal would refuse ordinary changes on a stock
  Community instance.
- **`role/owners` answers with direct owners, which may be roles**, so `RoleHolders.cls` performs the
  inverse traversal with the same guards as the forward one.

Three refined it: expiry must be compared against `ExpirationDate` because an expired account is
still reported as enabled; SQL provenance comes from the API's own `GrantedVia` and is not
recomputed; certificate validity exists only per alias, so it is cached with a cap and degrades to
"validity not read".

## Complexity Tracking

No constitution violation requires justification. The two scope notes above delimit principles I and
V; they add no new construct and are recorded in this plan rather than amending the constitution.
