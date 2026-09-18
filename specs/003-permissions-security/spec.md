# Feature Specification: Permissions, Security and Secrets

**Feature Branch**: `003-permissions-security`

**Created**: 2026-09-17

**Status**: Draft

**Input**: User description: "Permissions and security: the privilege chain, impact analysis, and
secret material that is never displayed. Scope: UC05 and UC06 from docs/prd.md Section 7, with their
Gherkin acceptance criteria verbatim as the definition of done; full coverage of the 31 permission
operations and the 89 security and wallet operations; built on the pattern delivered by feature 002,
which it composes and never re-invents; effective privileges always shown with provenance; impact
analysis computed server-side and shown in the existing dry-run; self-protection for the last
administrative access and reinforced confirmation when the change affects the signed-in user; secret
material never displayed, returned or logged; temporal treatment for items with an expiry; TLS
connection test with the platform's own result. Out of scope: tasks, system and logs."

## Clarifications

### Session 2026-09-17

- Q: Where do SQL privileges live, given that the official listings require a namespace and a
  grantee and there is no "list them all"? → A: Only as a panel inside the user and role inspectors,
  with a namespace choice. The command palette carries an action named "SQL privileges" that opens
  the chosen user's or role's inspector with that panel already open, so the family is reachable by
  its own name.
- Q: Do the encryption key file operations (create a key file, add or remove administrators,
  activate and deactivate a key) ship as writes? → A: No. Encryption is read-only in this feature,
  and each write is declared unavailable with its reason and the native path to perform it. Creating
  an encryption key file is the only operation in this project that can make data permanently
  unreadable with no recovery through the portal, and there is no safe way to exercise it within the
  schedule. The unavailability is declared with a reason, in the same manner as the journal origin
  in feature 001: a stated limit, not a silent gap.
- Q: How is "the last administrative access to the instance" defined, given that the session may not
  be allowed to read every user and role? → A: Narrowly, and with two modes. The predicate is: after
  the proposed change, at least one enabled and unexpired user still holds `%Admin_Secure:USE`. It
  does not attempt to cover `%All`, delegated access, LDAP or roles granted by an external
  mechanism, because those are not reliably enumerable and each one widens the false-positive area.
  When the session can read users, roles and resources, the predicate holds and a violation is an
  affirmative block. When the session's view is partial, the portal neither asserts nor denies: it
  states that the check was incomplete, names what it could not read, and requires the reinforced
  confirmation instead of blocking. The general rule is to block on certainty, never on suspicion;
  where there is doubt, the reinforced confirmation names the doubt. The mode used and the
  predicate's result are both recorded in the session trail. Asserting "this is the last
  administrative access" from a partial read would invent a guarantee the session does not have:
  self-protection holds where it is verifiable and declares itself incomplete where it is not.
- Q: The probes (`verification/permissions-security-probes-2026.2.md`) showed that `%All` reports no
  resources and no granted roles in the official API, and that on a default IRIS Community install
  the real administrators hold only `%All`. Does the narrow predicate survive? → A: It is revised on
  two points. First, a user is counted when they hold `%Admin_Secure:USE` **or** when their `Roles`
  contain `%All` by name. Counting `%All` this way is reading role membership from `User.Roles`,
  which carries the literal string, not resolving what `%All` grants; the rule of blocking only on
  certainty is preserved, and the message keeps stating that delegated access and LDAP are not
  covered. Second, a baseline is required: the affirmative block happens only when the counted set
  was non-empty **before** the change and is empty **after** it. A set that was already empty before
  the change means the predicate cannot see this instance's administrative access at all, which is
  the partial mode, not a block.
- Q: Where is the boundary with the logs feature for the audit operations? → A: The boundary is
  mutation against reading, not configuration against records. Audit writes stay here, under the
  mutation layer that already exists, with record purge at the maximum grade because it erases the
  audit trail itself. Reading audit records goes to the logs feature, where it is presented in the
  unified flow. The split of the 89 operations is recorded in this spec.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Follow the whole chain between a user and a resource (Priority: P1)

