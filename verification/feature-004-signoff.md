# Feature 004 sign-off (T087, T088), 2026-09-18

Tasks and operating system management: the instrument cluster on canvas, processes whose controls the
API decides, the task list with its recent-history band, and the eleven remaining sections of the
operating system domain. Run from the working tree; nothing is committed.

## Static gates

| Gate | Result |
|---|---|
| `scripts/build/check-generated.sh` | up to date; `check-descriptors` ok (46 entity types, 128 mutations); `check-secrets` ok (54 candidate fields, 21 declared, 42 exempted); `check-coverage` ok (254 operations, 11 declined, 15 known gaps from feature 003 listed) |
| `scripts/build/check-dist.sh` | up to date |
| `npm run lint` | clean |
| `npm run check:tokens` | ok |
| `npm run check:dialect` | ok (11 declared exceptions) |
| `npm run check:mutation-boundary` | ok (3 declared exceptions) |
| `npm run check:secrets` | ok |
| `npm run contrast` | ok, both themes |
| `npm run test` (Vitest) | 18/18 |
| `npm run build` | ok |

## New gate: `check-coverage.py`

Counts the operations of every shipped domain against `docs/api-coverage.md` and fails naming any
that is neither reachable through a descriptor, a link provider or a service, nor declared in
`FlightDeck.Capability.Policy`. Wired into `check-generated.sh`.

**It found sixteen operations that no code reached** — fifteen from feature 003, which claimed full
coverage of 89, and one more (`GET /v2/security/sql-column-privileges`) that appeared once the scan
stopped counting an operation an entity type merely names. **All sixteen are now closed**, and the
gate carries no list of tolerated gaps: a list that is kept is a list that grows.

| Closed | How |
|---|---|
| `encryption/keys`, `encryption/data-element-keys`, `encryption/file/keys`, `encryption/file/admins` | Four link groups on the encryption section. The policy declined the **writes**, never the reads; a section showing a setting but not the keys it applies to tells half the truth. The two per-file reads take the file as a declared parameter. |
| `oauth2/resource-server/mapping` (GET, PUT, DELETE) and `/mappings` | A mapping is an entity type of its own, listed as a link group of the resource server that owns it, created and deleted from that server's action bar. |
| `POST oauth2/server/client`, `POST oauth2/client/server-definition` | The creates the platform expresses as POST beside the PUT that edits. Discovery, which makes the instance fetch the provider's metadata, is graded reinforced by a rule that reads the parameter. |
| `POST audit/records` | A bounded read of the most recent records, on the audit section. It answers **202**: the records arrive through the asynchronous helper this feature built, which now serves the disk instrument, the long storage operations and this. |
| `POST audit/event/clear-count` | Reinforced: the count it discards cannot be recovered. |
| `GET security/sql-column-privileges` | Collected by the SQL privileges panel for the objects the other two listings already named, with a declared cap and what it skipped stated. |
| `POST ldap/test`, `GET mft/connection/auth-code-url`, `POST oauth2/revoke` | **Reinforced, each stating what it reaches outside this instance**: a real sign-in at the directory server (repeated failures can lock the account there), an authorization URL that grants access when followed, and tokens that stop working at the authorization server. The LDAP password is a secret field. |

The fourteen gaps of this feature were closed the same way: seven link providers (the three namespace
mapping families, database volumes, ECP databases, language-server activity, file-access paths), the
monitor dashboards block, and the task-info read.

**The gate was also made honest about itself.** Its first version counted an operation as reachable
when any class mentioned it, which included the generated catalogues and the descriptor XData — so
removing a descriptor still passed. It now reads descriptors structurally and scans only the classes
that make calls. Probed by deleting one descriptor: the gate named it and failed.

## What running every project on IRIS 2026.1 found

The three earlier features ran only part of the suite on that version; this feature ran all of it,
which surfaced one design error and several tests that presumed a full instance.

