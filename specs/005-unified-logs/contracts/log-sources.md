# Source contract — feature 005

What a source must provide to join the unified stream. Five exist today; a sixth would implement this
and nothing else. Sources are declared as data (spec FR-034); this document is what that data means.

---

## 1. What a source declares

| Field | Meaning |
|---|---|
| `id` | `audit`, `journal`, `messages`, `alerts`, `interop` |
| `label` | What the filter shows |
| `operations` | The official operations it calls, so the capability map can decide its availability |
| `severityMap` | How the source's own levels map onto info, warning, error, fatal |
| `correlates` | Which of process, namespace, user it can provide |
| `kind` | `api` (official operation), `file` (read backwards) or `sql` (per namespace) |

A source never declares a privilege: availability comes from the capability map, as everywhere else
(Constitution III).

## 2. What a source answers

```
Page(window, cursor, limit) -> { events, cursor, available, reason, read, suppressed, unread }
```

Rules every source obeys, whatever its kind:

1. **Newest first.** The merge orders across sources; each source is asked for its own newest.
2. **Bounded.** `limit` is a cap the source respects, and `suppressed` says how many it had beyond it.
   Nothing is dropped silently (spec FR-018).
3. **`raw` on every event.** Where the original cannot travel with the event, the source sets
   `rawAvailable: false` with the reason, and the event still appears (spec FR-004, FR-005).
4. **Absent is absent.** A field the source does not have is omitted, not defaulted. `severity` is the
   one exception, because the schema requires it: a source that states no level answers `unknown`,
   which is a value meaning "the source did not say" (spec FR-003a).
5. **Unavailable says why.** A source that cannot be read answers `available: false` with the
   platform's own words, and — where the instance can enable it — where that is done (spec FR-010,
   FR-011). It never answers an empty page, which would read as "nothing happened".
6. **Its own timestamps.** A source converts nothing: the instance's zone is stated once by the page.

## 3. `kind: file` — reading backwards (RN-FD-25)

The reader is shared by `messages` and `alerts`; a new file source reuses it.

- Seek to `size − (page × window)`, read one `window`, split lines, **discard the first line** (it
  belongs to the earlier page).
- `size` and `modified` are captured on the first page and carried in the cursor; a file that grew
  does not shift pages already served (spec FR-015).
- If `size` or `modified` moves backwards, stop and report `fileChanged` rather than mixing two files
  (spec FR-014).
- The whole file is never read, at any size (spec FR-013). `window` and `limit` are declared caps.
- A line that does not match the source's shape becomes an event with `parsed: false`, the line as its
  message, and the gap stated (spec FR-006).

## 4. `kind: sql` — per namespace

- One bounded query per namespace, over every namespace the source applies to, up to a declared cap.
- The page names the namespaces it read and those the cap or a refusal left out (`namespaces`,
  `unread`). A namespace the session may not read is named, not skipped (spec FR-011a).

## 5. `kind: api` — official operations

- Reads go through the dialect layer like every other official call; an operation the version does not
  offer makes the source unavailable with the map's reason, and the other sources keep streaming.
- An operation that answers asynchronously (audit records, journal records) uses
  `FlightDeck.Async.Runner` from feature 004 — fired and polled, with the last known page kept on
  screen while the next is fetched. No source writes a polling loop of its own.

## 6. What a source must never do

- Infer a severity the source did not state, from the text or from anything else.
- Return an empty page to mean "unavailable".
- Read a whole file.
- Drop an event it could not parse.
- Reach outside its own data to fill a field (a journal record names a database, not a namespace, so
  its `namespace` stays absent).