An administrator opens the permissions domain and works through its sections: users, roles,
resources, services, SQL privileges and privileged routines. Selecting a user shows every privilege
that user effectively holds and, beside each one, the chain that grants it: which role, through
which inherited roles, granting which resource with which permissions. From any entity they reach
the entities connected to it in one click, in either direction: from a resource to the roles that
grant it and the users who hold those roles, from a role to the resources it grants and the users
and owners who hold it.

**Why this priority**: this is the domain of highest perceived value and the main Complexity
argument. The platform's own portal shows the pieces; showing the chain, with provenance, is what
this feature exists for. It is also entirely read-only, so it delivers value before any change is
possible.

**Independent Test**: sign in on an instance with the demo roles and users, open a user who holds a
privilege through an inherited role, and confirm the privilege and its granting chain are both
displayed; then walk resource → roles → users and back without losing the inspector.

**Acceptance Scenarios**:

1. **(PRD UC05-1)** **Given** a user holds a privilege through an inherited role, **When** their
   effective privileges are displayed, **Then** the privilege appears, **And** the chain of roles
   that grants it is displayed with it.
2. **Given** a privilege granted directly and the same privilege granted through a role, **When**
   effective privileges are displayed, **Then** both origins are listed for that privilege, never a
   merged result without origin (RN-FD-10).
3. **(PRD UC05, A3)** **Given** a role granted by an external mechanism, delegation or LDAP, **When**
   the user's roles are displayed, **Then** that origin is marked, **And** the screen states that the
   portal does not manage it there.
4. **(PRD UC05, A4)** **Given** a system-defined entity (a system role, resource or service),
   **When** it is inspected, **Then** everything about it is visible, **And** the operations the
   platform does not allow on it are disabled with their reason.
5. **Given** any permissions entity, **When** it is inspected, **Then** its incoming and outgoing
   links are shown with counts, **And** each link opens the linked entity in one click (RN-FD-13).
6. **Given** SQL privileges and privileged routines, **When** a user or role is inspected, **Then**
   the SQL privileges held and the privileged routine applications appear in the same chain, not in
   a separate unlinked screen.
7. **Given** an administrator who knows the family by name but not where it lives, **When** they
   search the palette for "SQL privileges" and choose a user or role, **Then** that entity's
   inspector opens with the SQL privileges panel already open for a chosen namespace.

---

### User Story 2 - Change a permission only after seeing who loses access (Priority: P1)

The administrator proposes a change: removing a role from a user, revoking a resource permission
from a role, deleting a role or a resource, revoking a SQL privilege. Before anything is applied the
shared dry-run shows the field-by-field difference and, in its impact block, the users who lose
access and the protected objects that become unreachable. Changes that would remove the last
administrative access to the instance are refused by the server with an explanation. Changes that
affect the signed-in user's own access require the reinforced confirmation and warn that the effect
is immediate.

**Why this priority**: RN-FD-11 and RN-FD-12 are the reason a permissions screen can be trusted at
all. Without them this domain is a faster way to lock yourself out.

**Independent Test**: with safe mode off, propose removing a role that grants a resource, read the
list of affected users and objects in the dry-run, cancel, and confirm nothing changed; then try to
remove your own last administrative role and see the block.

**Acceptance Scenarios**:

1. **(PRD UC05-2)** **Given** the administrator proposes removing a role from a resource, **When**
   the dry-run is displayed, **Then** the users who lose access are listed, **And** the protected
   objects that become inaccessible are listed.
2. **(PRD UC05-3)** **Given** the change would remove the last administrative access to the
   instance, **When** the administrator confirms, **Then** the operation is blocked and the reason
   explained.
3. **(PRD UC05-4)** **Given** the change affects the user of the current session, **When** the
   dry-run is displayed, **Then** reinforced confirmation is required, **And** the immediate effect
   on the session is stated.
4. **Given** a proposed change whose impact cannot be determined, because the signed-in user may not
   read the roles or users involved, **When** the dry-run is displayed, **Then** the impact block
   states that it could not be determined and why, and never shows an empty list as if nothing were
   affected.
