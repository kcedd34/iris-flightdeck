# Feature Specification: Web Applications, REST API Explorer and the Shared Mutation Layer

**Feature Branch**: `002-webapps-explorer-mutations`

**Created**: 2026-09-17

**Status**: Draft

**Input**: User description: "Web applications and REST API explorer, plus the shared mutation
layer. Scope: UC03 (web applications), UC04 (REST API explorer) and UC10 (safe mutation with
dry-run, graded confirmation and session trail) from docs/prd.md Section 7. Use their Gherkin
acceptance criteria verbatim as the definition of done. This feature carries UC10 on purpose. It
establishes the reusable domain screen pattern that the remaining four domains apply: list,
inspector, entity links panel, action bar, and one shared dry-run component. No later feature may
write its own confirmation dialog. Treat the pattern as the primary deliverable here, on par with
the two domains themselves. Official API coverage: all 8 operations under /v2/web-app,
/v2/web-apps and /v2/web-app/pct-access*, per docs/api-coverage.md. Every listed operation is
implemented or explicitly degraded with a reason. UC04 is NOT covered by the SysAdmin API and stays
on /api/mgmnt/ and %REST.API. Constraints that carry over from feature 001: Principle I as amended
in constitution 2.0.0: use the official endpoint where one exists. The REST test executor derives
its target from the current instance, never from the client. It is not an outbound proxy, and the
README says so. FlightDeck's own API must appear in its own explorer with its OpenAPI spec (FR-012
/ RF12). Mutations are blocked server-side under safe mode, as already enforced by the Router
guards. Do not rely on the UI alone. Reuse the existing capability map derived from the spec. Do
not hand-code privileges. frontend/dist is versioned: any frontend change requires a rebuild and
check-dist.sh must pass. Apply docs/design.md and docs/prototype.html. Tokens only, no literal hex,
both themes verified, section tabs only where a domain has more than one entity type. Platform
findings from verification/README.md are known defects of the official API, not ours. Work around
them and keep them documented; do not silently mask them. Out of scope: permissions, security,
tasks, system and logs. Their routes keep rendering the empty state from feature 001."

**Governing documents**: `.specify/memory/constitution.md` v2.1.0 (principles I–XI, including the
dialect scope notes of Principles I and III); `docs/prd.md` §7 (UC03, UC04, UC10), §8 (RN-FD-03,
-04, -07, -08, -09, -11, -12, -13, -27, -31, -32, -34), §9 (messages 2, 3, 4, 8, 17, 18);
`docs/api-coverage.md` domain 1; `docs/design.md` §3, §4, §4.1, §6, §7, §8; `docs/prototype.html`
(prevails over design text for the components it implements, as in feature 001);
`verification/README.md` (known platform defects).

**Carried over from feature 001** (binding, not restated as new work):
- the shell (glareshield, rail, section tabs, list plus inspector, palette), the capability map
  derived from the official specification, per-tab safe mode enforced server-side, and the §9
  message catalog;
- the dialect boundary: no domain, screen or test code asks which API version the instance
  speaks; whether an operation exists comes only from the capability map (`available`), enforced by
  the `check:dialect` build gate;
- the versioned production bundle: every frontend change is rebuilt and the bundle check passes.

## Clarifications

### Session 2026-09-17

- Q: Constitution V requires a field-by-field diff before every mutation, but a mutating REST test
  request (POST, PUT, PATCH, DELETE) has no current state to compare. How does it pass through the
  shared mutation layer? → A: Through the same shared confirmation view, in **request mode**: it
  shows the exact method, path, parameters, headers and body that will be sent, with no current
  state column. Grade is simple, except DELETE, which is reinforced (type the path). The request is
  recorded in the trail. This is the only case in which the view shows no current state, and the
  reason is stated in the view.
- Q: Does the session trail survive a reload of the same tab? → A: Yes. It is kept in the tab's
  session storage (`sessionStorage`), never `localStorage`: it dies when the tab closes, which keeps
  the per-tab scope of FR-014. It is cleared explicitly at sign-out and when session expiry is
  detected. No leave-page warning (with a persisted trail it has no purpose). Secret masking
  happens in the mutation layer before anything is written to the trail; the trail never decides
  it. **Rationale**: safe mode is not persisted because persisting it would grant permission
  without a deliberate act. The trail records what already happened and grants nothing, so the
  symmetry argument does not apply.

