<!--
Sync Impact Report
==================
Version change: 1.0.0 → 2.0.0
Bump rationale: MAJOR. Principle I is redefined: its scope is narrowed to the running portal, and
its list of allowed native providers grows from one gap (logs) to two (logs, host CPU/memory).

Modified principles:
  I. Official SysAdmin API First (RN-FD-30)
     - Scope: governs the running portal's behavior, not the installer bootstrap.
     - Installer bootstrap exception: narrow, idempotent, recorded in plan Complexity Tracking.
     - Objects the installer creates beyond FlightDeck's own plumbing (demo data) MUST use the
       official API.
     - Native providers: logs AND host CPU/memory metrics (/proc/stat, /proc/meminfo). The
       SysAdmin API v2 reports only IRIS-internal counters and shared memory, while the contest
       statement names CPU and memory explicitly.

Added sections: none
Removed sections: none

Templates reviewed (read-only, not modified by this command):
  ✅ .specify/templates/plan-template.md      — Constitution Check reads this file at runtime
  ✅ .specify/templates/spec-template.md      — no constitution-specific slots
  ✅ .specify/templates/tasks-template.md     — no constitution-specific slots
  ✅ .specify/templates/checklist-template.md — no constitution-specific slots

Follow-up TODOs:
  - docs/prd.md RN-FD-30 and §10.1 still say "native providers: logs only". Update them to match
    Principle I v2.0.0 (tracked as a polish task in specs/001-foundation-shell/tasks.md).
  - Project skills for UI code, backend, domain screen structure and contest packaging are still
    absent from .claude/skills/ (carried over from 1.0.0).
  - docs/prd.md and docs/design.md cross-reference legacy file names (carried over from 1.0.0).
-->

# FlightDeck for InterSystems IRIS Constitution

FlightDeck is an alternative management portal for InterSystems IRIS, built for InterSystems
Programming Contest #48. Product scope lives in `docs/prd.md`; visual and interaction design in
`docs/design.md`; operation-by-operation API mapping in `docs/api-coverage.md`; contest rules and
judging strategy in `docs/contest.md`. This constitution states the rules that no feature, plan or
task may break. Where it cites `RN-FD-nn`, the full rule text in `docs/prd.md` §8 applies.

## Core Principles

### I. Official SysAdmin API First (RN-FD-30)

**Scope.** This principle governs the behavior of the **running portal**: FlightDeck API handlers,
composition, native providers, and every action a user triggers from the UI. It does not govern
the **installer bootstrap**, meaning the packaging steps that load and compile FlightDeck and
register FlightDeck's own web applications before the portal exists.

- The official SysAdmin API (`/api/admin`, v2 operations under `/api/admin/v2`, specified in
  `docs/sysadmin-api-v2.json`) is the source of truth for every administrative operation.
- Where the API provides an endpoint, the portal MUST use it. Reimplementing an operation it
  already exposes over ObjectScript classes (`Config.*`, `Security.*`, `SYS.*`, etc.) is forbidden.
- The FlightDeck backend forwards and composes; it MUST NOT rewrite. Composition (effective
  privilege, entity graph, impact analysis, diffs, self-protection) is allowed and expected.
- Native providers exist only for what the API does not cover. Today there are two gaps:
  - **Logs**: `messages.log`, alerts and the interoperability event log.
  - **Host CPU and memory**: read from `/proc/stat` and `/proc/meminfo`. The SysAdmin API v2
    reports only IRIS-internal counters and IRIS shared memory, while the contest statement names
    CPU and memory explicitly. Where both exist, the portal presents IRIS shared memory (from the
    API) and host memory (native) as separate, labeled metrics.

  Adding any other native provider requires a constitution amendment naming the gap.
- The REST explorer (UC04) uses `/api/mgmnt/` and `%REST.API` because the SysAdmin API does not
  cover it; this is a documented gap, not an exception to the rule.
- Every one of the 273 official operations MUST be assigned to a domain and either implemented
  or explicitly degraded with a stated reason (see `docs/api-coverage.md`).
- **Installer bootstrap exception**:
  - Allowed: loading and compiling code, declaring FlightDeck's own web applications through the
    package manager, and (container path only) platform-default account fixes the image requires.
  - It MUST be minimal and idempotent, and every item MUST be recorded in the feature plan's
    Complexity Tracking.
  - Anything else the installer creates, in particular demonstration roles, resources, tasks, web
    applications and wallet collections, MUST be created through the official API.