5. **Given** the same mutation reaches the server by any path, including a direct request that never
   opened the dry-run, **When** the check runs in complete mode and the change would leave no
   enabled, unexpired user holding `%Admin_Secure:USE`, **Then** the server refuses it and the
   attempt is recorded in the session trail as blocked.
5a. **Given** the session may not read the users or roles the check needs, **When** a change that
   could remove administrative access is proposed, **Then** the dry-run states that the check was
   incomplete and names what could not be read, **And** the reinforced confirmation is required,
   **And** the change is not blocked.
5b. **Given** a change applied after an incomplete check, **When** the session trail is read,
   **Then** the record states the mode used and the predicate's result, so it is distinguishable
   from a change applied under a complete check.
5c. **Given** an instance whose administrative access the predicate cannot see at all — no enabled,
   unexpired user holds `%Admin_Secure:USE` or `%All` before the change — **When** a protected change
   is proposed, **Then** it is not blocked: the check reports itself incomplete and the reinforced
   confirmation is required.
5d. **Given** the only remaining administrator's account is past its expiry date, although the
   official API still reports it as enabled, **When** the change that removes the last unexpired
   administrator is proposed, **Then** the check counts that account as not holding access and the
   change is blocked in complete mode.
6. **Given** a password or other secret field is part of a permissions mutation, **When** the
   dry-run and the trail show the change, **Then** only "changed" or "unchanged" appears, never a
   value.

---

### User Story 3 - Administer security and secrets without ever seeing a secret (Priority: P2)

The administrator opens the security domain and chooses a section: TLS configurations, X.509
credentials, OAuth 2.0 (client, server and resource server), wallet, encryption, LDAP, MFT, audit
configuration, superserver and web authentication. Each section lists its items with state, validity
where it applies and links. Secrets, private keys and client secrets can be set, replaced or
deleted, and are never displayed or returned. A TLS configuration can be tested on demand, and the
platform's own result is shown as returned. Sections the instance does not offer appear disabled
with the reason, and the rest keep working.

**Why this priority**: the largest domain of the official API and the literal reading of the
contest's "etc". It depends on nothing from US1 and US2 except the shared pattern, so it can ship
independently, but the permissions chain is the stronger argument and goes first.

**Independent Test**: open the wallet section, create a collection and a secret, reopen the secret
and confirm no value is shown and only replace and delete are offered; then run a TLS connection
test and read the platform's verbatim result.

**Acceptance Scenarios**:

1. **(PRD UC06-1)** **Given** a secret stored in the wallet, **When** the user opens that secret's
   detail, **Then** its content is not displayed in any form, **And** only the replace and delete
   operations are offered.
2. **(PRD UC06-3)** **Given** a section of the domain is not available on the instance, **When** the
   user opens the domain, **Then** that section appears disabled with the reason, **And** the other
   sections work normally.
3. **(PRD UC06-4)** **Given** the user opens a wallet collection protected by a resource, **When**
   the detail is displayed, **Then** it is possible to see, in one click, which users can use its
   secrets.
4. **(PRD UC06, A4)** **Given** a TLS connection test fails, **When** the result is shown, **Then**
   the original error is displayed, **And** the configuration is unchanged.
5. **(PRD UC06, A5)** **Given** the deletion of a wallet collection that holds secrets, **When** the
   dry-run is displayed, **Then** the confirmation is reinforced, **And** the number of secrets
   affected is stated.
6. **Given** any security mutation that carries secret material, **When** it is previewed, applied,
   recorded in the trail or exported, **Then** no secret value appears anywhere, including in error
   messages that echo the input.
7. **Given** the encryption section, **When** it is opened, **Then** settings, key files, key file
   administrators and data element keys are readable, **And** every write is disabled with its
   stated reason and the native path that performs it.
8. **Given** a purge of audit records, **When** the dry-run is displayed, **Then** the maximum
   confirmation is required with the consequence stated, because the instance's own audit trail is
   erased; **And** copying records to another namespace requires the reinforced confirmation naming
   the destination.

