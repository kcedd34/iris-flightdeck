# Feature Specification: FlightDeck Foundation and Shell

**Feature Branch**: `001-foundation-shell`

**Created**: 2026-09-16

**Status**: Draft

**Input**: User description: "Foundation and shell for FlightDeck, an alternative management
portal for InterSystems IRIS built on the official SysAdmin API. Scope: exactly UC01 (session,
identity, safe mode), UC02 (command palette) and UC11 (Docker Compose and IPM installation with
demo provisioning), from docs/prd.md Section 7. Use their Gherkin acceptance criteria verbatim as
the definition of done. Before any screen, deliver the day-1 verification script from
docs/prd.md Section 14. It probes every item in order, never aborts on error, classifies each
probe as confirmed_present, confirmed_absent or inconclusive, records the raw error, and exits
non-zero if any inconclusive remains. Probe 2, which authentication path works without storing
credentials, is blocking for UC01 and must be resolved before the session design is finalised.
The shell implements the layout of docs/design.md Section 4 and 4.1: 44px glareshield with
instance identity, vitals, theme toggle and persistent safe-mode indicator; 56px icon-only rail
with exactly six destinations; section tabs in the work header for domains with more than one
entity type; list-plus-inspector work area where detail never navigates away. Out of scope: every
other domain. Their routes render an empty state only."

**Governing documents**: `.specify/memory/constitution.md` v1.0.0 (principles I–XI);
`docs/prd.md` §7 (UC01, UC02, UC11), §8 (RN-FD rules), §9 (message catalog), §14 (verification);
`docs/design.md` §3, §4, §4.1, §7, §8.

## Clarifications

### Session 2026-09-16

> The first three were carried over from the previous revision and translated to English
> (Constitution XI). The rest were answered during this revision and /speckit-clarify.

- Q: After `docker compose up -d`, how does the evaluator learn the credential for the first
  sign-in? → A: The IRIS Community image's own default credential, documented in the README. The
  installer never generates a new credential. (The container log may repeat the portal URL and
  point at that documented default; it never prints a newly created secret.)
- Q: What triggers "session expired" in UC01 scenario 4: a FlightDeck-owned timeout or IRIS's
  native expiry? → A: FlightDeck keeps no timer of its own. It reacts when an API call reports
  that the IRIS session or token is no longer valid.
- Q: Should palette entity search query the real API generically, or only domains built in this
  feature? → A: Generic search against the real API, across every domain. Results from domains
  without a screen still appear, and selecting one opens that domain's declared empty state.
- Q: UC11 scenario 2 requires demo data on every domain screen, but domain routes are empty states
  in this feature. How is it satisfied? → A: Demo objects for every domain exist after install and
  are findable through palette entity search. The verbatim scenario is re-verified as each domain
  screen ships.
- Q: Which demo set does this feature provision? → A: The full UC11 set now: roles, resources, a
  sample web application, tasks, and a wallet collection when available.
- Q: How is UC01 scenario 4 proven without edit forms or diffs? → A: Restore-and-recompute is built
  as a shell capability and proven with a test-only fixture form that holds typed input and a
  computed difference. It is re-verified on the first real edit form.
- Q: Is safe mode enforced by the FlightDeck backend as well as the UI? → A: Both. Each tab sends
  its in-memory armed/disarmed state with every request; the backend rejects any mutation from an
  armed tab.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Verify what the platform supports before designing anything (Priority: P1)

As the developer building FlightDeck, I need one script that probes the target IRIS instance for
every open technical question in `docs/prd.md` §14, before any screen is built, so that design
decisions rest on confirmed platform behavior rather than assumption.

**Why this priority**: Probe 2 decides how users authenticate without any stored credential
(Constitution II). The session design in User Story 2 cannot be finalized until it resolves, and
probes 3–8 feed graceful-degradation decisions for every later feature.

**Independent Test**: Run the script against a fresh IRIS Community container and, separately, a
fresh IRIS for Health Community container. Inspect the report and exit code. No portal code needs
to exist.

**Acceptance Scenarios**:

1. **Given** a running IRIS instance, **When** the script runs, **Then** it executes these eight
   probes in exactly this order: (1) the SysAdmin API exists and responds, and the IRIS version;
   (2) which authentication path works without storing a credential, trying in order: in-process
   call under the user authenticated by the web application, JWT on IRIS 2026.2+, loopback proxy
   honoring the web session cookie; (3) the real response shape of system-resources statistics
   and shared-memory usage; (4) the asynchronous database-metrics cycle (trigger, poll, typical
   latency); (5) wallet endpoints respond; (6) the REST management/discovery API is available;
   (7) path and format of `messages.log`, the alerts file, and how the interoperability event log
   is queried; (8) whether auditing is enabled.
2. **Given** a probe fails, errors or times out, **When** the script continues, **Then** every
   remaining probe still runs and the report is complete.
3. **Given** the report is produced, **When** it is read, **Then** every probe has exactly one
   classification (`confirmed_present`, `confirmed_absent`, `inconclusive`), and every outcome
   other than `confirmed_present` includes the raw error or raw response.
4. **Given** at least one probe is `inconclusive`, **When** the script ends, **Then** it exits
   with a non-zero status.
5. **Given** probe 2 confirms one or more candidate paths, **When** the session design is
   finalized, **Then** it uses the first confirmed path in the probe order, and the report
   records which candidates were confirmed, absent or inconclusive.

---

### User Story 2 - Authenticate and start every session in safe mode (Priority: P1)

As an IRIS administrator, I want to sign in with my own IRIS credential and immediately see what I
can and cannot do, so I can work without risk of acting outside my permission level and without
wondering whether the tool kept my password.

**Why this priority**: Nothing in the product is reachable without a session, and safe mode is the
product's central trust promise (Constitution II, III, IV).

**Independent Test**: Against a live instance, sign in with valid and invalid credentials and with
users holding different privileges. Inspect browser storage, cookies and server logs for
credentials. Confirm the session is read-only until disarmed, and that new or duplicated tabs start
armed.

**Acceptance Scenarios** (verbatim from `docs/prd.md` UC01, translated):

1. **Given** that the user authenticates successfully, **When** the initial dashboard is opened,
   **Then** the session must be in safe mode, **And** the read-only indicator must be visible
   persistently.
2. **Given** that the user does not have the privilege required by an API operation, **When** the
   corresponding screen is rendered, **Then** the action must appear disabled, **And** the
   required resource and permission must be stated.
3. **Given** that the instance does not have the JWT authentication endpoints, **When** the user
   authenticates, **Then** access must work through the fallback path, **And** no credential may
   be persisted in any layer.
4. **Given** that the session expired with an unsaved edit open, **When** the user
   re-authenticates, **Then** the same screen must be restored, **And** the typed input preserved,
   **And** any computed difference must be recomputed before allowing confirmation.
   *Proven in this feature with a test-only fixture form (FR-017a); re-verified on the first real
   edit form.*

**Additional scenarios** (UC01 alternate flows, required by RN-FD-03 and RN-FD-01):

5. **Given** a tab was closed with safe mode disarmed, **When** a new session starts in any tab,
   including a duplicate of a disarmed tab, **Then** it starts in safe mode without exception.
6. **Given** an invalid credential, **When** sign-in fails, **Then** the message is exactly
   "Invalid credentials. Check your username and password." and does not reveal whether the
   username exists.
7. **Given** an IRIS instance whose SysAdmin API does not expose v2, **When** a user signs in with
   valid credentials, **Then** sign-in is refused with "Not available on this IRIS version or
   edition. Requires IRIS 2026.2." together with the version the instance reports, and no session
   is created.

---

### User Story 3 - Find and act on anything by typing its name (Priority: P2)

As an administrator, I want to find any object or start any action by typing its name, so I never
need to know where something lives in a menu tree.

**Why this priority**: The palette is the primary navigation surface for the whole product. It
needs a session (User Story 2) and must respect safe mode.

**Independent Test**: From an authenticated session on any screen, open the palette by shortcut,
search for terms that match actions and entities in several domains, navigate by keyboard, and
repeat with entity search made unavailable.

**Acceptance Scenarios** (verbatim from `docs/prd.md` UC02, translated):

1. **Given** that the user is on any screen, **When** they press Ctrl+K or Cmd+K, **Then** the
   palette must open with focus in the search field.
