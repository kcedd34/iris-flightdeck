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

**It found fifteen operations of feature 003 that no code reaches** — a feature that claimed full
coverage of 89. They are listed in `KNOWN_GAPS` with the date, printed on every build, and **any new
gap fails the build**. They are not declared declined, because FlightDeck does not decline them; it
simply never calls them:

```
oauth2/resource-server/mapping (GET, PUT, DELETE), oauth2/resource-server/mappings,
oauth2/revoke, POST oauth2/server/client, POST oauth2/client/server-definition,
encryption/keys, encryption/data-element-keys, encryption/file/keys, encryption/file/admins,
audit/records, audit/event/clear-count, ldap/test, mft/connection/auth-code-url
```

The fourteen gaps of this feature were closed rather than listed: seven link providers (the three
namespace mapping families, database volumes, ECP databases, language-server activity, file-access
paths), the monitor dashboards block, and the task-info read.

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
| IRIS CE 2026.2 (port 52780) | 166/166, 37 classes | 114 passed, 16 skipped | safe mode ok; mutation ok |
| IRIS for Health 2026.2 (port 52792, project `fd-health`) | 166/166 | 114 passed, 16 skipped | safe mode ok; mutation ok |
| IRIS CE 2026.1 (port 52791, project `fd-v1`, limited mode) | 166/166 | 121 passed, 9 skipped | safe mode ok; mutation ok |

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

**Open decision for the reviewer:** the fifteen unreached operations of feature 003 are listed in
`scripts/build/check-coverage.py` as known gaps. Closing them is a feature-003 correction, not part
of this feature's scope; leaving them listed keeps them visible on every build.