---

### User Story 4 - Know what expires before it expires (Priority: P3)

Items with a validity period — X.509 credentials and the certificates behind TLS configurations —
show how many days remain and which band they are in: valid, expiring within the alert window, or
expired. The items in the alert window and the expired ones are aggregated on the home panel among
the attention items, so an administrator who never opens the security domain still learns that
something is about to break.

**Why this priority**: it turns a list into an instrument, and it is what makes the home panel worth
opening daily. It depends on US3's reads, so it comes after them.

**Independent Test**: with a credential whose certificate expires inside the alert window, confirm
the band and remaining days in the list and the same item aggregated on the home panel.

**Acceptance Scenarios**:

1. **(PRD UC06-2)** **Given** a certificate that expires inside the alert window, **When** the user
   opens the home panel, **Then** that certificate appears among the attention items.
2. **Given** a list of items with validity, **When** it is displayed, **Then** each item shows the
   days remaining and its band, and the bands are distinguished by more than color alone.
3. **Given** an item whose validity the platform does not report, **When** it is displayed, **Then**
   it states that the validity is unknown, and is not counted as valid.

---

### Edge Cases

- A role, resource or user is deleted by someone else between the preview and the apply: the server
  re-reads before writing and refuses with the concurrency message rather than overwriting.
- The signed-in user loses, mid-session, the privilege that the open screen needs: the next read
  fails with the official 403 and the screen states it, keeping the last known values visible.
- A resource is granted to a role that no user holds: the impact block reports zero affected users
  explicitly, which is different from "could not be determined".
- A user holds the administrative privilege only through an escalation role: the check counts it as
  held, and the reason says so.
- Every remaining administrator is disabled or past its expiry date: the predicate treats them as
  not holding the privilege, so the change is blocked in complete mode and named in the reason.
- The instance's administrative access exists only through delegated authentication or LDAP: the
  predicate deliberately does not count those, so a complete-mode block may be issued although
  another path exists. This is the accepted cost of a predicate that only counts what it can read,
  and FR-010b-1 requires the reason to say what was counted and what was not.
- No enabled, unexpired user holds `%Admin_Secure:USE` or `%All` even before the change: the
  predicate has no baseline, so it reports itself incomplete rather than refusing every change
  (FR-010-1).
- The instance has a large number of users and roles: impact analysis states how many entities it
  examined, and says so when the answer is partial rather than silently truncating.
- An official operation returns a defect already recorded in `verification/README.md` (for example
  the LDAP configurations listing failing for a user with `%Admin_Operate` only): the screen shows
  the official message and the section stays usable for the operations that do work.
- A secret is written and the official API echoes part of the input in an error: the error is masked
  before it reaches the client or the trail.
- Encryption key files and key activation exist on the instance but the signed-in user may not read
  them: the section appears with the privilege reason, not as an empty list.

## Requirements *(mandatory)*

### Functional Requirements

#### Permissions domain (UC05)

- **FR-001**: The permissions domain MUST cover the 31 official operations listed in
  `docs/api-coverage.md` for users, roles, resources, services, SQL privileges, SQL admin
  privileges, SQL column privileges and privileged routines. Every one of them MUST be implemented
  or explicitly degraded with a reason obtained from the capability map.
- **FR-002**: The domain MUST present sections for users, roles, resources, services and privileged
  routines, each as a list and inspector built from the shared pattern, with the entity's official
  fields, server-computed markers and links.
- **FR-003**: For a user, the portal MUST display the effective privileges with the provenance of
  each one: the chain of roles (direct, inherited and escalation) and the resource and permissions
  that grant it. A privilege MUST NEVER be displayed without its origin (RN-FD-10).
- **FR-004**: The portal MUST mark roles whose origin the platform reports as external (delegated,
  LDAP or another mechanism) and state that it does not manage them there.
- **FR-005**: Every permissions entity MUST expose incoming and outgoing links with counts, each
  opening the linked entity in one click, including links that cross into the web applications
  domain already delivered (RN-FD-13).