## User Scenarios & Testing *(mandatory)*

> Acceptance scenarios marked **(PRD)** are the Gherkin criteria of `docs/prd.md` §7, translated to
> English (Constitution XI) with their meaning unchanged. They are the definition of done. The
> other scenarios make the requirements below testable and do not relax any PRD scenario.

### User Story 1 - See what is exposed and under which protection (Priority: P1)

An administrator opens the web applications domain and, in one reading of the list, sees which
applications are enabled, which are reachable without authentication, and which are REST services.
Selecting an application opens its detail in the inspector beside the list, with its links: the
resource that protects it, the roles that grant that resource, the users who hold those roles, and,
for a REST service, its specification in the explorer. Percent class access configurations are a
second entity type in the same domain.

**Why this priority**: exposure without authentication is the configuration that causes the most
real incidents (PRD UC03). Reading safely comes before changing, and this story also delivers the
list, inspector and entity links panel of the reusable domain pattern.

**Independent Test**: on the demo install, open the domain with safe mode armed, find the
applications flagged as unauthenticated (for example `/api/monitor` on the default image), open
`/csp/fd-demo`, and reach the roles granting its resource in one click, without any request that
changes state.

**Acceptance Scenarios**:

1. **(PRD UC03-1)** **Given** a web application is accessible without authentication, **When** the
   list is displayed, **Then** that application receives a visual attention highlight.
1a. **Given** an unauthenticated application exposes a REST API and another serves only static
   files, **When** the list is displayed, **Then** both are highlighted, the API with the stronger
   "Open API" marker and the static application with "static files only", without opening either;
   **And** FlightDeck's own `/api/flightdeck`, which requires authentication, carries no marker.
2. **(PRD UC03-2)** **Given** the user opens an application protected by a resource, **When** the
   detail is displayed, **Then** the roles that grant that resource are reachable in one click.
3. **Given** the list is displayed, **When** the user filters by namespace, enabled state, type
   (REST or not) or "no authentication", **Then** only matching applications remain, and the filter
   is reflected in the address so the view can be shared.
4. **Given** an application the API marks as a system application, **When** it is listed or
   inspected, **Then** its nature is signaled, and its destructive operations are restricted
   (FR-020).
5. **Given** the user lacks the privilege an operation declares, **When** the list, inspector or
   action bar renders, **Then** the control is visible, disabled, and states the required
   permission and resource (§9 message 2).
6. **Given** a linked entity belongs to a domain not yet delivered (roles, users), **When** the user
   follows the link, **Then** the linked entity's detail opens in the inspector, replacing the
   current one, and the list stays visible; the out-of-scope domain routes still render their empty
   state.

---

### User Story 2 - Change anything only after seeing exactly what will change (Priority: P1)

An administrator disarms safe mode in the tab and edits a web application, creates or deletes one,
or changes a percent class access configuration. Before anything is sent, the one shared dry-run
view shows every field as current against commanded, any impact on third parties, and asks for the
confirmation grade the operation requires. After applying, the action is recorded in the tab's
session trail, which can be exported as JSON at any moment. If the object changed on the server
while the user was editing, nothing is overwritten: the differences are recomputed and a new
confirmation is required. FlightDeck refuses to disable or break the web applications that serve
FlightDeck itself.

**Why this priority**: confidence is one of the three problems the product exists to solve, and
the shared component is what every later domain reuses (UC10, Constitution V). It is built once,
here, with web applications as its first real consumer.

**Independent Test**: with the demo install, disarm safe mode, change the description of
`/csp/fd-demo`, verify the dry-run and the trail entry; change the same application through the
official API from outside while the dry-run is open and verify the recomputation; attempt to
disable `/flightdeck` and verify the explained block, including when the request is sent directly
to FlightDeck's API without the UI.

**Acceptance Scenarios**:

1. **(PRD UC03-3)** **Given** the user edits an application with safe mode disarmed, **When** they
   confirm the edit, **Then** the differences are displayed before applying, **And** the action is
   recorded in the trail after applying.
2. **(PRD UC03-4)** **Given** the user tries to disable the application that serves the portal,
   **When** they confirm the action, **Then** the system blocks the operation and explains the
   reason.