2. **Given** that the term matches entities from different domains, **When** the results are
   displayed, **Then** they must be grouped by domain, **And** each result must show the context
   that disambiguates it.
3. **Given** that entity search is unavailable, **When** the user types a term, **Then** local
   actions must continue to be offered, **And** the unavailability must be signaled.
4. **Given** that safe mode is armed, **When** the user selects a mutating action, **Then** the
   system must offer to disarm before executing.

---

### User Story 4 - Install with one command and land on a populated instance (Priority: P2)

As a contest evaluator, or an administrator adopting the tool, I want to bring FlightDeck up with
one command and land on an instance with example data, so I can assess the product without
getting stuck on setup.

**Why this priority**: Clarity of Instructions and Developer Experience are two of the five
judging criteria (Constitution, Delivery Priorities). Installation is a first-class deliverable
built alongside the shell, not left for the end.

**Independent Test**: On a clean machine, clone the repository and run `docker compose up -d`, on
both Community images. Separately, install via IPM into an existing instance and confirm that no
demo objects were created.

**Acceptance Scenarios** (verbatim from `docs/prd.md` UC11, translated):

1. **Given** a clean environment with Docker available, **When** the user runs
   `docker compose up -d`, **Then** the portal must be reachable with no additional manual step.
2. **Given** that the installation finished, **When** the user accesses the portal for the first
   time, **Then** every domain screen must contain demonstration data.
   *In this feature: demo objects for every domain exist and each is findable through palette
   entity search (FR-044a). The verbatim scenario is re-verified as each domain screen ships.*
3. **Given** that the user installs via IPM into an existing instance, **When** the installation
   finishes, **Then** no demonstration object may have been created without consent.
4. **Given** that the installation is done on the IRIS for Health Community image, **When** the
   portal is accessed, **Then** every domain must work with no change in procedure.

---

### User Story 5 - Move through a consistent shell (Priority: P3)

As an administrator, I want the same frame on every screen, with instance identity, vitals, theme
and safe-mode state always in view, six fixed destinations, and details that open beside the list
instead of replacing it, so I always know where I am and what mode I am in.

**Why this priority**: Every later domain feature plugs into this frame. It depends on User
Story 2 for identity and safe-mode state.

**Independent Test**: Signed in, visit the home screen and all six destinations in both themes,
at 1280px and wider and below 1280px, using only the keyboard. Measure glareshield height and rail
width, and check tab strips, empty states, the inspector and the URL.

**Acceptance Scenarios**:

1. **Given** any screen, **When** it renders, **Then** a 44px glareshield is visible showing
   instance identity (version, edition, namespace), vitals (host CPU, host memory, IRIS shared
   memory and disk, each labeled), the theme toggle, the safe-mode indicator and the signed-in
   user, and it stays visible above floating layers.
2. **Given** safe mode is disarmed, **When** the glareshield renders, **Then** the indicator reads
   "Live — changes enabled" in the warning state with a full-width 2px rule along the glareshield's bottom edge, and
   carries an icon and text label in addition to color.
3. **Given** any screen, **When** the rail renders, **Then** it is 56px wide, icon-only, with
   exactly six destinations in fixed order (Web applications and APIs, Permissions, Security and
   secrets, Tasks, System, Logs), the active one marked by a 2px selected-color bar on its inner
   edge, and labels available on hover or keyboard focus.
4. **Given** a domain with more than one entity type, **When** it opens, **Then** a section-tab
   strip appears under the work-header title, the active tab is marked by a 2px bottom rule, and
   the active tab is reflected in the URL. **Given** a domain with a single entity type (Logs),
   **Then** no tab strip is shown.
5. **Given** any of the six destinations or tabs, **When** it renders in this feature, **Then** it
   shows a declared empty state that states why it is empty and what the user can do next (for
   example, open the palette), and never an error or a broken layout.
6. **Given** an entity is selected (for example, from the palette), **When** its detail opens,
   **Then** it opens in the inspector next to the list, without navigating away. Below 1280px wide,
   the inspector opens as an overlay instead of a column.
7. **Given** a first visit, **When** the theme is resolved, **Then** it follows the OS preference.
   An explicit choice made with the toggle overrides it and is remembered for that IRIS user.

