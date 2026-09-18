# Feature 005 sign-off (T073, T074), 2026-09-18

The unified log stream: five sources under one normalised event, merged, filtered, followed live,
correlated and exported, with the journal and the audit event definitions as configuration beside
them. This is the only mandatory axis of the brief with no official API coverage. Run from the
working tree; nothing is committed.

## Static gates

| Gate | Result |
|---|---|
| `scripts/build/check-generated.sh` | up to date; `check-descriptors` ok (50 entity types, 142 mutations); `check-secrets` ok (54 candidate fields, 21 declared, 42 exempted); **`check-coverage` ok (268 operations across 6 shipped domains, 11 declined)** |
| `scripts/build/check-dist.sh` | up to date; `check-no-fixtures` ok |
| `npm run lint` | clean |
| `npm run check:tokens` | ok |
| `npm run check:dialect` | ok (11 declared exceptions) |
| `npm run check:mutation-boundary` | ok (3 declared exceptions) |
| `npm run check:secrets` | ok |
| `npm run contrast` | ok, both themes |
| `npm run test` (Vitest) | 18/18 |
| `npm run build` | ok |

`check-coverage` carries **no tolerated-gap list**: it was emptied at the end of feature 004 and the
14 operations of the logs domain were added to its count here. Before the work started it named all
14 as unreached, which is the check that proves it counts them (T004).

## SC-003: a 100 MB file is paged without the process growing with it

**The quickstart's own step was wrong and is corrected.** Growing the instance's `messages.log` to
100 MB does not hold: IRIS rotates it at `MaxConsoleLogSize` (5 MB by default), so on the next line
the instance writes it is copied to `messages.old_<date>` and replaced by a fresh 322-byte file — and
the measurement then reads the fresh one. That rotation was observed here, at 102 MB. Raising the
setting to defeat it would be tampering with the instance's logging, so §6 now measures the reader on
a file built for the purpose.

Measured on IRIS CE 2026.2, `/tmp/big-messages.log`, **102,588,896 bytes**:

| Reading | Result |
|---|---|
| 400 consecutive pages | 80,000 lines in **0.710 s**; first page 1.9 ms, slowest page 2.7 ms |
| Partition memory | 116,528 bytes before → 150,336 bytes after — the last page's own object, not the file |
| One page at the newest offset (102,588,896) | 200 lines, 2.1 ms |
| One page in the middle (51,294,448) | 200 lines, 1.9 ms |
| One page at the oldest offset (200,000) | 200 lines, 2.4 ms |

A page costs the same wherever it sits in a 100 MB file, and the process does not grow with it. The
bound lives in the reader (`WINDOW` 65,536 bytes, `LINES` 200), not in its callers, so it cannot be
opted out of by a caller that never sees the stream.

## What the full suite found

Two regressions this feature introduced elsewhere, and one latent defect, all caught by running every
project rather than the new one:

**The logs domain gained section tabs, and `shell.spec.ts` still had logs as the exception.** It
asserted zero tabs on logs and a "Not available in this build yet" placeholder — both true in
feature 001 and false now. The test now asserts what its own title says, for every domain, and that
**no** section anywhere still carries the placeholder. Every domain in the rail is built.

**An ARIA violation that only the logs route was slow enough to expose.** The glareshield's vitals
render a skeleton while the first reading arrives, and that skeleton is a bare `<span>` carrying
`aria-label="Loading"` — an attribute ARIA prohibits on an element with no role (axe
`aria-prohibited-attr`). It had been latent since feature 001 and appeared here because the logs
route takes long enough for the skeleton to still be on screen when axe runs. The skeleton is now
`aria-hidden`, and the reading's own element carries the state in its label: the name says
"reading it now" while pending and carries the reason when a vital is unavailable, so a screen
reader gets the fact rather than a labelled blank.

**React was dropping a link row.** `LinksPanel` keyed rows by entity type and display name, and the
same entity legitimately appears twice in one group through two different grants — the permissions
resource inspector showed `wallet-collection:FD_Demo_Vault` twice. React warned and the behaviour on
a duplicate key is to duplicate or omit. Rows are now keyed by position, which is safe here: the
order is the server's and the rows hold no state.