3. **(PRD UC10-1)** **Given** the user requests a mutation, **When** the confirmation is displayed,
   **Then** the differences between current and proposed state appear field by field.
4. **(PRD UC10-2)** **Given** the operation is destructive, **When** the confirmation is displayed,
   **Then** typing the name or identifier of the target is required.
5. **(PRD UC10-3)** **Given** the state changed on the server since it was read, **When** the user
   tries to confirm, **Then** the system reloads and recomputes the differences before applying.
6. **(PRD UC10-4)** **Given** the user applied mutations in the session, **When** they request the
   trail export, **Then** they receive JSON with the time, target, differences and result of each
   action.
7. **Given** safe mode is armed, **When** the user opens an edit, **Then** fields are read-only and
   disarming is offered (UC03 A1); **And** a mutation sent directly to FlightDeck's API while armed
   is refused by the server with §9 message 3.
8. **Given** the official API rejects a mutation, **When** the result returns, **Then** the IRIS
   message is shown verbatim, the form keeps the user's input, and the failed attempt is recorded
   in the trail (UC03 A2, UC10 A2).
9. **Given** the proposed state equals the current state, **When** the user asks to apply, **Then**
   no request is sent and §9 message 18 is shown (UC10 A3).
10. **Given** a mutation that would disable, delete or make unreachable a FlightDeck web
    application, **When** it reaches FlightDeck's server by any path (UI, palette or a direct
    request), **Then** it is refused with §9 message 4 and recorded in the trail as blocked.

---

### User Story 3 - Discover, read and test the instance's REST APIs (Priority: P2)

A developer opens the REST APIs section, sees every REST service of the instance by namespace,
including services defined by a specification and services coded by hand, with the ones lacking a
specification flagged. FlightDeck's own API is among them, with its specification. Selecting a
service renders its specification grouped by path and method with schemas. The developer fills in
parameters and a body, runs a test request against this same instance under their own identity,
and reads the status, time, headers and formatted body, and can copy the equivalent `curl` command.

**Why this priority**: it is the second domain of the contest axis and the self-documentation
requirement (RF04, RF12), but it depends on the pattern and safe-mode behavior of stories 1 and 2
rather than the other way around.

**Independent Test**: on the demo install, open REST APIs, find `/api/flightdeck` with its
specification and `/api/monitor` flagged as having no specification, run `GET` on a FlightDeck
operation and copy it as `curl`; with safe mode armed, try a `DELETE` and verify it is refused by
the server, not only disabled in the UI.

**Acceptance Scenarios**:

1. **(PRD UC04-1)** **Given** the instance has REST services with and without a specification,
   **When** the list is displayed, **Then** both appear, **And** those without a specification are
   flagged.
2. **(PRD UC04-2)** **Given** the user runs a test request, **When** the response returns, **Then**
   status, time, headers and formatted body are displayed, **And** the equivalent request can be
   copied as `curl`.
3. **(PRD UC04-3)** **Given** safe mode is armed, **When** the user tries to run POST, PUT, PATCH or
   DELETE, **Then** execution is blocked and disarming is offered.
4. **(PRD UC04-4)** **Given** FlightDeck is installed, **When** the user lists the discovered
   services, **Then** FlightDeck's own API appears with its specification.
5. **Given** a test request, **When** it is prepared, **Then** the user can choose only the method,
   the path within a discovered service or the instance, parameters, headers and body; scheme, host
   and port always come from the current instance, and a request naming another host is refused
   (RN-FD-08).
6. **Given** a service without a specification, **When** it is selected, **Then** its metadata
   (web application, namespace, dispatch class, routes the platform reports) is shown and a free
   request by path is offered (UC04 A1).
7. **Given** the test request fails or returns an error status, **When** the response is shown,
   **Then** it is presented in full, without interpretation (UC04 A2).
8. **Given** a namespace with no REST service, **When** it is selected, **Then** an empty state
   explains why and points to the namespace where FlightDeck's own API lives (UC04 A4).
9. **Given** safe mode is disarmed and the user runs POST, PUT, PATCH or DELETE, **When** they ask
   to run it, **Then** the shared confirmation view opens in request mode, showing exactly what will
   be sent and stating that a test request has no current state to compare; a DELETE requires
   typing its path; after running, the request and its status are recorded in the trail (FR-039).

---