- **FR-006**: SQL privileges, SQL admin privileges and SQL column privileges MUST appear as a panel
  inside the user and role inspectors, for a namespace the user chooses, and MUST be granted and
  revoked through the same mutation layer as any other change. They MUST NOT become a separate
  top-level list, because the official listings answer only for a given namespace and grantee.
- **FR-006b**: The provenance of a SQL privilege MUST be the one the official listing reports in its
  own fields (`GrantedVia`, for example `Role:FD_Ops` or `Owner Privilege`, and `GrantedBy`).
  FlightDeck MUST NOT compute a second answer by traversing roles itself for SQL privileges: the
  API already resolves the chain, and a divergent local answer would be a second source of truth.
- **FR-006a**: The command palette MUST offer an action named after the family ("SQL privileges")
  which, for a chosen user or role, opens that entity's inspector with the SQL privileges panel
  already open, so the family is reachable by its own name and not only by knowing where it lives.
- **FR-007**: User creation, editing, deletion and password change MUST be offered through the
  official operations, with the password treated as a secret field in every layer.

#### Impact analysis and self-protection (UC05, RN-FD-11, RN-FD-12)

- **FR-008**: Every removal or revocation in the permissions and security domains MUST run an impact
  analysis before the confirmation, computed on the server, listing the users who lose access and
  the protected objects that become inaccessible.
- **FR-009**: The impact analysis MUST be displayed inside the existing dry-run's impact block. It
  MUST distinguish three states: a determined result (with its lists), no affected entity, and not
  determined with the reason (for example a privilege the signed-in user lacks).
- **FR-010**: The server MUST evaluate, for any change that could remove administrative access, the
  last-administrator predicate over the set of **enabled, unexpired users who either hold
  `%Admin_Secure:USE` or have `%All` among their roles**. `%All` is counted by **name**, read from
  `User.Roles`, which carries the literal string; the predicate MUST NOT try to resolve what `%All`
  grants, because the official API reports no resources for it. The predicate MUST NOT attempt to
  account for delegated access, LDAP or roles granted by an external mechanism; those are not
  reliably enumerable and including them would widen the area of false positives.
- **FR-010-1**: The predicate MUST require a baseline: the affirmative block happens **only when the
  counted set was non-empty before the change and is empty after it**. When the set was already
  empty before the change, the portal MUST NOT block — it cannot see this instance's administrative
  access, which is the partial mode of FR-010a.
- **FR-010-2**: Membership MUST be decided by the account's state, not by a single flag: a user
  counts only when `Enabled` is true **and** the account is not past its `ExpirationDate`. An
  expired account is still reported as enabled by the official API, so counting it would let through
  exactly the change that locks the instance out.
- **FR-010a**: The evaluation MUST run in one of two modes, decided only by what the signed-in
  session can actually read through official operations:
  - **complete** — the session can read the users, roles and resources the predicate needs: the
    predicate holds, and a violation is an affirmative block, refused by the server whatever path it
    arrives by, with its reason;
  - **partial** — any needed read is refused: the portal MUST NOT assert or deny. It MUST state that
    the check was incomplete, name what it could not read, and require the reinforced confirmation
    instead of blocking.
- **FR-010b**: The general rule MUST hold across this feature: block on certainty, never on
  suspicion. Where there is doubt, the reinforced confirmation names the doubt rather than a block
  being issued or the doubt being hidden.
- **FR-010b-1**: A block MUST state what it counted — holders of `%Admin_Secure:USE` and members of
  `%All` — and that delegated access and LDAP were not counted. The feature may still refuse although
  an administrative path exists outside the predicate; the reason makes that visible instead of
  implying an exhaustive check.
- **FR-010c**: The session trail record MUST carry the mode used (complete or partial) together with
  the predicate's result, so a reader of the trail can tell an affirmative block from a change
  applied under an incomplete check. A blocked attempt MUST be recorded as blocked.
- **FR-011**: A change that affects the signed-in user's own access MUST require the reinforced
  confirmation and state that the effect is immediate in the current session.