---

### Edge Cases

- **None of probe 2's candidate paths is confirmed.** User Story 2 is blocked. The session design
  is not finalized, and no path that stores a credential (for example, keeping the password to
  replay basic authentication) is adopted as a workaround. The situation is escalated as a scope
  decision.
- **Probe 2 confirms different paths on IRIS Community and IRIS for Health Community.** Both are
  recorded, and the session design must work on both images with no difference for the operator.
- **A probe reaches the API and gets a definitive "not present/not configured" answer, versus the
  call itself failing or timing out.** The first is `confirmed_absent`; the second is
  `inconclusive`. They are never merged, and an inconclusive result is never shown to end users as
  a degradation message.
- **The user has no %Admin privilege at all, so the instance probe refuses them.** Sign-in does not
  create a half-working session. The user sees which privileges are required, in the §9 message
  format: "Requires [PERMISSION] on [RESOURCE]. Ask your instance administrator for access."
- **The user has some but not all administrative privileges.** The session opens read-restricted,
  and the missing resources are named wherever an action is disabled (UC01 A2).
- **Disk vitals arrive asynchronously.** While a refresh is in flight, the last known value stays
  visible. It is never blanked or replaced by a loading indicator. Before the first value arrives,
  the slot shows a shape-preserving placeholder, not a spinner.
- **Host counters are not readable** (non-Linux host, restricted `/proc`). CPU and Memory show
  unavailable with "Host metrics are not readable on this platform."; Shared memory and Disk keep
  working.
- **A vitals metric is unavailable on this edition or version.** That vital is shown disabled with
  the reason. The other vitals and the rest of the glareshield keep working.
- **The session expires while the palette is open or a query is typed.** Re-authentication happens
  in an overlay without leaving the page. Afterward the same screen, tab, selection and typed input
  are restored, and computed state is discarded and recomputed.
- **Palette search matches nothing.** The palette suggests searchable domains and points to the
  shortcut reference (UC02 A1).
- **Palette results exceed the display limit.** The top-ranked results are shown with the total
  count, and refinement by domain is offered (UC02 A4).
- **Entity search is unavailable.** The palette shows "Entity search is unavailable right now.
  Portal actions are still available." and keeps serving actions.
- **The user selects an action they lack the privilege for.** The action is shown disabled with the
  required resource and permission. It is not hidden and not executable.
- **A mutating request reaches the backend from an armed tab, or with no safe-mode state** (direct
  call, UI defect). It is rejected before reaching IRIS, and nothing changes.
- **Safe mode is armed and a mutating action is selected.** The palette offers disarming as a
  chained step, using the message "Safe mode is on. Turn it off to make changes in this tab."
- **The default install port is already taken.** The README documents the override variable and
  the exact error the operator will see (UC11 A1).
- **Class compilation fails during container install.** A legible error appears in the container
  log. Nobody needs to open a shell inside the container (UC11 A3).
- **Reduced motion is preferred.** All shell transitions are removed, and state changes are
  instant.

## Requirements *(mandatory)*

### Functional Requirements

**Day-1 verification (delivered before any screen)**

- **FR-001**: A verification script MUST run the eight probes of `docs/prd.md` §14 in the order
  listed there.
- **FR-002**: The script MUST NOT abort when a probe fails, errors or times out. All remaining
  probes MUST run.
- **FR-003**: Each probe MUST be classified as exactly one of `confirmed_present`,
  `confirmed_absent` or `inconclusive`. Every non-`confirmed_present` result MUST include the raw
  error or raw response.
- **FR-004**: The script MUST exit non-zero if any probe is `inconclusive`, and zero otherwise.
- **FR-005**: The report MUST be readable by a person and parseable by a program, and MUST record
  the instance version and edition it was run against.
- **FR-006**: An `inconclusive` probe MUST block planning of the area it covers and MUST NOT be
  turned into an end-user degradation message.
- **FR-007**: Probe 2 MUST test all three candidate authentication paths in order and report each
  candidate's classification. The session design (FR-009 to FR-018, including FR-012a, FR-015a and FR-017a) MUST NOT be finalized until
  at least one candidate is `confirmed_present` on both target images.