**The self-protection rule was comparing the wrong thing.** "The process running your own session"
was implemented as `$job` — the process serving the request. IRIS serves consecutive requests from
different processes, so the list marked one process and the mutation blocked another: the rule could
refuse an arbitrary process and let the real one through. It now compares the **CSP session**
(`CSPSessionID` on the process against the signed-in session), and falls back to the request's own
process where the platform reports no session. The list, which carries no session identifier, marks
the process serving that request and says exactly that ("Serving this request"); the block uses
either, because both are true reasons to refuse.

**Tests that presumed a full instance** were rewritten to follow the instance, each skipping with a
stated reason: no terminable process other than this session's own; no recorded failed run (the
demo's failing task does run on 2026.2, but 2026.1 records no history row for it); the database
directories not offered at all on the v1 dialect; and a control the instance disabled between the
list read and the inspector read.

## Fresh installs

Each was `docker compose down -v` then `up -d --build`, with the demo, then the whole backend suite,
every Playwright project and both enforcement scripts. One install at a time.

| Install | Backend `%UnitTest` | Playwright | Enforcement |
|---|---|---|---|
| IRIS CE 2026.2 (port 52780) | 168/168, 37 classes | 115 passed, 16 skipped | safe mode ok; mutation ok |
| IRIS for Health 2026.2 (port 52792, project `fd-health`) | 168/168 | 115 passed, 16 skipped | safe mode ok; mutation ok |
| IRIS CE 2026.1 (port 52791, project `fd-v1`, limited mode) | 168/168 | 122 passed, 9 skipped | safe mode ok; mutation ok |

The counts above are the final run, after feature 003's sixteen unreached operations were closed.

Every skip states its reason. The new ones this feature adds are conditions of the install, not
gaps: an instance that allows terminating no process but the one serving the request; an instance
that has recorded no failed task run; the database directories the v1 dialect does not offer; and a
control the instance disabled between the listing and the inspector read.

## Capability counts

| Install | allowed | unavailable (this version) | declined (policy) | total |
|---|---|---|---|---|
| IRIS CE 2026.2 | 262 | 0 | 11 | 273 |
| IRIS CE 2026.1 | 200 | 62 | 11 | 273 |

The three storage writes this feature declines were merely absent on 2026.1 before; they are now
declined on every version, which is a different reason for the same disabled control and is counted
apart.

## Quickstart (T088)

Run as written on IRIS CE 2026.2. §1, §2 and §5's curl ran verbatim; the header came back as
documented (`LOCATION: /api/admin/v1/async-result?id=…` on a v2 instance). §4, §6 to §12 are the
`instruments`, `processes`, `tasks` and `system` projects, which drive the same screens and assert
the same outcomes; both themes were checked by hand in the design review.

**Corrected in the quickstart:**
- §1 now names `check-coverage` and says it prints the earlier feature's unreached operations and
  fails on any new one.
- §3 says that several tests skip with a stated reason where the install does not present their
  condition, and that a skip with a reason is the expected outcome there rather than a gap.
- §7 now says which process "your own" is: it changes between requests, so the list must be read
  again before choosing one.
- §9's address was `/logs/events`; the logs domain's entry section is `/logs/stream`, which exists
  today, so the jump is verifiable now. The same correction was made in `data-model.md`,
  `research.md` and `tasks.md`.

## Result

Feature 004 is complete: 88 of 88 tasks. The matrix is green on IRIS CE 2026.2, IRIS for Health 2026.2
and IRIS CE 2026.1, from fresh installs, with the same backend suite and the same Playwright projects
on each. Nothing is committed; the working tree carries the changes.

**Every operation of every shipped domain is now reachable or declined**, with no tolerated list in
the gate. `refusedWhen` is written into the pattern's own documentation
(`frontend/src/pattern/README.md`, "When the object itself says no") and into
`contracts/ui-pattern-delta.md` §3.2 as a standing rule, and the pattern catalog exercises it on a
fixture item the API refuses — beside one that carries no such field at all, which stays editable,
because an unknown capability is not a refusal.