- **FR-012**: Self-protection and impact rules MUST be declared as descriptor data for the operation
  they protect, evaluated on the server against the state re-read immediately before writing, never
  decided by the client.

#### Security and secrets domain (UC06)

- **FR-013**: The security domain MUST cover the 89 official operations listed in
  `docs/api-coverage.md`: the 7 wallet operations and the 82 security operations for TLS, X.509,
  OAuth 2.0 (client, server, resource server), encryption, LDAP, MFT, audit configuration,
  superserver, web authentication and delegated authentication. Every one MUST be implemented or
  explicitly degraded with a reason.
- **FR-014**: The domain MUST present one section per family, and a section whose operations the
  instance does not offer MUST appear disabled with the reason from the capability map, while the
  other sections keep working.
- **FR-015**: Secret material — wallet secrets, private keys, client secrets, passwords and tokens —
  MUST never be displayed, never be returned by the portal's API, and never be written to a log or
  the session trail. Only set, replace and delete are offered (RN-FD-14).
- **FR-016**: A wallet collection MUST link to the resource that protects it, and from there to the
  roles and users that can use its secrets, in one click.
- **FR-017**: Deleting a wallet collection that holds secrets MUST use the reinforced confirmation
  and state the number of secrets affected.
- **FR-018**: TLS configurations MUST offer the platform's connection test on demand and display the
  platform's own result, success or failure, without reinterpretation, leaving the configuration
  unchanged (RN-FD-16).
- **FR-019**: Operations that generate, rotate or register credentials through the official API (for
  example OAuth client registration, key rotation and initial access tokens) MUST be offered through
  the same confirmation path as other mutations, and their responses MUST be masked before they
  reach the client.