- **FR-008**: The script MUST be runnable against both IRIS Community and IRIS for Health
  Community with no change in procedure.

**Session, identity and safe mode (UC01)**

- **FR-009**: Authentication and authorization MUST be delegated to IRIS. FlightDeck MUST NOT have
  its own user store, and every operation MUST run under the authenticated user's IRIS identity and
  roles.
- **FR-010**: No password, token, or other credential may be stored, cached or logged in any layer
  (browser storage, portal-controlled cookies, server state, files, logs), on any authentication
  path including fallback paths.
- **FR-011**: The session MUST use the authentication path confirmed by probe 2 (first confirmed in
  probe order) on the running instance.
- **FR-012**: The instance-information endpoint MUST be the source of version, edition and the
  user's privileges. Capability detection MUST NOT parse version strings when that endpoint answers
  the question.
- **FR-012a**: If the instance does not expose SysAdmin API v2 (`apiVersion` below 2 in the
  instance-information response, or the `/v2` operations absent), sign-in MUST be refused with §9
  message 8 ("Not available on this IRIS version or edition. Requires IRIS 2026.2.") plus the
  detected version string as reported by the instance. The IRIS session opened by the attempt MUST
  be ended, and no FlightDeck session MUST exist afterward.
- **FR-013**: The session capability map MUST be computed by crossing the privilege each SysAdmin
  API operation declares in the official specification with the user's privileges. A hand-written
  privilege table is not permitted.
- **FR-014**: Every action the user cannot perform MUST appear disabled, stating the required
  resource and permission. It MUST NOT be hidden.
- **FR-015**: Every session MUST start in safe mode (read-only). Disarming MUST be an explicit user
  action scoped to the current browser tab. Safe-mode state MUST NOT be shared between tabs and
  MUST NOT survive a reload, a new tab or a duplicated tab.
- **FR-015a**: Safe mode MUST also be enforced server-side. Every request MUST carry the tab's
  in-memory safe-mode state, and the FlightDeck backend MUST reject any mutating request from an
  armed tab, or one that carries no state, with the §9 safe-mode message, before contacting IRIS.
- **FR-016**: Session expiry MUST be detected reactively, when an API call reports the IRIS session
  or token invalid. FlightDeck MUST NOT run its own idle timer.
- **FR-017**: On expiry, re-authentication MUST happen in an overlay without navigating away. It
  MUST restore the same screen, section, selection and typed input, and MUST discard and recompute
  any computed state (including diffs) before any confirmation is allowed.
- **FR-017a**: A test-only fixture form, not reachable from navigation or the palette in the
  shipped product, MUST hold typed input and a computed difference so that FR-017 and UC01
  scenario 4 can be proven before any domain edit form exists.
- **FR-018**: Invalid credentials MUST produce exactly "Invalid credentials. Check your username and
  password." and never distinguish an unknown user from a wrong password.

**Command palette (UC02)**

- **FR-019**: Ctrl+K (Windows/Linux) and Cmd+K (macOS) MUST open the palette from any screen,
  including when a floating layer is open, with focus in the search field.
- **FR-020**: The palette MUST show recent actions when opened with an empty query.
- **FR-021**: The palette MUST search two indexes in parallel: local actions, resolved on the
  client, and entities, searched on the server after a short debounce. Results MUST be grouped by
  domain, and each result MUST show disambiguating context (for example, namespace or entity type).
- **FR-022**: Entity search MUST cover every domain the SysAdmin API exposes, not only domains with
  screens. Selecting an entity from a domain without a screen MUST open that domain's route with
  the entity identified in the inspector and the domain's empty state in the list area.
- **FR-023**: The action index MUST include navigation to the home screen, the six destinations and
  every section tab, plus theme switching, arming and disarming safe mode, and signing out. It MUST
  also include the mutating operations of the SysAdmin API, each labeled with its domain and
  showing its capability-derived enabled or disabled state. In this feature, running a mutating
  action (after disarming) opens the owning domain's route.
- **FR-024**: If entity search fails or is unavailable, local actions MUST remain available, and the
  palette MUST show "Entity search is unavailable right now. Portal actions are still available."
- **FR-025**: Selecting a mutating action while safe mode is armed MUST offer disarming as the
  preceding step and MUST NOT execute the action until the tab is disarmed.