### User Story 4 - Add the next domain without a single new design or confirmation decision (Priority: P2)

A maintainer building permissions, security, tasks or system in a later feature composes the
domain from the pattern delivered here: list header with filters, row with attention markers,
inspector with the fixed label column, entity links panel, action bar gated by the capability map
and safe mode, and mutation descriptors consumed by the one shared dry-run and confirmation
component. They write no confirmation dialog, diff renderer or trail logic of their own, and an
automated check fails the build if they try.

**Why this priority**: the user made the pattern a primary deliverable on par with the two
domains. Its value is realized by the next four features, so it is proven here by two real
consumers (web applications and percent class access) plus a pattern catalog, and by the guard.

**Independent Test**: open the test-only pattern catalog (not reachable in production builds) and
exercise every pattern part and all three confirmation grades on sample entities, including a
secret field and a blocked operation; add a stray confirmation dialog to a domain module and see
the build fail.

**Acceptance Scenarios**:

1. **Given** the pattern catalog, **When** a simple, a reinforced and a maximum operation are
   requested, **Then** each shows the same dry-run view with the grade's interaction: confirm;
   type the target name; type the identifier and acknowledge the consequence.
2. **Given** a mutation descriptor marks a field as secret, **When** the dry-run and the trail show
   it, **Then** only "changed" or "unchanged" appears, never a value (Constitution VI).
3. **Given** a domain module outside the shared layer renders its own confirmation dialog or diff,
   **When** the build runs, **Then** it fails and names the file.
4. **Given** `prefers-reduced-motion`, **When** the dry-run opens, **Then** the orchestrated reveal
   is replaced by an instant state change (design §3.4, §6).

---

### Edge Cases

- **FlightDeck's own web applications.** `/flightdeck` and `/api/flightdeck` cannot be disabled,
  deleted, renamed, moved to another namespace or dispatch class, left without the authentication
  method FlightDeck relies on, or stripped of the role match that lets signed-in users run the
  portal code. Other edits to them (for example the description) are allowed with reinforced
  confirmation, because they affect every portal user. Blocks are enforced by the server.
- **Application that serves the current request path but is not FlightDeck's** (for example
  `/api/mgmnt`, which the explorer itself uses): disabling it is allowed with reinforced
  confirmation, and the impact block states that the REST explorer would stop discovering services.
- **Application with no resource**: the links panel states that access is not restricted by a
  resource, instead of an empty list, and the impact of disabling it is "every user who can reach
  the namespace".
- **Application renamed or deleted by someone else while inspected**: the inspector states that the
  object no longer exists on the server, keeps the last known values visible, and offers to return
  to the list; an open dry-run recomputes and shows the object as gone.
- **Concurrent change detected only at apply time**: the platform offers no version token or lock,
  so the check compares the state re-read immediately before sending with the state the diff was
  computed from. A change landing in the instant between that re-read and the write cannot be
  detected; this residual window is documented, not hidden.
- **Percent class access key**: a configuration is identified by application, allow type and class
  or package. Changing any of the three is a delete plus a create, shown as such in the dry-run
  with the delete's confirmation grade.
- **List larger than one screen**: filters and search apply to the whole list, not only to the
  loaded rows; the list states how many applications match.
- **Official API defects**: known platform defects recorded in `verification/README.md` that affect
  these operations are worked around where possible and always surfaced with the original IRIS
  text; new ones found during this feature are added to that file. None is masked by generic text.
- **Operations the instance does not offer**: an operation with `available: false` in the
  capability map is shown disabled with its reason, like a missing privilege; no screen asks for
  the version.
- **REST service whose web application is disabled**: listed with its state; a test request is
  allowed and returns what the instance answers, in full.
- **Test request to a service that requires a different authentication method** than the signed-in
  session (for example an unauthenticated application, or one using delegated authentication): the
  request still runs as the signed-in user, never with a credential FlightDeck would have to hold;
  if the service cannot be reached that way, the response or the refusal is shown verbatim.
- **Large or binary test responses**: the body is shown formatted up to a size limit, with the size
  stated and the rest available to copy; binary content is summarized, not rendered.
- **Test request that would call FlightDeck's own mutation endpoints**: it goes through the same
  server-side safe-mode and self-protection checks as any other path.