Rationale: every contestant has the same endpoints. Reimplementation adds risk, diverges from the
platform, and earns nothing; experience, logs and real host telemetry are where FlightDeck
differentiates. The installer is kept out of scope because creating the portal's own entry points
over HTTP, before the portal exists, adds a failure mode to the path that decides Clarity of
Instructions and Developer Experience.

### II. Delegated Identity, No Stored Credentials (RN-FD-01, RN-FD-33)

- Identity and authorization are delegated to IRIS. The portal has no user store of its own, and
  every operation runs under the authenticated user's identity and roles.
- The portal MUST NOT store, cache or persist credentials in any layer: browser storage, cookies
  it controls, server globals, files, logs, or memory beyond the request that uses them.
- This holds under every authentication path, including any fallback for instances older than
  IRIS 2026.2 that lack `/login`, `/refresh`, `/logout` and `/revoke`. A fallback that needs a
  stored credential is rejected, not accepted as a temporary compromise.
- Invalid credentials produce one generic error that does not reveal whether the user exists.
- `GET /info` is the source of version, edition and user privileges. Capability detection MUST
  NOT parse version strings when the API answers the question.

Rationale: an admin portal that keeps admin credentials is itself the largest attack surface on
the instance.

### III. Capabilities Derived From the Spec (RN-FD-02)

- The session capability map MUST be computed by crossing the privilege each SysAdmin API
  operation declares (e.g. `%Admin_Secure:U`, `%Admin_Operate:U or %Admin_Task:U`) with the
  privileges of the authenticated user.
- A hand-written permission table, or a per-screen hardcoded privilege check, is a defect.
- Actions the user cannot perform MUST be shown disabled with the required resource and
  permission stated. They are never hidden.

Rationale: a derived table cannot drift from the platform; a hand-coded one will.

### IV. Safe Mode Per Tab (RN-FD-03)

- Every session starts read-only (safe mode), with a persistent, unambiguous indicator in the
  glareshield.
- Disarming is explicit and scoped to a single browser tab. The armed/disarmed state MUST NOT be
  shared across tabs, and MUST NOT be persisted (no localStorage, sessionStorage, cookie or
  server state). Every new tab, including a duplicate of a disarmed tab, starts armed.
- Any mutation attempted while armed (forms, command palette actions, REST explorer POST/PUT/
  PATCH/DELETE) is blocked, and disarming is offered as the preceding step.

Rationale: safe-by-default is the core Applicability argument and must survive reloads,
duplicated tabs and expired sessions.

### V. Diff Before Every Mutation (RN-FD-04, RN-FD-11, RN-FD-27, RN-FD-31)

- Every mutation MUST show a field-by-field diff (current vs commanded) before it is applied.
  A mutation with no difference sends no request.
- Confirmation level is set by the operation, not the domain: simple (confirm after diff),
  reinforced (type the target name), maximum (type the identifier and acknowledge the
  consequence). Destructive actions MUST require typing the target name or identifier; process
  termination is always maximum (RN-FD-22).
- Every removal or revocation in security runs impact analysis (users and objects that lose
  access) and shows it in the same confirmation view (RN-FD-11).
- If server state changed between read and confirm, the portal reloads, recomputes the diff and
  requires a new confirmation; it never overwrites external changes (RN-FD-31).
- Every applied or failed mutation is recorded in the tab-local session trail (time, target,
  diff, result), exportable as JSON, labeled as not a substitute for IRIS auditing.
- The diff/confirm/trail flow is ONE shared component. Per-domain reimplementations are defects.

Rationale: confidence is the third problem the product exists to solve; with 273 operations, a
per-domain mutation flow would be the most expensive mistake in the project.

### VI. Secrets Are Write-Only (RN-FD-14)

- Secret material (wallet secrets, private keys, key passwords, client secrets, search/SMTP
  passwords, tokens) MUST never be displayed, never returned by any FlightDeck API response,
  and never written to any log, trail, error message or diff.
- Secrets can only be set, replaced or deleted. No read-back path exists anywhere, including
  debug, export or "reveal" affordances. Diffs show a secret field as changed/unchanged only.