- **FR-026**: When results exceed the display limit, the palette MUST show the top-ranked results,
  state the total count and offer refinement by domain. When there are no results, it MUST suggest
  searchable domains and point to the shortcut reference.
- **FR-027**: The palette MUST be fully operable by keyboard: arrow keys to move, Enter to run,
  Escape to close, with focus returning to where it was before opening.
- **FR-028**: Selecting a result MUST record it in the recent-actions list for the current user.

**Shell layout (`docs/design.md` §4, §4.1: binding per Constitution X)**

- **FR-029**: The glareshield MUST be 44px tall, fixed, and visible on every screen including above
  floating layers. It MUST show, left to right: instance identity (version, edition, namespace),
  vitals, and then on the right the theme toggle, the safe-mode indicator and the signed-in user.
  The vitals, each with its own label, are:
  - "CPU": host CPU utilization;
  - "Memory": host memory in use;
  - "Shared memory": IRIS shared memory heap in use, a separate metric that is never presented as
    host memory;
  - "Disk": the fullest database.

  Labels follow `docs/prototype.html` wording.
- **FR-030**: The safe-mode indicator MUST read "Safe mode" when armed. When disarmed, it MUST read
  "Live — changes enabled" in the warning state with a 2px full-width rule on the glareshield's
  bottom edge. This wording follows `docs/prototype.html`, which prevails over design §4's all-caps
  mock for this component (design §10). Both states MUST carry an indicator mark and a text label,
  never color alone.
- **FR-031**: Vitals MUST refresh periodically, MUST pause while the tab is hidden, and MUST keep the
  last known value visible during refresh. Asynchronously computed values (disk) MUST NOT be blanked
  or replaced by a loading indicator. Numerals MUST be tabular.
- **FR-031a**: Host CPU and host memory MUST come from a native provider, because the SysAdmin API
  v2 does not report them (Constitution I, v2.0.0):
  - **CPU** percent is computed from the difference between two readings of the host's CPU time
    counters (`/proc/stat`), taken at least one second apart.
  - **Memory** percent is `(MemTotal − MemAvailable) / MemTotal` from `/proc/meminfo`.
  - IRIS shared memory and disk MUST come from the SysAdmin API.
  - If the host counters cannot be read (for example, IRIS on a non-Linux host), the CPU and Memory
    vitals MUST be shown unavailable with the reason "Host metrics are not readable on this
    platform."
  - Host metrics MUST require the same privilege as the API's monitor operations (Use on
    `%Admin_Operate`) and MUST show that requirement when it is missing.
  - In a container, the values describe the Docker host kernel, and the vital's tooltip MUST say so.
- **FR-032**: The rail MUST be 56px wide and icon-only, with exactly six destinations in this fixed
  order: Web applications and APIs, Permissions, Security and secrets, Tasks, System, Logs. The
  active destination MUST be marked by a 2px selected-state bar on the inner edge, with no
  background fill. Labels MUST appear as a tooltip on hover and keyboard focus.
- **FR-033**: Domains with more than one entity type MUST show a section-tab strip below the
  work-header title, with fixed tab order (most-used first), the active tab marked by a 2px
  selected-state bottom rule (no fill, no pill), and the active tab in the URL. Domains with one
  entity type MUST NOT show the strip. Tab sets are listed in Assumptions.
- **FR-034**: The work area MUST use the list-plus-inspector layout. Opening an entity's detail MUST
  update the inspector in place and MUST NOT navigate to another page. Inspector labels MUST use a
  fixed 96px label column. At widths below 1280px, the inspector MUST open as an overlay.
- **FR-035**: Every domain route and section tab in this feature MUST render a declared empty state
  that states the probable cause and a next action. It MUST NOT show a runtime error, a blank area
  or a centered spinner.
- **FR-036**: The home screen (the "initial dashboard" of UC01) MUST show instance identity and the
  session's capability summary, and MUST reserve the attention-items region, which shows an empty
  state until domains supply items.
- **FR-037**: Themes MUST be dark and light, switched from the glareshield toggle. The initial theme
  MUST follow the OS preference, and an explicit choice MUST be remembered per IRIS user. Theme is
  the only UI preference persisted.