- **FR-020**: Encryption MUST be read-only in this feature. Encryption settings, key files, key file
  administrators and data element keys are displayed; the operations that create a key file, add or
  remove a key file administrator, activate a key, deactivate a key or change encryption settings
  MUST be declared unavailable, each with its reason and with the native path that performs it
  ("System Administration > Encryption" in the platform's own management portal). The declaration
  MUST use the same mechanism as any other unavailable operation, so the coverage document and the
  capability map agree, and the control states the reason instead of being hidden.
- **FR-020a**: The recorded reason MUST state why: creating an encryption key file can make an
  instance's data permanently unreadable, with no recovery through the portal, and this feature has
  no safe way to exercise it. This is a declared limit, recorded in the coverage document and in the
  project's own gap list, not a silent omission.
- **FR-021**: The boundary between this feature and the logs feature for audit is **mutation against
  reading**, not configuration against records. This feature MUST carry every audit write, through
  the existing mutation layer: enabling and disabling auditing, clearing an event count, copying
  audit records to another namespace and purging audit records, plus the configuration read that
  shows the current state.
- **FR-021a**: Purging audit records MUST use the maximum confirmation grade, with the consequence
  stated, because it erases the instance's own audit trail — the record that outlives the portal's
  session trail. Copying records MUST use the reinforced grade and name the destination namespace.
- **FR-021b**: Reading audit records MUST NOT be part of this feature: the record listing operation
  belongs to the logs feature, where records are presented in the unified flow. The split is
  recorded in the operation ownership table below.

#### Operation ownership (the 89 security and wallet operations)

- **FR-021c**: This feature MUST implement or explicitly degrade **88** of the 89 operations: all 7
  wallet operations and 81 of the 82 security operations.
- **FR-021d**: The single operation that moves to the logs feature is the audit **record listing**
  (`POST /v2/security/audit/records`), a read presented in the unified log flow. It MUST NOT be
  counted as degraded here; the coverage document MUST name the feature that owns it.
- **FR-021e**: Of the 88, the operations declared unavailable by FR-020 (encryption writes) MUST be
  listed individually in the coverage document with their reason, so "implemented" and "declared
  unavailable" are never confused with "missing".
- **FR-021f**: The five audit operations that `docs/api-coverage.md` lists under the logs domain
  (audit event definition read, create, edit and delete, and reading one audit record) are outside
  the 89 and outside this feature's scope. By the same criterion, the event definition writes are
  mutations and must run through the shared mutation layer wherever they ship; this spec records the
  question for the logs feature rather than annexing those operations now.

#### Temporal lifecycle (UC06, RN-FD-15)

- **FR-022**: Items whose validity the platform reports MUST display the days remaining and a band:
  valid, expiring within the alert window, or expired. Bands MUST be distinguishable without relying
  on color alone.
- **FR-022a**: Validity is reported per item, not by the listing, so a list of N items needs N extra
  reads. Those reads MUST be cached with a stated cap; beyond the cap, or when a read is refused, the
  item MUST show "validity not read" with the reason, and MUST NOT be counted as valid or silently
  omitted from the attention list.
- **FR-023**: Items in the expiring and expired bands MUST be aggregated on the home panel among the
  attention items, with the count and one click to the item.
- **FR-024**: An item whose validity the platform does not report MUST state that it is unknown and
  MUST NOT be counted as valid.

#### Reuse of the delivered pattern

- **FR-025**: Every screen in this feature MUST be composed from the pattern modules delivered by
  feature 002 and from the single shared dry-run and session trail. No new confirmation dialog, diff
  renderer or trail writer may be added; the existing build gate MUST keep failing the build if one
  is.
- **FR-026**: New entity types, mutations, markers, facts, grades, self-protection rules and impact
  providers MUST be declared as descriptor data, as documented in the pattern's own guide. A need
  the pattern cannot express MUST be satisfied by changing the pattern and its contract, not by a
  local component in this feature.
- **FR-027**: Behaviour these domains do not exercise but the pattern must guarantee MUST be proven
  in the pattern catalog fixture, not in a one-off screen.

#### Cross-cutting

- **FR-028**: Availability and permission of every operation MUST come from the capability map
  derived from the official specification. No code outside the official-API client may consult the
  instance version or dialect, and the existing gate MUST keep enforcing it.
- **FR-029**: Mutations MUST be refused by the server while the tab's safe mode is armed,
  independently of the interface.
- **FR-030**: Official errors MUST be shown verbatim, and platform defects already recorded in
  `verification/README.md` MUST be worked around visibly and documented, never silently masked.
- **FR-031**: The routes for tasks, system and logs MUST keep rendering the empty state from feature
  001.

### Key Entities

- **User**: an IRIS account, with its roles (direct and escalation), its state and its effective
  privileges with provenance.
- **Role**: a named set of privileges, which may inherit other roles, is held by users and owners,
  and grants permissions on resources.
- **Resource**: what a privilege protects, with its public permission and the objects it guards
  (databases, web applications, wallet collections and others).
- **Service**: a system-defined access service, editable but never creatable.
- **SQL privilege**: a privilege held by a user or role over a table, view, column or SQL
  administrative action, in a namespace.
- **Privileged routine application**: a routine application granted a role while it runs.
- **TLS configuration**: a named client or server configuration, with its certificate's validity and
  an on-demand connection test.
- **X.509 credential**: a stored certificate with its validity window and the private key that is
  never readable.
- **OAuth 2.0 configuration**: client configurations, server definitions, the authorization server
  and resource servers, each with secrets that are only ever set.
- **Wallet collection and secret**: a protected group of secrets whose values are never returned.
- **Effective privilege**: a computed statement that a user holds a permission on a resource, always
  carrying the chain that grants it.
- **Impact**: the server's answer to "who and what loses access if this is applied", with its state
  (determined, none, or undetermined with a reason).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An administrator can answer "why does this user have access to this resource" in under
  60 seconds, starting from the home panel, and the answer names every role in the chain.
- **SC-002**: 100% of the 31 permission operations and of the 88 security and wallet operations this
  feature owns are implemented or listed as declared-unavailable with a reason; the coverage document
  matches what ships and names the feature that owns the one operation moved to logs.
- **SC-002a**: Every encryption write is declared unavailable with a reason that names the native
  path, and 0 of them are hidden from the interface.
- **SC-003**: 0 secret values appear in any portal response, screen, session trail, trail export or
  IRIS log after a session that creates, replaces and deletes wallet secrets, OAuth secrets and a
  user password.
- **SC-004**: 100% of removals and revocations show an impact result before confirmation, and 0 of
  them show an empty list when the impact could not be determined.
- **SC-005**: With a complete view and a non-empty baseline, an attempt to leave no enabled,
  unexpired user holding `%Admin_Secure:USE` or `%All` is refused on the server in 100% of paths
  tried, including a direct request that never opened the interface, and the instance is unchanged
  afterwards. An expired account is counted as not holding access in 100% of the cases tested.
- **SC-005a**: With a partial view, or with an empty baseline, 0 changes are blocked by the
  predicate and 100% of them state the incomplete check, name what could not be read, and require
  the reinforced confirmation; every resulting trail record names the mode used.
- **SC-005b**: On a default IRIS Community install, where the administrators hold `%All`, 0 ordinary
  permission changes are refused by the predicate.
- **SC-006**: A change affecting the signed-in user's own access always requires the reinforced
  confirmation, in 100% of the cases tested.
- **SC-007**: Every item with a reported validity shows days remaining and a band, and items in the
  alert window appear on the home panel within one refresh of the panel.
- **SC-008**: 0 new confirmation dialogs, diff renderers or trail writers exist outside the shared
  mutation layer; the build gate proves it.
- **SC-009**: On an instance that does not offer a section, that section is disabled with its reason
  and every other section still works, with 0 screens that fail to render.
- **SC-010**: Accessibility and design gates report 0 violations on every new screen in both themes.

## Assumptions

- **Official coverage lists**: the operation lists and their declared privileges are those in
  `docs/api-coverage.md` (31 permission operations, 82 security plus 7 wallet operations), which was
  derived from the official specification.
- **Provenance data**: the chain of roles and the owners of a role come from official operations
  (role details and the role owners operation); where the platform does not report an origin, the
  portal says so rather than inferring it.
- **Alert window**: the expiry alert window is the one already used by the home panel from feature
  001, so this feature adds bands rather than a new policy.
- **Impact scope**: impact is computed from what the signed-in user may read through official
  operations; when a needed read is refused, the result is "not determined" with that reason.
- **Last administrative access**: the predicate of FR-010, verified against a live instance in
  `verification/permissions-security-probes-2026.2.md`. `%Admin_Secure:USE` is the privilege the
  official specification declares for the permissions and security operations themselves, so losing
  it is what locks administration out of this domain; the privilege name comes from the capability
  data. `%All` is counted as a role name read from `User.Roles`, because the official API reports no
  resources for it and the default install's administrators hold nothing else.
- **Role holders**: the official `role/owners` operation answers with the **direct** owners of a
  role, and an owner may itself be a role. Finding the users behind a role needs the inverse
  traversal, with the same cycle guard and cap as the forward one (probe finding B).
- **Where partial mode is testable**: every permission operation declares `%Admin_Secure:U` for both
  reads and writes, so inside the permissions domain a session that may write may always read, and
  partial mode is unreachable by privilege. It is reachable in the security domain, whose mutations
  declare `%Admin_Wallet:U` and the OAuth privileges; the end-to-end test for partial mode therefore
  uses a wallet-only administrator deleting a collection without being able to read the users behind
  its resource. A test written in the permissions domain would give false confidence.
- **Secrets in the schema**: which fields are secret is declared per operation in descriptor data,
  following the official schema; a field whose nature is ambiguous is treated as secret.
- **Limited mode**: on IRIS 2026.1 the sections follow the capability map like any other operation;
  this feature adds no version check.
- **Demo data**: the demo roles, resources and wallet collection created by the installer are the
  fixtures for acceptance tests, extended where a scenario needs an expiring certificate.
- **Out of scope**: tasks, system and logs, including the unified log flow and the reading of audit
  records, which the clarification placed in the logs feature.
- **Native path for encryption**: the portal names the platform's own management portal path for the
  encryption operations it declares unavailable; it does not link into it or drive it.