- **Session expiry during a dry-run**: when expiry is detected, the trail is cleared (FR-014).
  Re-authentication happens in the overlay from feature 001, the same dry-run is restored, and the
  differences are recomputed before confirmation (RN-FD-31 shares this code path). Actions recorded
  before the expiry are not restored; exporting remains possible until expiry is detected.
- **Duplicated tab**: browsers copy a tab's session storage into its duplicate at the moment of
  duplication. The duplicate therefore starts with a snapshot of the trail and diverges from then
  on. Nothing is shared live between tabs, and the duplicate still starts in safe mode (feature
  001).
- **Session storage unavailable or full** (private browsing restrictions, quota): the trail keeps
  working in the tab's memory, states that it will not survive a reload, and never blocks a
  mutation.
- **Trail and secrets**: no trail entry, export or error message contains secret material. Masking
  is decided in the mutation layer, before any trail write; the trail stores only the already
  masked record of what the dry-run displayed and never inspects values itself.

## Requirements *(mandatory)*

### Functional Requirements

#### Reusable domain screen pattern

- **FR-001**: The feature MUST deliver one reusable domain screen pattern, used unchanged by both
  domains of this feature and by every later domain: list header (title, search, filters, create
  action), list row (identity, state markers including the attention highlight, tabular numerals),
  inspector (fixed 96 px label column, detail never navigates away), entity links panel (incoming
  and outgoing links), action bar, and mutation descriptors consumed by one shared dry-run and
  confirmation component and one session trail.
- **FR-002**: The action bar MUST derive each control's state only from the capability map (the
  declared privilege and `available`), the object's own capability fields when the API declares
  them (Constitution IX), safe mode, and self-protection. It MUST NOT hide controls; disabled
  controls state their reason (§9 messages 2, 3, 4 or 8).
- **FR-003**: A mutation descriptor MUST declare, once per official operation: the confirmation
  grade rule, the target name or identifier to type, which fields are secret, the self-protection
  rule if any, and the impact provider if any. Confirmation grade is determined by the operation and
  the proposed change, never by the domain (RN-FD-04).
- **FR-004**: An automated build check MUST fail when any module outside the shared mutation layer
  renders a confirmation dialog, a diff view or writes to the trail, and MUST name the offending
  file. The check is part of the standard build, like the token and dialect gates.
- **FR-005**: A test-only pattern catalog MUST exercise every pattern part and all three confirmation
  grades on sample entities, including a secret field, an impact block and a blocked operation. It
  MUST NOT be reachable from navigation or the palette, and MUST be absent from the production
  bundle (as the feature 001 fixture is).
- **FR-006**: Linked entities from domains not yet delivered (roles, users) MUST open read-only in
  the inspector, replacing the current entity, with a way back to the previous entity; their domain
  routes keep rendering the feature 001 empty state.

#### Shared mutation layer (UC10)

- **FR-007**: Before any mutation, the system MUST compute the proposed state and show the dry-run:
  every field as `CURRENT` against `COMMANDED`, unchanged rows muted, changed rows in the commanded
  color, with the orchestrated reveal of design §6 (instant under reduced motion).
- **FR-008**: If the proposed state equals the current state, the system MUST NOT send any request
  and MUST show §9 message 18.
- **FR-009**: The confirmation grade MUST be enforced in the same view: simple (confirm after the
  diff); reinforced (type the target name exactly); maximum (type the identifier exactly and
  acknowledge the stated consequence). `Apply` stays disabled until the grade is satisfied; the
  action word is `Apply`, the notice says `Applied`, the trail records `Applied`.
- **FR-010**: When the operation affects third parties, the impact block MUST appear below the diff
  in the same view, listing the affected users and objects or stating that they could not be
  determined and why (RN-FD-11).
- **FR-011**: Immediately before sending, the server MUST re-read the target and compare it with the
  state the diff was computed from. If they differ, it MUST NOT apply; the client MUST reload,
  recompute the diff, show §9 message 17 and require a new confirmation (RN-FD-31). The re-read,
  comparison and send MUST happen server-side, not only in the client.
- **FR-012**: Safe mode MUST be enforced by the server for every mutation this feature adds, using
  the feature 001 guard: a mutation request without the tab's disarmed state is refused with §9
  message 3. The UI shows read-only fields and offers disarming, but is not the enforcement.