Rationale: stricter than strictly necessary, adopted deliberately as product posture.

### VII. Self-Protection (RN-FD-12)

- The portal MUST block operations that would remove the last administrative access to the
  instance, disable or delete the web application serving FlightDeck, or terminate the process
  running the current session.
- These checks are enforced server-side in the FlightDeck backend. A client-only check does not
  satisfy this principle.
- Every block is explained to the user in plain language.
- Changes affecting the session's own user require reinforced confirmation and a warning that
  the effect may be immediate.

Rationale: a rule that lives only in the client is not a rule.

### VIII. Graceful Degradation, No Broken Screens (RN-FD-32)

- Any capability missing on the running IRIS version or edition (IRIS CE vs IRIS for Health CE,
  pre-2026.2, disabled auditing, absent wallet, etc.) appears disabled with an explicit reason
  and, when known, the minimum version. Sibling sections keep working.
- Data delivered asynchronously (e.g. disk free space via `/v2/async-result`) MUST keep the last
  known value visible while refreshing. It is never blanked and never replaced by a spinner.
- No screen ever breaks: an unavailable source, failed request or unexpected payload degrades the
  affected region only, with the original IRIS error shown rather than generic portal text.
- Schemas without declared shape (`SystemResourcesStats`, `SharedMemoryUsage`) MUST be probed
  against a real instance before being typed. Fields are never invented.
- An inconclusive verification probe blocks planning of the dependent feature; it MUST NOT be
  turned into a user-facing degradation message.

Rationale: the jury runs Community images; a broken screen on either one fails Applicability
and Usability at once.

### IX. The API Decides What Is Allowed (RN-FD-34)

- When a schema declares an operation capability on an object (e.g. `CanBeTerminated`,
  `CanBeSuspended`, `CanReceiveBroadcast` on `Process`), those fields directly govern the
  control state.
- The UI MUST NOT infer permission from object type, user, name, state or heuristics. When the
  API says no, the control is disabled with the server's reason and the action is never attempted.

Rationale: the platform has already answered; guessing can only be wrong.

### X. docs/design.md Is Binding

- `docs/design.md` is an acceptance specification, not guidance. Specifically, these are
  acceptance criteria for every UI task:
  - the token tables for both themes (§3.1): no color outside them; no literal hex in components;
  - the radius hierarchy (§3.3): 0 structural, 2px controls, 6px floating layers only;
  - the motion budget (§3.4): 120ms layers, 90ms control state, nothing above 200ms, one
    orchestrated moment (the dry-run reveal), `prefers-reduced-motion` disables all motion;
  - the anti-pattern list (§7): any item present is a defect.
- The quality floor in §8 (contrast measured in both themes, full keyboard operation, visible
  focus ring, tabular numerals, WCAG 2.1 AA, usable from 1280px) is verified before submission.
- Precedence: `docs/design.md` overrides `docs/prd.md` on appearance; `docs/prototype.html`
  overrides `docs/design.md` for components it already implements; `docs/design.md` overrides any
  condensed design skill.

Rationale: two signature moments over a disciplined, conventional shell is the chosen strategy;
inconsistency reads as amateurism, and a single literal color silently breaks one of two themes.

### XI. English Everywhere

- All UI text is English. The message catalog in `docs/prd.md` §9 is the baseline wording.
- Code comments, commit messages, README, OpenAPI descriptions and log messages are English.
- Internationalization is out of scope; no i18n layer is built.

Rationale: contest moderation requires an English README, and the audience is international.

## Technical Constraints

- **Backend:** ObjectScript REST under an OpenAPI specification. The FlightDeck API is the single
  surface consumed by the UI and appears in its own REST explorer (RF12, RN-FD-09).
- **Frontend:** React 18, TypeScript, Vite. Static build.
- **Hosting:** everything is served by IRIS itself. No external runtime (no Node server, no
  reverse proxy, no sidecar) in the delivered product.
- **Assets:** IBM Plex Sans and IBM Plex Mono self-hosted with a Latin subset. No CDN-loaded
  fonts, scripts or styles; the portal must work on an instance with no internet egress.
- **Themes:** dark (design default) and light, switched by swapping root variables. Initial theme
  follows the OS; explicit choice persists per user (this is the only UI preference persisted).
