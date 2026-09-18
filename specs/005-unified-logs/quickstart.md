# Quickstart: Validating Feature 005

**Feature**: `005-unified-logs`

Runnable checks that prove the feature end to end. Contracts:
[`contracts/flightdeck-api-005.openapi.json`](./contracts/flightdeck-api-005.openapi.json) and
[`contracts/log-sources.md`](./contracts/log-sources.md). Data shapes:
[`data-model.md`](./data-model.md). Decisions and probes: [`research.md`](./research.md).

## 0. Prerequisites

- The prerequisites of features 001 to 004 (Docker Engine, Node 20).
- A fresh install with the demo, and the other two installs each under its own compose project:

```bash
docker compose down -v && docker compose up -d --build && scripts/dev/wait-ready.sh 600
IRIS_IMAGE=intersystemsdc/iris-community:2026.1-zpm FLIGHTDECK_PORT=52791 \
  docker compose -p fd-v1 up -d --build && FD_CONTAINER=fd-v1-iris-1 scripts/dev/wait-ready.sh 600
IRIS_IMAGE=intersystemsdc/irishealth-community:2026.2-zpm FLIGHTDECK_PORT=52792 \
  docker compose -p fd-health up -d --build && FD_CONTAINER=fd-health-iris-1 scripts/dev/wait-ready.sh 600
```

The container carries its own copy of the repository: after changing backend code, rebuild the image
or use `scripts/dev/load-backend.sh`, which copies the working tree in first.

## 1. Static gates

```bash
scripts/build/check-generated.sh     # capability data, OpenAPI class, descriptors, secrets, coverage
scripts/build/check-dist.sh
cd frontend
npm run lint && npm run check:tokens && npm run check:dialect && npm run check:mutation-boundary \
  && npm run check:secrets && npm run contrast && npm run test && npm run build
```

Expected: all pass. `check-coverage` now counts the logs domain too: its 14 official operations must
be implemented or declined, and the gate carries no tolerated list.

## 2. Backend tests

```bash
FD_DEV_CONTAINER=iris-flightdeck-iris-1 scripts/dev/test-backend.sh
```

Expected: every class runs and passes, including the backwards file reader (paging, the discarded
partial line, rotation detection), each source's normaliser, the severity mappings, and the merge's
stable ordering.

## 3. End-to-end

```bash
cd frontend && FLIGHTDECK_PORT=52780 FD_CONTAINER=iris-flightdeck-iris-1 npx playwright test
```

Run one suite at a time. Expected: the projects of features 001 to 004 keep passing, plus `logs`.
Tests skip with a stated reason where an install does not present their condition — an instance that
writes no alerts log, or a version that withholds the journal.

## 4. One line, five sources (UC09-1)

1. Open the logs domain.
2. Read the list, then open one event from each source that is available.

Expected: every event shows the same fields; each opens to its original record; a source that could
not be read is named with its reason and the others keep streaming. An event whose source stated no
level shows `unknown`, not `info`.

## 5. The original record is always reachable (RN-FD-24, SC-002)

Take the three-part key from any audit event in the stream — it travels in every row — and read the
record from both sides. The timestamp contains a space, so the parameters must be URL-encoded;
`--data-urlencode` does it.

```bash
# the key as the stream gives it
curl -s -u "$FD_VERIFY_USER:$FD_VERIFY_PASSWORD" -H 'X-FlightDeck-Tab: qs' \
  "http://localhost:52780/api/flightdeck/v1/logs/events?limit=5&sources=audit" | head -c 400

# the same record from the official API
curl -s -u "$FD_VERIFY_USER:$FD_VERIFY_PASSWORD" -G \
  "http://localhost:52780/api/admin/v2/security/audit/record" \
  --data-urlencode "utcTimeStamp=<utcTimeStamp>" \
  --data-urlencode "systemID=<systemID>" \
  --data-urlencode "auditIndex=<auditIndex>" | head -c 200
```

Expected: both answer 200 with the same record, and the portal shows it for that event. Where an
original cannot be recovered, the event says so and still shows its normalised fields — there is no
third case. The pattern catalog holds that state permanently (`__fixtures__/pattern`), because a live
instance cannot be asked for it on demand.

## 6. A big file is never read whole (RN-FD-25, SC-003)

**Not on the instance's own messages log.** IRIS rotates it at `MaxConsoleLogSize` (5 MB by default),
so a log grown to 100 MB is copied to `messages.old_<date>` and replaced by a fresh one on the next
line the instance writes — and the measurement reads the fresh file. Changing that setting to keep
the big file is tampering with the instance's logging, which is not something this portal's own
validation should ask anyone to do. Measure the reader on a file built for it instead:

```bash
docker exec iris-flightdeck-iris-1 sh -c \
  'awk "BEGIN{for(i=1;i<=1700000;i++) printf \"09/18/26-05:00:00:000 (1) 0 [Quickstart] filler line %d\\n\", i}" > /tmp/big-messages.log; ls -la /tmp/big-messages.log'
```

```bash
FD_DEV_CONTAINER=iris-flightdeck-iris-1 scripts/dev/iris.sh USER <<'OS'
set file="/tmp/big-messages.log",size=##class(%File).GetFileSize(file)
write !,"file bytes ",size,"  used bytes start ",($zstorage*1024)-$storage
set cursor="",t0=$zhorolog,total=0,pages=0,maxms=0
for page=1:1:400 { set p0=$zhorolog,a=##class(FlightDeck.Logs.Reader).Page(file,cursor),ms=($zhorolog-p0)*1000 set:ms>maxms maxms=ms set cursor=a.cursor,total=total+a.lines.%Size(),pages=page quit:a.exhausted }
write !,"pages ",pages,", lines ",total,", elapsed ",$fnumber($zhorolog-t0,"",3)," s, slowest page ",$fnumber(maxms,"",1)," ms"
write !,"used bytes end ",($zstorage*1024)-$storage
OS
```

Then read one page at three depths — the newest, the middle and the oldest — by handing the reader a
cursor built from the offset (`<offset>|<size>|`).

Expected: every page costs the same wherever it sits in the file, and the process's partition memory
does not grow with it. Delete `/tmp/big-messages.log` afterwards. The end-to-end path is covered by
the `logs` project against the instance's real log.

## 7. Live follow, and what it suppresses (UC09-2, SC-004)

1. Turn on live follow.
2. Produce events faster than the limit (sign in and out repeatedly, or run the demo failing task).

Expected: new events appear at the top without reloading; the screen states how many were suppressed;
the window stays bounded; hiding the tab pauses the follow and returning resumes it.

## 8. Auditing disabled (UC09-3, SC-005)

Do this in the portal, not with curl: applying a mutation needs the session cookie **and** the
fingerprint the preview answers, so a single pasted command cannot stand on its own. In the security
domain's auditing section, turn safe mode off for the tab, switch auditing off through the shared
dry-run, then open the logs domain.

Expected: the other four sources keep streaming, and the audit source is listed with the reason and
where to enable it. Turn auditing back on afterwards. The `logs` project drives exactly this and puts
the instance back.

## 9. From an event to the entity (UC09-4, SC-006)

Open an event carrying a process identifier and use the jump.

Expected: the process's inspector opens in the operating system domain. An event naming a process the
instance no longer reports says so instead of offering a dead link.

## 10. The correlation contract from feature 004 (SC-007)

In the tasks domain, open a failed run and use "Open the logs of this period".

Expected: the stream opens filtered on that task and window, **and says so** on screen. This is the
contract feature 004 wrote and tested; this feature consumes it unchanged.

## 11. Export (SC-008)

Filter, then export.

Expected: the file carries exactly the events the filter selected, each with its original record, and
names the filters and the sources that were unavailable when it was taken.

## 12. Journal and audit events as configuration

1. Open the journal section: files, settings, switch file, switch directory, integrity check.
2. Open the audit events section.

Expected: every write goes through the shared dry-run; switching the file or directory states the
instance-wide effect; the integrity check is fired and polled with its expected duration stated; the
audit event definitions are here, and the security domain's auditing section links to them and back.

## 13. Matrix and sign-off

```bash
# IRIS CE 2026.2, IRIS for Health 2026.2, IRIS CE 2026.1 — one install at a time
FD_DEV_CONTAINER=<container> scripts/dev/test-backend.sh
cd frontend && FLIGHTDECK_PORT=<port> FD_CONTAINER=<container> npx playwright test
scripts/dev/check-safe-mode-enforcement.sh http://localhost:<port>
scripts/dev/check-mutation-enforcement.sh http://localhost:<port>
```

Expected: the same backend set on every version, every Playwright project green or skipped with a
stated reason, and both enforcement scripts refusing every mutating route while armed. On IRIS 2026.1
the journal source and section state the reason recorded in feature 001, and the other four sources
keep streaming. Record it in `verification/feature-005-signoff.md`.
