---

description: "Task list for feature 003: permissions, security and secrets"
---

# Tasks: Permissions, Security and Secrets

**Input**: Design documents from `/specs/003-permissions-security/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), and the probe results in
`verification/permissions-security-probes-2026.2.md`.

**Tests**: test tasks are included because the spec's acceptance scenarios are the definition of
done, as in features 001 and 002.

**Organization**: by user story. US1 and US2 are the permissions domain (P1), US3 the security
domain (P2), US4 the temporal lifecycle (P3). The five pattern changes are in the foundational
phase, because every story consumes them and they must land in `src/pattern/` or `src/mutation/`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1, US2, US3, US4
- Paths are repository-relative and exact

---

## Phase 1: Setup (shared infrastructure)

- [X] T001 Add this feature's official schemas to `scripts/build/gen-schemas.py`: `User`, `UserList`,
  `Role`, `RoleList`, `Resource`, `ResourceList`, `Service`, `ServiceList`,
  `PrivilegedRoutineApplication`, `PrivilegedRoutineApplicationList`, `SSLConfig`,
  `SSLConfigurationList`, `X509Credential`, `X509CredentialsList`, `X509CredentialCertificate`,
  `WalletCollection`, `WalletCollectionList`, `WalletSecretList`, `OAuth2Client`,
  `OAuth2ServerClient`, `OAuth2ServerDefinition`, `OAuth2ResourceServer`, `LDAPConfig`,
  `LDAPConfigurationList`, `MFTConnection`, `MFTConnectionList`, `Superserver`, `SuperserverList`,
  `WebAuthenticationSettings`, `EncryptionSettings`, `AuditingEnabled`, `SQLPrivilegeList`,
  `SQLAdminPrivilegeList`, `SQLColumnPrivilegeList`, `RoleOwnerList`; regenerate and run
  `scripts/build/check-generated.sh`.
- [X] T002 Merge `specs/003-permissions-security/contracts/flightdeck-api-003.openapi.json` into the
  served document in `scripts/build/gen-openapi-cls.py` (`contracts_merge`), the way the 002 contract
  is merged, and regenerate `backend/cls/FlightDeck/API/OpenAPI.cls`.
- [X] T003 [P] Create `scripts/build/check-secrets.py` (research R9): scan `docs/sysadmin-api-v2.json`
  for request-body fields whose name matches password, secret, token or credential, plus every
  `writeOnly` field, and fail when one is neither declared in a descriptor's `secretFields` nor listed
  in `scripts/build/secret-exemptions.json` with a reason.
  _Note: the gate is wired into `scripts/build/check-generated.sh` in T050, when the descriptors that
  declare the 12 genuine secrets exist; wiring it here would leave the build red between tasks._
- [X] T004 [P] Extend `backend/cls/FlightDeck/Install/Demo.cls` with the fixtures these stories need:
  a three-level role chain (`FD_Demo_L1` grants `FD_Demo_L2` grants `FD_Demo_L3`, which grants
  `FD_Demo_Billing:U`) and one wallet secret. Keep it idempotent and behind the demo flag.
  _Note: the demo users moved to the end-to-end setup (T005). A user needs a password, and the
  installer creates no credential (Constitution II). The wallet secret's name is
  `FD_Demo_Vault.FD_Demo_Token`: the official API names a secret `<collection>.<secret>` in a single
  parameter._
- [X] T005 [P] Add the Playwright projects `permissions`, `security`, `secrets` and `last-admin` to
  `frontend/playwright.config.ts`, and create the wallet-only administrator
  (`fd_e2e_wallet`, role granting `%Admin_Wallet:U` only) in `frontend/e2e/setup/users.ts`, which
  probe P5 showed is the only way to reach partial mode by privilege.

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the five pattern changes of `contracts/ui-pattern-delta.md`, plus the shared traversals
and the policy mechanism. Nothing in a user story may start before the change it consumes lands.

- [X] T006 Create `backend/cls/FlightDeck/Capability/Policy.cls` (delta D4, research R12): an XData
  table of operation ids FlightDeck declines to offer, each with `reason` and `nativePath`; merge it
  into `FlightDeck.Capability.Map` entries as `available:false` with that reason, before privileges
  are evaluated. Add `backend/test/FlightDeck/Test/CapabilityPolicy.cls`: a policy entry makes the
  operation unavailable in the map, in `Client.Has`, and for the mutation service, with no version
  check anywhere.
- [X] T007 Add mutation `kind: "action"` to the descriptor mechanism (delta D1): accept `params` and
  `options` in `backend/cls/FlightDeck/Mutation/Descriptors.cls` validation
  (`FlightDeck.Domain.Descriptor`), and create `backend/cls/FlightDeck/Mutation/Action.cls` that
  builds the preview rows from the descriptor's `readOperation` (before and after the action) or, when
  none exists, the request block; apply through the official operation with its path and query
  parameters.
- [X] T008 Wire the action kind into `backend/cls/FlightDeck/Mutation/Service.cls` (`Context`,
  `Preview`, `DoApply`) so grade, self-protection, impact, masking and trail behave as for the other
  kinds, and extend `backend/test/FlightDeck/Test/MutationService.cls` with an action case.
- [X] T009 [P] Render the action kind in `frontend/src/mutation/DryRun.tsx` (delta D1): before/after
  rows reuse the existing diff table; a parameters-only action reuses the request block. No new test
  id.
- [X] T010 Extend link providers with declared parameters (delta D2, contract
  `LinksResponseWithParameters`): `backend/cls/FlightDeck/API/Entities.cls` accepts `provider` and
  arbitrary provider parameters, and `backend/cls/FlightDeck/Domain/LinkProviders.cls` lets a provider
  declare `parameters` and answer `needs-parameter`.
- [X] T011 [P] Render parameterised panels in `frontend/src/pattern/LinksPanel.tsx` (delta D2): one
  control per declared parameter, values when the session may list them and a typed value when it may
  not, refresh of a single group, test id `links-group-<provider>-parameter-<name>`.
- [X] T012 [P] Add singleton sections to `frontend/src/pattern/` (delta D3): an entity type with a
  detail operation and no list renders inspector and actions without a list half, test id
  `singleton-inspector`.
- [X] T013 Add `checkMode`, `checkResult` and `checkUnread` to the trail record (delta D5): written by
  `backend/cls/FlightDeck/Mutation/Service.cls`, typed in `frontend/src/api/types.ts`, rendered by
  `frontend/src/mutation/TrailPanel.tsx` (mode in the collapsed row, unread list in the detail, test
  id `trail-entry-check-mode`), and carried unchanged into the export.
- [X] T014 [P] Add the validity marker vocabulary to `backend/cls/FlightDeck/Domain/EntityTypes.cls`
  and `frontend/src/domains/presentation.ts` (delta D6): `expired` (warning, "Expired {n} days ago"),
  `expiring` (caution, "Expires in {n} days"), `validity-unknown` and `validity-not-read` (neutral),
  distinguishable without color alone.
- [X] T015 Create `backend/cls/FlightDeck/Domain/Links/RoleGraph.cls`: forward traversal of
  `GrantedRoles` from a set of roles, with a cycle guard, a depth cap and a role cap, returning each
  role with the path that reached it and a `truncated` flag naming what was not expanded (probe P2
  confirmed `GrantedRoles` is one level deep). Unit test with the three-level chain from T004.
- [X] T016 Create `backend/cls/FlightDeck/Domain/Links/RoleHolders.cls`: inverse traversal, because
  `GET /v2/security/role/owners` answers with **direct** owners and an owner may itself be a role
  (probe finding B). Walk owners of owners with the same cycle guard and cap as T015, returning users
  with the chain that reaches them, plus `truncated`. Unit test proves the user three levels below is
  found and that a cycle terminates.
- [X] T017 [P] Create `backend/cls/FlightDeck/Security/Validity.cls`: per-alias certificate reads
  (`GET /v2/security/x509-credential/certificate`) with a declared cap and a short cache, because the
  credentials listing carries no validity (probe P3). Beyond the cap or on refusal it returns
  `not-read` with the reason instead of fanning out.

**Checkpoint**: the pattern can express everything the four stories need.

---

## Phase 3: User Story 1 - Follow the whole chain between a user and a resource (Priority: P1)

**Goal**: the permissions domain, read-only, with effective privileges and provenance.

**Independent Test**: on the demo instance, open the user holding the three-level chain and confirm
each privilege appears with every granting chain; walk resource → roles → users and back.

- [X] T018 [P] [US1] Declare the entity types `permissions/user`, `permissions/role`,
  `permissions/resource`, `permissions/service` and `permissions/privileged-routine` in
  `backend/cls/FlightDeck/Domain/EntityTypes.cls` per data-model §1, with keys, schemas, sections and
  markers; the existing read-only `permissions/role` and `permissions/user` entries from feature 002
  are replaced by these.
- [X] T019 [P] [US1] Add the facts of data-model §2 to `backend/cls/FlightDeck/Domain/Facts.cls`:
  `enabled`, `expired` (compare `ExpirationDate`; the API normalises "no limit" to an empty string and
  an expired account is still `Enabled: true`, probe P1), `externalAuthentication` (from
  `AutheEnabled`) and `isSystem`.
- [X] T020 [US1] Create `backend/cls/FlightDeck/Domain/Links/UserRoles.cls`: direct roles, escalation
  roles and each one's inherited chain through T015, marking the external-authentication note of spec
  FR-004 when the account's methods include delegated or LDAP.
- [X] T021 [US1] Create `backend/cls/FlightDeck/Domain/Links/EffectivePrivileges.cls` (spec FR-003,
  research R1): one row per resource and permission with **every** chain that grants it, never a
  result without its origin; `truncated` states what could not be expanded. Emit nothing for a
  privilege whose chain is unknown.
- [X] T022 [P] [US1] Create `backend/cls/FlightDeck/Domain/Links/RoleResources.cls` (role → resources
  with permissions) and extend `backend/cls/FlightDeck/Domain/LinkProviders.cls` with the new
  providers.
- [X] T023 [US1] Create `backend/cls/FlightDeck/Domain/Links/ResourceObjects.cls` (spec FR-005,
  research R8): the web applications, wallet collections, privileged routines, databases and services
  a resource protects, each source capability-gated so a refusal narrows the answer with its reason
  instead of failing the panel.
- [X] T024 [US1] Create `backend/cls/FlightDeck/Domain/Links/SqlPrivileges.cls` as a parameterised
  provider (T010): `namespace` declared as a required parameter with values from `GET /v2/namespaces`
  when the session may list them; rows are the official listing's own fields, and provenance is its
  `GrantedVia` and `GrantedBy` — no local traversal (probe P4, spec FR-006b).
- [X] T025 [P] [US1] Backend tests: `backend/test/FlightDeck/Test/EffectivePrivileges.cls` (chain
  through the three-level fixture, direct plus inherited origins both listed, truncation reported),
  `backend/test/FlightDeck/Test/ResourceObjects.cls` and
  `backend/test/FlightDeck/Test/SqlPrivilegesProvider.cls` (parameter declaration and `GrantedVia`
  passed through unchanged).
- [X] T026 [P] [US1] Add the permissions presentations (field sections and labels) to
  `frontend/src/domains/presentation.ts` for user, role, resource, service and privileged routine.
- [X] T027 [US1] Create `frontend/src/domains/permissions/Users.tsx` and `Roles.tsx` from the pattern
  modules (list, filters in the address, inspector, links panel), registered in
  `frontend/src/domains/registry.tsx`.
- [X] T028 [P] [US1] Create `frontend/src/domains/permissions/Resources.tsx`, `Services.tsx` and
  `PrivilegedRoutines.tsx` the same way.
- [X] T029 [US1] Effective privileges panel: one row per privilege with its chains, the truncation
  note, and no privilege without an origin.
  _Note: no new component was needed. The provider answers as a link group, so the shared
  `LinksPanel` renders it; the only pattern change was showing a group's reason even when the group
  answered (an account whose roles may also come from LDAP)._
- [X] T030 [US1] SQL privileges panel on the parameterised link group (T011), showing `GrantedVia` as
  the provenance. _Note: rendered by the shared `LinksPanel` as well; the namespace list puts the
  instance's current namespace first and drops the `%ALL` wildcard, which the official listing
  refuses._
- [X] T031 [US1] Add the palette action "SQL privileges" (spec FR-006a) in
  `backend/cls/FlightDeck/Palette/Search.cls` and `frontend/src/palette/actions.ts`: choosing a user or
  role opens its inspector with the SQL panel already open.
- [X] T032 [US1] Create `frontend/e2e/permissions.spec.ts` for US1 scenarios 1 to 7 (PRD UC05-1
  verbatim, provenance for direct and inherited grants, the external-origin note, a system entity
  read-only with its reason, links in one click, SQL privileges in the chain, the palette action).

**Checkpoint**: the chain is navigable and nothing can be changed yet.

---

## Phase 4: User Story 2 - Change a permission only after seeing who loses access (Priority: P1)

**Goal**: permissions mutations with impact, the last-administrator predicate and the own-session rule.

**Independent Test**: propose removing a role that grants a resource, read the affected users and
objects, cancel; then attempt the change that would leave no administrator and see the block.

- [X] T033 [US2] Declare the permissions mutations in
  `backend/cls/FlightDeck/Mutation/Descriptors.cls` per data-model §5.2: `PUT`/`DELETE
  /v2/security/user`, `POST /v2/security/user` (create, with `Password` secret), `PUT`/`DELETE
  /v2/security/role`, `PUT`/`DELETE /v2/security/resource`, `PUT /v2/security/service`,
  `PUT`/`DELETE /v2/security/privileged-routine`, with grades: simple, reinforced when the change
  removes a role or a permission, reinforced on delete, maximum on a system entity.
- [X] T034 [US2] _(the six SQL actions were declared with T007/T008, as the subject that proved the
  action kind against real official operations.)_ Declare the action-kind mutations `POST /v2/security/user/password` (secret field
  `NewPassword`), `POST /v2/security/sql-privilege/grant` and `/revoke`, `POST
  /v2/security/sql-admin-privilege/grant` and `/revoke`, `POST /v2/security/sql-column-privilege/grant`
  and `/revoke`, with the path parameters the official specification declares (`namespace`, `grantee`,
  `type`, `object`, `action`, `privilege`, `column`) and the options `withGrant`, `cascade`,
  `asGrantor`; grant simple, revoke reinforced.
- [X] T035 [US2] Create `backend/cls/FlightDeck/Mutation/LastAdmin.cls` (spec FR-010 to FR-010-2):
  count enabled, unexpired users who hold `%Admin_Secure:USE` (roles found through T015, holders
  through T016) **or** have `%All` among their `Roles`, read as a literal name; apply the proposed
  change in memory; block only when the set was non-empty before and is empty after; return `complete`
  or `partial` with the list of what could not be read.
- [X] T036 [US2] Create `backend/test/FlightDeck/Test/LastAdmin.cls`. The predicate fails by
  permitting, not by refusing, so the **positive case is the one that proves self-protection exists**
  and it runs against the real instance, not against a staged data structure:
  - **the legitimate block, end to end**: narrow the instance to a single counted administrator
    (record the other administrators' roles, remove them, and restore them afterwards, whatever the
    outcome), then propose the change that would remove the last one and assert the server refuses
    it, with its reason, and that the instance is unchanged;
  - the negative cases the probes made concrete: a `%All`-only instance is not blocked (probe
    finding A, spec SC-005b); an expired account does not count although the API reports
    `Enabled: true` (probe P1, scenario 5d); an empty baseline reports partial instead of blocking
    (scenario 5c); a refused read produces `partial` with the unread list.
- [X] T037 [US2] Wire the predicate into `backend/cls/FlightDeck/Mutation/SelfProtection.cls` and the
  descriptors of T033 and T034 for the operations of data-model §5.3, with the message of spec
  FR-010b-1 stating what was counted (`%Admin_Secure:USE` holders and `%All` members) and that
  delegated access and LDAP were not.
- [X] T038 [US2] Add the own-session rule (spec FR-011): a change affecting the signed-in user is
  graded reinforced with the immediate-effect warning, decided on the server from the session's user
  name against the mutation's target.
- [X] T039 [P] [US2] Create the impact providers `backend/cls/FlightDeck/Domain/Impact/RoleImpact.cls`,
  `ResourceImpact.cls` and `SqlPrivilegeImpact.cls` (research R7): users who lose access (through
  T016) and objects that become inaccessible (through T023), each answering `ok`, `none` or
  `undetermined` with the reason, never an empty list for a refused read.
- [X] T040 [P] [US2] Backend tests `backend/test/FlightDeck/Test/PermissionsImpact.cls`: determined,
  none and undetermined for each provider, and the masking of a password in a preview, trail and error
  text.
- [X] T041 [US2] Create the permissions forms in `frontend/src/domains/permissions/`: `UserForm.tsx`
  (create with password through `SecretEditor`, edit without it), `RoleForm.tsx` (granted roles and
  resources), `ResourceForm.tsx` (stating the `PublicPermission` constraint the official API enforces,
  probe re-confirmed), `ServiceForm.tsx` and `PrivilegedRoutineForm.tsx`, each submitting through
  `useDomainMutation`.
- [X] T042 [US2] Add the action controls to the permissions screens: change password, and grant and
  revoke inside the SQL panel, all through `useDomainMutation().run({ operationId, params, options })`.
- [X] T043 [US2] Extend `scripts/dev/check-mutation-enforcement.sh` with the new mutating routes:
  armed apply refused, the last-administrator block refused server-side by a direct request, and IRIS
  state unchanged afterwards.
- [X] T044 [US2] Create `frontend/e2e/permissions-mutations.spec.ts` for US2 scenarios 1 to 6: impact
  before a removal, the block with its reason, the own-session reinforced confirmation, undetermined
  impact never rendered as empty, a direct request refused, and a secret shown only as changed or
  unchanged.
- [X] T045 [US2] Create `frontend/e2e/last-admin.spec.ts`: complete mode blocks and records the
  attempt; the trail entry carries `checkMode` and `checkResult`; on the default install, where the
  administrators hold `%All`, an ordinary role change is **not** blocked (spec SC-005b).
- [X] T046 [US2] Run the US1 and US2 suites plus the feature 001 and 002 suites; fix until green.

**Checkpoint**: the permissions domain is complete and safe.

---

## Phase 5: User Story 3 - Administer security and secrets without ever seeing a secret (Priority: P2)

**Goal**: the security domain, its sections, its secrets and its actions.

**Independent Test**: create a wallet collection and a secret, reopen the secret and confirm no value
and only replace and delete; run a TLS connection test and read the platform's verbatim result.

- [X] T047 [P] [US3] Declare the security entity types of data-model §1 in
  `backend/cls/FlightDeck/Domain/EntityTypes.cls`: TLS configurations, X.509 credentials, the three
  OAuth 2.0 families, wallet collections and secrets, LDAP configurations, MFT connections and
  superservers, with keys, schemas, sections and markers.
- [X] T048 [P] [US3] Declare the singleton types: audit settings, encryption settings, web
  authentication and the OAuth 2.0 authorization server (detail operation only, rendered by T012).
- [X] T049 [US3] Declare every security mutation in `backend/cls/FlightDeck/Mutation/Descriptors.cls`
  with its secret fields: TLS (`PrivateKeyPassword`), X.509 create (`PrivateKeyPassword`), wallet
  secret (`WalletSecretConfig`, `writeOnly` in the official schema), OAuth client and server secrets
  (`ClientSecret`, `ClientPassword`, `ServerPassword`, `InitialAccessToken`), LDAP search password,
  web authentication SMTP password (the official field is spelled `SMPTPPassword`; send what the API
  declares and record the defect), and MFT token deletion.
- [X] T050 [US3] Complete the secret gate and turn it back on:
  - fill `scripts/build/secret-exemptions.json` so every candidate field is either
    declared in a descriptor's `secretFields` or exempted with a reason;
  - **re-add `python3 scripts/build/check-secrets.py` to `scripts/build/check-generated.sh`**, which
    T003 deliberately left out while the descriptors did not exist yet. The exclusion is temporary
    only if this line is a task: a temporary exclusion outlives its reason when it lives in memory;
  - probe it: remove one declaration, confirm the build fails naming the field, restore it;
  - add `backend/test/FlightDeck/Test/SecurityMasking.cls`: no secret value in any read, preview,
    trail, error text or apply result.
- [X] T051 [US3] Add the wallet providers and facts: `secretCount` from `GET /v2/wallet/secrets`, the
  reinforced delete message stating it (spec FR-017), and
  `backend/cls/FlightDeck/Domain/Links/WalletUsers.cls` (collection → resource → roles → users, spec
  FR-016) built on T016.
- [X] T052 [US3] Declare the TLS connection test as an action (`POST
  /v2/security/ssl-configuration/test`, body `Host` and `Port`) and render the platform's own result,
  success or failure, without reinterpretation, leaving the configuration unchanged (spec FR-018).
- [X] T053 [US3] Declare the audit writes (spec FR-021, FR-021a): `PUT /v2/security/audit/enabled`
  (reinforced when disabling), `POST /v2/security/audit/event/clear-count`, `POST
  /v2/security/audit/record/copy` (reinforced, target names the destination namespace; maximum when
  `DeleteAfterCopy` is true) and `POST /v2/security/audit/record/purge` (maximum, consequence stated).
  Reading audit records stays out of this feature.
- [X] T054 [US3] _(written with T006; its entries are the encryption writes.)_ Fill `backend/cls/FlightDeck/Capability/Policy.cls` with the encryption writes of
  spec FR-020: create key file, add and remove key file administrator, add key, activate key,
  deactivate key and change encryption settings, each with the reason of FR-020a and the native path
  "System Administration > Encryption".
- [X] T055 [P] [US3] Add the security presentations to `frontend/src/domains/presentation.ts` and the
  section list to `frontend/src/shell/domains.ts`.
- [X] T056 [US3] Create `frontend/src/domains/security/TlsConfigurations.tsx` and
  `X509Credentials.tsx`, including the connection test control and its verbatim result panel.
- [X] T057 [P] [US3] Create `frontend/src/domains/security/Wallet.tsx`: collections list, secrets
  panel showing names and types only, create and replace forms using `SecretEditor`, delete stating
  the secret count.
- [X] T058 [P] [US3] Create `frontend/src/domains/security/OAuth2.tsx` covering the three families
  with their parameterised listing (`serverId` for client configurations, research R4).
- [X] T059 [P] [US3] Create `frontend/src/domains/security/Ldap.tsx`, `Mft.tsx` and
  `Superservers.tsx`, working around the LDAP listing defect recorded in `verification/README.md` by
  showing the official message and keeping the section usable.
- [X] T060 [P] [US3] Create the singleton sections `frontend/src/domains/security/AuditSettings.tsx`,
  `WebAuthentication.tsx`, `OAuth2Server.tsx` and `Encryption.tsx`, the last read-only with every
  write disabled and its policy reason visible.
- [X] T061 [US3] Register the security sections in `frontend/src/domains/registry.tsx` and the palette
  entries for the new entity types in `backend/cls/FlightDeck/Palette/Search.cls`.
- [X] T062 [US3] Create `frontend/e2e/security.spec.ts` for US3 scenarios 2, 3, 4 and 7 (a section
  disabled with its reason, wallet users in one click, the TLS test failure shown verbatim, encryption
  read-only with the native path).
- [X] T063 [US3] Create `frontend/e2e/secrets.spec.ts` for US3 scenarios 1, 5, 6 and 8: a stored
  secret offers only replace and delete, the wallet collection delete states the secret count, no
  secret appears in any layer, and the audit purge requires the maximum confirmation while copy
  requires the reinforced one naming the destination.
- [X] T064 [US3] Create the partial-mode end-to-end test in `frontend/e2e/security.spec.ts` using the
  wallet-only administrator of T005: deleting a collection whose resource's users they cannot read
  produces an incomplete check naming what was unread, the reinforced confirmation, no block, and a
  trail record carrying `checkMode: partial` (probe P5 — this test cannot live in the permissions
  domain, where reads and writes share one privilege).
- [X] T065 [US3] Run the US3 suites plus everything before them; fix until green.

**Checkpoint**: all 119 owned operations are implemented or declared unavailable with a reason.

---

## Phase 6: User Story 4 - Know what expires before it expires (Priority: P3)

**Goal**: days remaining, bands, and the home panel's attention list.

**Independent Test**: with a credential expiring inside the alert window, confirm the band in the
list and the same item on the home panel.

- [X] T066 [US4] Add the validity facts to `backend/cls/FlightDeck/Domain/Facts.cls` on top of T017:
  `daysRemaining`, `validityBand` (`valid`, `expiring`, `expired`, `unknown`, `not-read`), with the
  cap and cache stated in the response (spec FR-022a).
- [X] T067 [US4] _(done early: the merged contract declared `/attention`, and a served document must
  not name a route that does not exist.)_ Create `backend/cls/FlightDeck/API/Attention.cls` and its route
  (`GET /v1/attention`, contract `AttentionResponse`): expiring and expired items the session may
  read, with `degraded` and a reason when a source was refused or capped.
- [X] T068 [P] [US4] Mark TLS configurations `validity-unknown` (the official API reports no validity
  for the certificate file, probe P3) so they are never counted as valid, and record the gap in
  `docs/api-coverage.md`.
- [X] T069 [US4] Render the attention items in `frontend/src/home/Home.tsx`, replacing the empty
  state from feature 001, each item opening its entity in one click.
- [X] T070 [P] [US4] Backend test `backend/test/FlightDeck/Test/Validity.cls`: bands at the window
  boundaries, `not-read` beyond the cap, `unknown` when the platform reports nothing, and the
  attention endpoint's degraded answer.
- [X] T071 [US4] Create `frontend/e2e/attention.spec.ts` for US4 scenarios 1 to 3, using a credential
  generated with a short validity in the e2e setup.

**Checkpoint**: an administrator who never opens the security domain still learns what is about to
break.

---

## Phase 7: Polish & cross-cutting concerns

- [X] T072 [P] Update `docs/api-coverage.md` with the ownership table of spec FR-021c to FR-021f: the
  88 operations this feature owns, the audit record listing owned by the logs feature, and the
  encryption writes declared unavailable with their reason.
- [X] T073 [P] Fold `contracts/ui-pattern-delta.md` into
  `specs/002-webapps-explorer-mutations/contracts/ui-pattern.md` (the pattern's binding contract) and
  update `frontend/src/pattern/README.md` with the action kind, parameterised panels and singleton
  sections.
- [X] T074 [P] Update `README.md`: what the permissions chain shows and does not (delegation and LDAP
  are not enumerated), that secrets are never displayed, and that the last-administrator check counts
  `%Admin_Secure:USE` holders and `%All` members and declares itself incomplete otherwise.
- [X] T075 Extend the pattern catalog fixture
  (`backend/cls/FlightDeck/Fixture/PatternCatalog.cls`, `frontend/src/fixtures/PatternCatalog.tsx`,
  `frontend/e2e/pattern.spec.ts`) with an action-kind mutation and a parameterised panel, so the two
  new pattern capabilities are proven where no domain data can hide a gap.
- [X] T076 [P] Extend the credential audit (`frontend/e2e/audit.spec.ts`) to a session that writes a
  wallet secret, an OAuth client secret and a user password: 0 findings in the export, storage,
  cookies and the IRIS logs.
- [X] T077 [P] Design review of both domains in both themes against `docs/design.md` §4, §6 and §7,
  with axe on every new section, the singleton sections, the panels and the attention list; record it
  in `specs/003-permissions-security/checklists/design-review.md`.
- [X] T078 Limited-mode matrix on IRIS 2026.1: extend `frontend/e2e/limited.spec.ts` with one
  permissions read, one security read and one write, deciding availability through the capability map
  only; run the whole backend suite there (the script fails if a class does not run).
- [X] T079 Full matrix on fresh installs — IRIS CE 2026.2, IRIS for Health 2026.2 and IRIS CE 2026.1 —
  with the backend suite, every Playwright project, `scripts/dev/check-mutation-enforcement.sh` and
  every static gate; record it in `verification/feature-003-signoff.md`.
- [X] T080 Run `specs/003-permissions-security/quickstart.md` §1 to §11 end to end and fix any step
  that does not work as written.

---

## Dependencies & Execution Order

- **Phase 1 (T001–T005)** blocks everything: schemas, the merged contract, the secret gate, fixtures
  and the test users.
- **Phase 2 (T006–T017)** blocks every story. Within it: T006, T007→T008→T009, T010→T011, T012, T013,
  T014, T015→T016, T017 are independent tracks except where arrows show.
- **US1 (T018–T032)** depends on T015 and T010; it is the MVP.
- **US2 (T033–T046)** depends on US1's entity types and on T007, T008, T013, T016.
- **US3 (T047–T065)** depends on Phase 2 only; it can run in parallel with US2 once T007 and T012
  exist, on different files.
- **US4 (T066–T071)** depends on T017 and on US3's X.509 section.
- **Polish (T072–T080)** depends on all stories.

## Parallel opportunities

- T003, T004 and T005 in Phase 1.
- In Phase 2: T009, T011, T012, T014 and T017 touch different files.
- In US1: T018, T019, T022, T025, T026 and T028.
- In US3: T055, T057, T058, T059 and T060.
- Polish: T072, T073, T074, T076 and T077.

## Implementation strategy

1. **MVP**: Phase 1, Phase 2 and US1 — the chain with provenance, read-only. It is demonstrable and
   carries the feature's main argument.
2. **Second increment**: US2, which makes the domain safe to change, including the predicate the
   probes reshaped.
3. **Third**: US3, the largest surface but the most repetitive, once the pattern changes exist.
4. **Fourth**: US4, small and dependent on US3's reads.
5. **Then** polish, the matrix and the sign-off, in the shape feature 002 used.