- **Telemetry:** time series render on canvas, never declarative SVG. Metrics history is never
  persisted server-side (RN-FD-21). Host CPU and memory come from the native provider (Principle I),
  and IRIS metrics from the SysAdmin API.
- **Logs:** all sources map to the normalized schema with `raw` always preserved (RN-FD-23,
  RN-FD-24). Files are read in reverse, paginated, never loaded whole (RN-FD-25).
- **REST executor:** target always derives from the current instance; the portal is never a
  proxy for external requests (RN-FD-08), and the README says so.
- **Lists:** server-side pagination for every listing; no unbounded collection loads.
- **Compatibility:** MUST run on both `intersystemsdc/iris-community` and
  `intersystemsdc/irishealth-community`, with no change in procedure.
- **Installation:** `docker compose up -d` with no file edits and no required variables;
  IPM install as the alternative. Demo data is created automatically only in the container path;
  via IPM on an existing instance it is opt-in and off by default (RN-FD-28, RN-FD-29).
- **Development environment:** WSL2 with native Docker Engine (no Docker Desktop). The repo lives
  on `/mnt/d` (DrvFs), so durable IRIS data MUST use named Docker volumes, never bind mounts from
  `/mnt/d`, and the Vite dev server MUST use polling watch. These are in place from day one.
- **Project skills:** detailed rules for UI code, backend, domain screen structure and contest
  packaging live in project skills under `.claude/skills/`. Consult the relevant skill before
  writing code in those areas. This constitution does not restate them; where a skill and this
  constitution conflict, this constitution wins and the skill is updated.

## Delivery Priorities and Quality Gates

Submissions are judged on **Complexity, Clarity of Instructions, Developer Experience,
Applicability and Usability**. Two of the five are README and installation. Therefore:

- README (English, installation steps, link to the Ideas Portal idea, port-conflict handling,
  REST executor confinement explained) and one-command installation are first-class deliverables
  with reserved schedule. They are planned and reviewed like features, not left as final polish.
- Installation is verified from a clean environment on both Community images before submission.
- Every domain screen has content on first access in the container install path.
- Scope cuts follow `docs/prd.md` §13.3: cut depth in API-covered domains first, never coverage
  of the six axes. Logs are never cut.
- Never cut: both theme token sets, tabular numerals, focus ring, dry-run orchestration, canvas
  instrument cluster, and the reserved README/install/video time.

Every plan (`/speckit-plan` Constitution Check) and every review MUST confirm:

1. No reimplementation of an operation the SysAdmin API exposes, in the running portal; installer
   bootstrap items are listed in Complexity Tracking (I).
2. No credential or secret persisted, returned or logged on any path (II, VI).
3. Capabilities come from the derived map; disabled actions state their reason (III).
4. Mutations go through the shared diff/confirm/trail component with the correct level (V).
5. Safe mode state is tab-scoped and not persisted (IV).
6. Self-protection checks exist server-side for any operation that could trigger them (VII).
7. Degraded and async states are specified for every data source touched (VIII).
8. Schema capability fields drive control state where present (IX).
9. No literal hex, no off-scale radius or spacing, no motion over budget, no §7 anti-pattern (X).
10. UI text, comments and commit messages are English (XI).
11. The feature runs on both IRIS CE and IRIS for Health CE.

## Governance

- This constitution supersedes all other project practices. Product documents in `docs/` define
  scope and design; where they conflict with this constitution, this constitution prevails until
  amended.
- Amendments are made via `/speckit-constitution`, record a Sync Impact Report, and state which
  `RN-FD` rules or design sections they affect. The author (sole Product Owner and developer)
  approves amendments.
- Versioning follows semantic versioning: MAJOR for removing or redefining a principle, MINOR for
  adding a principle or section or materially expanding guidance, PATCH for clarifications and
  wording.
- A violation found in review is a defect, not a trade-off. A deliberate exception MUST be
  recorded in the plan's Complexity Tracking with the principle cited, the reason, and the
  simpler alternative rejected; exceptions to Principles II, IV, VI and VII are not permitted.
- Compliance is checked at three points: the Constitution Check gate in every plan, the
  `/speckit-analyze` pass after tasks are generated, and the pre-submission review of
  `docs/design.md` §7 anti-patterns screen by screen in both themes.

**Version**: 2.0.0 | **Ratified**: 2026-09-16 | **Last Amended**: 2026-09-16