- **FR-013**: When the official API rejects a mutation, the system MUST show the IRIS message
  verbatim, keep the form input, and record the failed attempt (UC10 A2).
- **FR-014**: The session trail MUST record every applied, failed and server-blocked mutation with
  time, target, displayed differences and result (`Applied`, `Failed` with the IRIS text, `Blocked`
  with the reason), and every mutating REST test request run (FR-039). It MUST be scoped to the
  browser tab, never shared across tabs, and MUST state explicitly that it does not replace IRIS
  auditing (RN-FD-27). It MUST be kept in the tab's session storage (never persistent browser
  storage), so it survives a reload of that tab and dies when the tab closes. It MUST be cleared
  explicitly at sign-out and when session expiry is detected. No leave-page warning is shown.
- **FR-015**: The user MUST be able to export the trail as JSON at any moment, containing for each
  action the time, target, differences and result, plus the not-a-substitute-for-auditing notice
  (UC10 A4).
- **FR-016**: Secret fields MUST appear in the dry-run, trail, export and error messages only as
  changed or unchanged, never with a value (Constitution VI). Masking MUST be applied by the
  mutation layer from the operation's descriptor before any record is written to the trail; the
  trail receives only masked records and never decides what is secret.
- **FR-017**: The trail and the dry-run MUST be reachable from the palette. A disarm-then-continue
  offer from feature 001 MUST lead into the same dry-run, never bypass it.

- **FR-039**: A mutating REST test request (POST, PUT, PATCH, DELETE) MUST go through the shared
  confirmation view in request mode: the exact method, path, parameters, headers and body to be
  sent, with a stated reason why no current state is compared. Grade: simple, except DELETE, which
  is reinforced (type the path). The request and its outcome are recorded in the trail, with header
  and body values masked by the same rules as FR-016 and never including credentials. This is the
  only use of the view without current state; every other mutation shows the field-by-field diff.

#### Web applications (UC03)

- **FR-018**: All 8 official operations MUST be implemented through the official SysAdmin API:
  list applications, view one, create or edit, delete; list percent class access configurations,
  view one, create or edit, delete. Any operation that cannot be offered on an instance MUST appear
  disabled with its reason from the capability map. No operation is reimplemented over platform
  classes (Constitution I).
- **FR-019**: The list MUST show, per application, name, namespace, enabled state, resource,
  authentication methods, dispatch class and type, and MUST give an attention highlight (icon and
  text, not color alone) to applications reachable without authentication (RN-FD-07). The highlight
  MUST grade the exposure in the list row itself, not only in the inspector: an unauthenticated REST
  API is marked more strongly than an unauthenticated application that serves only static files. The
  grade is derived from the authentication methods the API reports and from verifiable facts about
  the dispatcher, never from the application's name. FlightDeck's own static application and its
  API MUST therefore show different markers. Filters: text, namespace, enabled state, REST or not,
  no authentication.
- **FR-020**: An application the API marks as a system application MUST be signaled as such.
  Deleting it MUST require maximum confirmation with a consequence stating that the platform or its
  tools may stop working; the API's own marking decides, never a name pattern (RN-FD-34, UC03 A3).
- **FR-021**: The inspector's links panel MUST show the resource protecting the application, the
  roles granting that resource with the permission they grant, the number of users holding those
  roles (with the list one click away), and for a REST application a link to its specification in
  the REST APIs section. The roles MUST be reachable in one click (PRD UC03-2).
- **FR-022**: Editing MUST cover every attribute the official create/edit operation accepts, with
  field-level validation messages from the API shown verbatim. Grades: create and edit are simple;
  an edit that disables the application, changes its authentication methods, resource, match roles,
  namespace or dispatch class, or any edit to a FlightDeck application, is reinforced (affects third
  parties); delete is reinforced, or maximum for a system application.
- **FR-023**: The server MUST refuse, with §9 message 4 and a trail entry, any mutation that would
  disable, delete, rename or make unreachable a web application serving FlightDeck (Constitution
  VII, RN-FD-12). FlightDeck's applications are identified by what the install declares, not by the
  path the user typed.
- **FR-024**: Percent class access configurations MUST be listed per application and globally, with
  allow type, class or package and allowed state, editable through the shared mutation layer; delete
  is reinforced (type the class or package name).