## The pattern catalog gained the two honest-gap states (T065)

A live instance cannot be asked, on demand, for an event whose original record is gone or for a line
that did not parse. Both now live in the catalog beside the feature-004 instrument cases, and the
`fixtures` project asserts them: the gap replaces the record and not the event, and the unparsed line
is shown whole with a field it never carried marked absent rather than defaulted.

## Fresh installs

Each was `docker compose down -v` then `up -d --build`, with the demo, then the whole backend suite,
every Playwright project and both enforcement scripts. One install at a time.

| Install | Backend `%UnitTest` | Playwright | Enforcement |
|---|---|---|---|
| IRIS CE 2026.2 (port 52780) | **189/189**, 42 classes | **130 passed, 18 skipped** | safe mode ok; mutation ok |
| IRIS for Health 2026.2 (port 52792, project `fd-health`) | **189/189** | **130 passed, 18 skipped** | safe mode ok; mutation ok |
| IRIS CE 2026.1 (port 52791, project `fd-v1`, limited mode) | **189/189** | **139 passed, 9 skipped** | safe mode ok; mutation ok |

Every skip states its reason. The 2026.1 install runs nine more tests than the other two because the
`limited` project only applies there; the eighteen it skips on 2026.2 are that project.

### Capability counts

| Install | allowed | unavailable (this version) | declined (policy) | total |
|---|---|---|---|---|
| IRIS CE 2026.2 | 262 | 0 | 11 | 273 |
| IRIS for Health 2026.2 | 262 | 0 | 11 | 273 |
| IRIS CE 2026.1 | 200 | 62 | 11 | 273 |

Unchanged from feature 004: this feature adds no declined operation and no new native provider that
the capability map has to account for. The 14 logs operations were already counted; they are now
reached.

### Limited mode on IRIS 2026.1 (T072)

Two tests were added to `limited.spec.ts` and both pass on that install:

- **The journal source states the reason and the other four keep streaming.** The capability map
  withholds `GET /v2/journal/files` on the v1 dialect, the source is listed unavailable with the
  reason feature 001 recorded, no "every source is out" line appears, and the stream still renders
  events from the sources that answered. Nothing here reads a version: the test asserts the
  capability map's answer and the screen's, and they agree.
- **The journal section states the reason instead of an empty list**, because an empty list would
  read as "this instance has no journal files", which is a different and false statement.

### What the five sources look like on a stock install

On the fresh CE 2026.2 install, all five sources answered: audit 40 events, messages 40, journal 10,
alerts 1, interoperability 0 — the last naming the namespace it read (`USER`) rather than staying
silent about having found nothing. The per-source share was 40, so no source could fill the page on
its own, and the screen says so. Severities came out 39 `info`, 1 `warning` and 51 `unknown`: the
audit and journal records state no level, and `unknown` is what a source that states no level gets.

This install **did** write an alerts log, so that source was available here. Its absent path is the
one a stock instance usually shows and is covered by the `logs` project, which skips with a stated
reason where the install does not present the condition.


## Result

Feature 005 is complete: **74 of 74 tasks**. The matrix is green on IRIS CE 2026.2, IRIS for Health
2026.2 and IRIS CE 2026.1, from fresh installs, with the same backend suite and the same Playwright
projects on each. Nothing is committed; the working tree carries the changes.

The six domains are now all built. `check-coverage` counts **268 operations across 6 shipped
domains** with 11 declined and **no tolerated-gap list**, so every operation of every shipped domain
is reachable or declined for a stated reason.

The quickstart was run end to end and three steps were corrected where they did not work as written:
§5 (the record key needs URL-encoding, and the stream is where the key comes from), §6 (the
instance's own messages log rotates at 100 MB, so the reader is measured on a file built for it), and
§8 (applying a mutation needs a session cookie and the preview's fingerprint, so it is done in the
portal rather than with a pasted curl).

The README now describes the log stream and what it deliberately is not: FlightDeck reads logs, it
does not store, index or forward them.