- **FR-038**: The shell MUST meet `docs/design.md` §3 tokens, radius hierarchy and motion budget, §7
  anti-patterns, and §8 quality floor. That includes contrast measured in both themes, full keyboard
  operation, a never-suppressed focus ring, and `prefers-reduced-motion` honored.
- **FR-039**: All UI text MUST be in English, using the `docs/prd.md` §9 wording wherever a message
  there applies.

**Installation and provisioning (UC11)**

- **FR-040**: `docker compose up -d` on a clean environment MUST start IRIS, compile FlightDeck,
  register its web application and make the portal reachable, with no file edits, no required
  variables and no further manual step.
- **FR-041**: The container log MUST show, on success, the portal URL and a pointer to the
  documented default sign-in. On compilation or registration failure, it MUST show a legible error.
  The installer MUST NOT generate or print a new credential.
- **FR-042**: The default port MUST be overridable by an optional variable. The README MUST document
  the variable and the exact message seen on a port conflict.
- **FR-043**: FlightDeck MUST be installable via IPM into an existing instance, with demo
  provisioning off by default and runnable only by explicit opt-in.
- **FR-044**: The container install path MUST provision demonstration objects automatically on a
  fresh instance, and provisioning MUST be idempotent: re-running it creates no duplicates. The set
  MUST be the full UC11 set: roles, resources, a sample web application, tasks, and a wallet
  collection when the wallet is available (skipped with a logged reason otherwise). It MUST contain
  no credential or secret value visible anywhere in the portal.
- **FR-044a**: Every demo object MUST be findable through palette entity search after a fresh
  container install, grouped under its domain.
- **FR-045**: Installation and every capability in this feature MUST behave identically on IRIS
  Community and IRIS for Health Community, with no procedural difference.
- **FR-046**: The README MUST be in English and include: prerequisites, the one-command install, the
  default sign-in, port override and conflict message, the IPM path with the demo opt-in, the
  verification script's purpose and usage, and a link to the related Ideas Portal idea.

### Key Entities

- **Verification report**: One run of the day-1 script. Records the instance version and edition,
  when it ran, the overall exit status, and an ordered list of probe results.
- **Probe result**: Probe number and name, classification (`confirmed_present`, `confirmed_absent`,
  `inconclusive`), a finding summary, and the raw error or response. For probe 2, it also holds a
  per-candidate classification.
- **Session**: One authenticated browser tab. Holds the IRIS identity, the instance identity
  (version, edition, namespace), the capability map and the safe-mode state. Owns no credential. The
  safe-mode state is never shared or persisted.
- **Capability entry**: One SysAdmin API operation, the privilege it declares, whether the user
  satisfies it, and, when not, the resource and permission to display.
- **Palette entry**: Either an action (local; label, domain, whether it mutates, capability state)
  or an entity (server-found; name, domain, entity type, disambiguating context, target route).
- **Recent action**: A palette entry the user selected, kept per IRIS user for the empty-query list.
- **Theme preference**: The explicit theme choice (dark or light) for an IRIS user. Absent means
  "follow OS".
- **Demo provisioning set**: The objects created automatically on a fresh container install.
  Full UC11 set: roles, resources, sample web application, tasks, wallet collection when available.
  Contains no credential.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The verification script produces a complete eight-probe report on both Community
  images, with 100% of probes classified, and its exit code matches the presence of any
  `inconclusive` result in 100% of runs, including runs with deliberately broken probes.
- **SC-002**: 100% of new sessions, reloads, new tabs and duplicated tabs start in safe mode across
  at least 20 trials that include tabs duplicated from a disarmed tab.
- **SC-002a**: 100% of mutating requests sent directly to the FlightDeck backend with an armed or
  missing safe-mode state are rejected, and no IRIS state changes.
- **SC-003**: Zero credentials found in browser storage, portal-controlled cookies, server-side
  state or logs, inspected after sign-in, normal use, session expiry, re-authentication and
  sign-out.
- **SC-004**: The palette opens with focus in the search field within 100 milliseconds of the
  shortcut on every screen, including while entity search is still pending or unavailable.