- **FR-025**: The domain keeps its section tabs from feature 001 (web applications, REST APIs,
  percent class access) because it has more than one entity type; the active tab and the selected
  entity are in the address.

#### REST API explorer (UC04)

- **FR-026**: The explorer MUST discover REST services per namespace through the instance's REST
  management interfaces (the documented `/api/mgmnt/` services and `%REST.API`, not the SysAdmin
  API), covering both services defined by a specification and services coded by hand, and MUST
  flag services that have no published specification (RN-FD-09). A route list the platform
  generates from a hand-coded dispatch map is shown as metadata and does not count as a
  specification.
- **FR-027**: FlightDeck's own API MUST appear among the discovered services with the OpenAPI
  specification FlightDeck publishes, not a reconstruction (RF12).
- **FR-028**: A selected specification MUST render grouped by path and method, with parameters,
  request and response schemas.
- **FR-029**: The test executor MUST take from the client only the method, a path relative to the
  instance, query parameters, headers and body. Scheme, host and port MUST be derived by the server
  from the current instance. A path that names another host, a scheme, or escapes the instance MUST
  be refused. FlightDeck MUST NOT act as a proxy for external requests (RN-FD-08).
- **FR-030**: Test requests MUST run under the signed-in user's identity without FlightDeck holding,
  forwarding or storing a credential (Constitution II), and never with more privilege than the
  FlightDeck request itself. When the target application would grant roles to a real call that a
  test request does not receive, the response view MUST say so before and after running, because
  the result can differ from a real call (verified in spike T-EXEC-1). Services unreachable that way
  are reported verbatim, not retried with another identity.
- **FR-031**: The response view MUST show status, elapsed time, headers and body (formatted when
  structured, size-limited with the size stated), and MUST offer the equivalent `curl` command. The
  copied command MUST NOT contain any credential or session token; it uses a placeholder the user
  fills in.
- **FR-032**: POST, PUT, PATCH and DELETE test requests MUST be refused by the server while safe mode
  is armed, with §9 message 3 and the disarm offer. The server decides from the method of the
  request under test, so running GET, HEAD or OPTIONS stays possible while armed even though running
  a test is itself a request to FlightDeck.
- **FR-033**: A namespace without REST services MUST show an empty state with the probable cause and
  a pointer to the namespace where FlightDeck's own API is installed (UC04 A4).
- **FR-034**: The README MUST state that the test executor is confined to the current instance, is
  not an outbound proxy, and runs as the signed-in user.

#### Cross-cutting

- **FR-035**: Every new user-facing text uses the §9 catalog where a message exists; new texts are
  English and added to the catalog source used by feature 001.
- **FR-036**: All screens MUST follow `docs/design.md` and `docs/prototype.html`: tokens only (no
  color literal), both themes verified for contrast, the §7 anti-pattern list, keyboard operability
  with visible focus, and the list-plus-inspector geometry including the overlay inspector below
  1280 px.
- **FR-037**: Platform defects of the official API encountered in these operations MUST be
  documented in `verification/README.md` with the observed request, response and version, and
  surfaced to users with the original IRIS text.
- **FR-038**: Every change to the frontend MUST be followed by a rebuild of the versioned production
  bundle, and the bundle check MUST pass.

### Key Entities

- **Web application**: path name, namespace, enabled state, type, resource, authentication methods,
  dispatch class, match roles, system-application marking from the API, and the other attributes
  the official operation exposes. Linked to a resource, to percent class access configurations, and,
  when REST, to a discovered REST service.
- **Percent class access configuration**: identified by application, allow type and class or
  package; carries whether access is allowed.
- **REST service**: discovered per namespace; web application, dispatch class, namespace, whether
  it is specification-defined or hand-coded, whether a published specification exists, and the
  specification itself when it does.
- **Test request and response**: method, path relative to the instance, parameters, headers, body;
  response status, elapsed time, headers, body and size. Never contains a stored credential.
- **Mutation descriptor**: per official operation, the grade rule, target naming, secret fields,
  self-protection rule and impact provider. Declared once, consumed by the shared layer.
- **Dry-run**: the current and commanded state of every field, the change set, the impact block, the
  required grade, and the snapshot the comparison was computed from.
- **Trail entry**: time, operation, target, displayed differences or, for a REST test request, the
  request sent (secrets already masked by the mutation layer), result (`Applied`, `Failed`,
  `Blocked`) and message. Belongs to one tab; kept in that tab's session storage.