- **SC-005**: An evaluator who has never seen the project reaches a signed-in home screen from a
  clean clone in under 10 minutes, following only the README, with zero file edits, on both
  Community images.
- **SC-006**: The first useful render of the home screen after sign-in happens in under 2 seconds on
  a local instance.
- **SC-007**: All six destinations and every section tab render without error in both themes, at
  1280px and at 1024px wide, and are reachable and operable by keyboard alone.
- **SC-010**: After a fresh container install, a palette search for each provisioned demo object
  returns it under the correct domain, on both Community images.
- **SC-011**: With the instance idle and then under a synthetic CPU load, host CPU and Memory agree
  with the operating system's own readings (`top`/`free` in the same host or container) to within 5
  percentage points, sampled 10 times, on both Community images.
- **SC-008**: A review against `docs/design.md` §7 finds zero anti-pattern defects in the shell, and
  contrast checks pass (4.5:1 text, 3:1 UI elements) for every shell token pair in both themes.
- **SC-009**: 100% of actions the signed-in user lacks privilege for appear disabled with a stated
  resource and permission; none are hidden. Checked with at least three users holding different
  privilege sets.

## Assumptions

- **Probe 2 order and selection.** Candidates are tried in the `docs/prd.md` §14 order. The first
  confirmed on the running instance is used. The session design is finalized only after the probe
  has been run on both target images.
- **Glareshield vitals** are a low-frequency snapshot, not the sliding-window canvas instruments,
  which belong to the System domain feature. Host CPU and host memory come from the native provider
  (FR-031a). IRIS shared memory and disk come from the SysAdmin API. The contest statement names CPU
  and memory explicitly.
- **Section-tab sets** (fixed order, most-used first), drawn from `docs/prd.md` UC03–UC09:
  - Web applications and APIs: Web applications, REST APIs, Percent class access.
  - Permissions: Users, Roles, Resources, Services, SQL privileges, Privileged routines.
  - Security and secrets: TLS, X.509, OAuth 2.0, Wallet, Encryption, LDAP, MFT, Auditing,
    Superservers.
  - Tasks: Tasks, Work queue categories, Async results.
  - System: Instruments, Processes, Databases, Namespaces, Devices, License, Locks, Web sessions,
    ECP, External language servers, DocDB, File system access.
  - Logs: single stream, no tab strip.

  Each domain's own feature may refine order and labels. The rule "tabs only when there is more
  than one entity type" is fixed.
- **Recent actions and theme preference** are kept per IRIS username in the browser, contain no
  credential, and are the only persisted UI state. Safe-mode state is never among them.
- **Home screen** is the "initial dashboard" referred to by UC01. Its attention-items content arrives
  with later domain features.
- **Default sign-in** is the IRIS Community image's documented default account. The README tells
  evaluators to use it and notes it is for local evaluation only.
- **Browsers**: current Chromium, Firefox and Safari. Minimum functional width is 1280px, with an
  inspector overlay below that. Mobile is out of scope.
- **Out of scope**: every domain's screens, lists, inspectors and mutations (UC03–UC09), the
  shared diff/confirm/trail component (UC10), the REST explorer and FlightDeck's self-listing
  (UC04, RF12).
- **Dependency**: the SysAdmin API v2 must be present on the target images, confirmed by probe 1.
  If probe 1 is `confirmed_absent`, the project design must be revisited (`docs/prd.md` §14).
- **Version floor: IRIS 2026.2** (the first release exposing SysAdmin API v2). Checked on
  2026-09-16:

  | Image | `iris --version` | SysAdmin API |
  |---|---|---|
  | `intersystemsdc/iris-community:latest` | 2026.1.0.234.1 | `apiVersion` 1, `/v2/*` → 404 |
  | `intersystemsdc/irishealth-community:latest` | 2026.1.0.235.2 | `apiVersion` 1, `/v2/*` → 404 |
  | `intersystemsdc/iris-community:2026.2-zpm` | 2026.2.0.221.0 | `apiVersion` 2 |
  | `intersystemsdc/irishealth-community:2026.2-zpm` | 2026.2.0.221.0 | `apiVersion` 2 |

  The `latest` tags of both Community images are **below the floor**. The installation therefore
  pins the `2026.2-zpm` tags, and FR-012a covers any instance below the floor.