- **Linked entity reference**: an entity in another domain reachable from the links panel,
  opened read-only in the inspector.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 12 PRD acceptance scenarios of UC03, UC04 and UC10 pass as automated end-to-end
  tests on IRIS 2026.2 Community and IRIS for Health 2026.2 Community.
- **SC-002**: 8 of 8 web application operations are implemented or shown disabled with a stated
  reason; 0 are reimplemented outside the official API.
- **SC-003**: 100% of mutations sent while safe mode is armed are refused by the server when sent
  directly, without the UI, across every mutating route this feature adds and the REST test
  executor's mutating methods.
- **SC-004**: 100% of attempts to disable, delete, rename or make unreachable FlightDeck's own web
  applications are refused by the server, through the UI and through direct requests, and each is
  explained.
- **SC-005**: In a scripted concurrent-change test (a change made through the official API between
  opening the dry-run and confirming), 0 external changes are overwritten and the recomputed
  differences are shown every time.
- **SC-006**: An administrator identifies every unauthenticated web application on the demo install
  within 10 seconds of opening the domain, without opening any application.
- **SC-007**: From the list, the roles granting an application's resource are displayed after one
  click.
- **SC-008**: A developer goes from opening the REST APIs section to reading the response of a test
  request on FlightDeck's own API in under 60 seconds.
- **SC-009**: 0 test requests reach a host other than the current instance in a test that submits
  absolute URLs, other hosts, schemes and path traversal attempts.
- **SC-010**: 0 credentials or session tokens appear in the trail export, copied `curl` commands,
  browser storage or server logs after a session that edits applications and runs test requests.
- **SC-011**: The build fails when a stray confirmation dialog, diff renderer or trail write is added
  outside the shared layer (verified with a probe, like the dialect gate).
- **SC-012**: The dry-run opens with its orchestrated reveal completing within the design's motion
  budget (no transition over 200 ms outside the reveal sequence of §6), and the whole feature passes
  the design review checklist of feature 001 in both themes, with no accessibility violation.
- **SC-013**: The limited-mode matrix of feature 001 still passes: on IRIS 2026.1, any web
  application or pct-access operation the capability map marks unavailable is shown disabled with
  its reason, and the rest work.

## Assumptions

- **Official operations**: the 8 web application operations and their privilege (`%Admin_Secure:U`
  for all 8) are those in `docs/api-coverage.md`; the list schema exposes the system-application
  marking used by FR-020.
- **REST discovery sources** (observed on IRIS 2026.2, 2026-09-17): the platform's REST management
  service lists hand-coded REST applications per namespace with a route document generated from the
  dispatch map, and separately lists specification-defined applications. Hand-coded applications
  whose only document is generated are "without specification" for FR-026. The exact calls are a
  planning concern.
- **No version token**: the official API offers no ETag, version field or lock for web applications,
  so optimistic concurrency is a server-side re-read and compare with a documented residual window
  (edge cases).
- **Default install data**: the demo web application `/csp/fd-demo` and roles from feature 001 are
  the fixtures for acceptance tests; `/api/monitor` is unauthenticated on the default Community
  image and serves as the unauthenticated case.
- **Limited mode**: web application and pct-access operations follow the capability map on IRIS
  2026.1 like any other operation; this feature adds no version check.
- **Impact for web applications** is computed from the resource, the roles granting it and the users
  holding those roles, read through official operations the user is allowed to call; when the user
  cannot read roles or users, the impact block says so instead of guessing.
- **Pattern consumers**: web applications and percent class access are the two real consumers in
  this feature; the catalog covers what they do not (maximum grade on a non-system entity, secret
  fields).
- **Constitution V and request mode**: Principle V says every mutation shows a field-by-field diff.
  A REST test request has no current state, so request mode (FR-039) shows the exact request
  instead. The author decided this on 2026-09-17; the plan's Constitution Check must record it
  (a scope note or a Complexity Tracking entry), since the principle's text does not yet mention
  it.
- **Out of scope**: permissions, security, tasks, system and logs screens; their routes keep the
  feature 001 empty state. Read-only linked-entity detail for roles and users (FR-006) is in scope
  only as inspector content, not as those domains' lists or mutations.
