# Quickstart: Validating Feature 004

**Feature**: `004-tasks-system`

Runnable checks that prove the feature end to end. Contracts:
[`contracts/flightdeck-api-004.openapi.json`](./contracts/flightdeck-api-004.openapi.json) and
[`contracts/ui-pattern-delta.md`](./contracts/ui-pattern-delta.md). Data shapes:
[`data-model.md`](./data-model.md). Decisions and probes: [`research.md`](./research.md).

## 0. Prerequisites

- The prerequisites of features 001 to 003 (Docker Engine, Node 20).
- A fresh install with the demo:

```bash
docker compose down -v && docker compose up -d --build && scripts/dev/wait-ready.sh 600
```

- For the other two installs, each under its own compose project, told which container to wait on:

```bash
IRIS_IMAGE=intersystemsdc/iris-community:2026.1-zpm FLIGHTDECK_PORT=52791 \
  docker compose -p fd-v1 up -d --build && FD_CONTAINER=fd-v1-iris-1 scripts/dev/wait-ready.sh 600
IRIS_IMAGE=intersystemsdc/irishealth-community:2026.2-zpm FLIGHTDECK_PORT=52792 \
  docker compose -p fd-health up -d --build && FD_CONTAINER=fd-health-iris-1 scripts/dev/wait-ready.sh 600
```

The container carries its own copy of the repository: after changing backend code, rebuild the image
(`up -d --build`). `scripts/dev/load-backend.sh` only reaches a container that mounts the working
tree.

## 1. Static gates

```bash
scripts/build/check-generated.sh     # capability data, OpenAPI class, descriptors, secret fields,
                                     # and check-coverage: every operation of a shipped domain is
                                     # reachable or declined
scripts/build/check-dist.sh
cd frontend
npm run lint && npm run check:tokens && npm run check:dialect && npm run check:mutation-boundary \
  && npm run check:secrets && npm run contrast && npm run test && npm run build
```

Expected: all pass. `check:dialect` must still pass with the asynchronous helper in place: the
platform's `LOCATION` header names `/v1/async-result` even on v2 (research R6), and only the dialect
layer may see that string. `check-coverage` prints the operations an earlier feature left unreached
(fifteen from feature 003) and fails on any new one.

## 2. Backend tests

```bash
FD_DEV_CONTAINER=iris-flightdeck-iris-1 scripts/dev/test-backend.sh
```

Expected: every class runs and passes, including the composed task list with its history band, the
asynchronous helper's state machine, the process capability facts, the self-protection rule for the
session's own process, and the three declined storage writes.

## 3. End-to-end

```bash
cd frontend && FLIGHTDECK_PORT=52780 FD_CONTAINER=iris-flightdeck-iris-1 npx playwright test
```

Run one suite at a time: every run serves the frontend on the same port, so two runs against
different installs answer from whichever dev server started first.

Expected: the projects of features 001 to 003 keep passing, plus `instruments`, `processes`, `tasks`
and `system`. Several tests skip with a stated reason where the install does not present their
condition — no terminable process other than the one serving the request, no recorded failed run,
or a section this version does not offer. A skip with a reason is the expected outcome there, not a
gap.

## 4. The cluster is alive (UC08-1)

1. Open the operating system domain; the instruments section is the landing section.
2. Watch for sixty seconds.

Expected: the numbers change, each series slides without per-point animation, the three instruments
share one geometry, and a crossed threshold changes colour and shows an icon without blinking. Switch
to another tab and back: the window is still there and telemetry resumed.

## 5. The disk number never disappears (UC08-2, SC-004)

```bash
# fire the platform's asynchronous task by hand and watch the handle arrive in the header
curl -s -D - -o /dev/null -u "$FD_VERIFY_USER:$FD_VERIFY_PASSWORD" \
  -X POST "http://localhost:52780/api/admin/v2/database-dir/info?dir=/durable/iris/mgr/" | grep -i location
# -> LOCATION: /api/admin/v1/async-result?id=<handle>
```

Then, in the portal, watch the disk instrument across several refreshes.

Expected: the number is never blank and never replaced by a loading indicator; while a refresh is in
flight the last known value stays, and a value older than the interval is marked stale with the time
it was read.

## 6. The API decides which process controls are enabled (UC08-3, SC-005)

1. Open the processes section and find a row whose terminate control is disabled.
2. Open the browser's network view and confirm no request is issued when it is clicked.

Expected: the control is disabled with the reason the API gave, and `CanBeTerminated`,
`CanBeSuspended`, `CanReceiveBroadcast` and `CanBeExamined` come from the list itself (research R5).

## 7. Terminating is maximum grade, and the session's own process is refused (UC08-4, SC-006)

1. Disarm safe mode, choose a terminable process, and terminate it: the identifier must be typed.
2. Then try the process running your own session.

```bash
# the server refuses it even when the request bypasses the interface
curl -s -b "$COOKIE" -H 'X-FlightDeck-Tab: qs' -H 'X-FlightDeck-Safe-Mode: disarmed' \
  -H 'Content-Type: application/json' -X POST http://localhost:52780/api/flightdeck/v1/mutations/apply \
  -d '{"operationId":"POST /v2/process/terminate","keys":{"id":"<own pid>"},"confirmation":"<own pid>"}'
# -> 403 SELF_PROTECTION, with the explanation
```

Which process that is changes between requests: IRIS serves consecutive requests from different
processes, so read the list again before choosing one. The list marks the process serving that very
request ("Serving this request"), and the block is re-evaluated on the object the mutation re-reads.

## 8. Tasks: the band, the failure and the concurrent run (UC07-1, UC07-3)

1. Open the tasks domain and read the list.
2. Open a failed run's detail.
3. Run a task on demand; while it is running, try to run it again.

Expected: the recent-history band is visible in the list without opening anything (RN-FD-17); the
failed run shows the complete message; the second run is refused with the start time of the run in
flight. The list costs one history read, not one per task (research R7).

## 9. The jump to logs carries the correlation (UC07-2, SC-012)

From a failed run, use the jump control.

Expected: the address becomes
`/logs/stream?taskId=<id>&taskName=<name>&from=<start-1m>&to=<end+1m>` — the logs domain's entry
section, which exists today — and that route's empty state states what it received. Feature 005 will
consume these parameters unchanged.

## 10. The task manager is instance-wide (UC07-4)

Suspend the task manager.

Expected: reinforced confirmation whose text states the effect on the whole instance, the trail
records it, and the task list then states that the manager is suspended rather than showing every
task as merely idle.

## 11. Long storage operations say how long (SC-011)

Run an integrity check on a database directory.

Expected: the confirmation states the expected duration as well as the risk; the operation is fired
and polled, never issued synchronously; the domain stays usable while it runs and reports progress.

## 12. Declined writes read as decisions (spec FR-037a)

Open a database directory, a database and a namespace.

Expected: truncate, delete database and delete namespace are disabled with a reason that says what
FlightDeck does do (it creates both), why it declines the deletion, and the native path in the
platform's management portal. Nothing looks like missing work.

## 13. Matrix and sign-off

```bash
# IRIS CE 2026.2, IRIS for Health 2026.2, IRIS CE 2026.1 — one install at a time
FD_DEV_CONTAINER=<container> scripts/dev/test-backend.sh
cd frontend && FLIGHTDECK_PORT=<port> FD_CONTAINER=<container> npx playwright test
scripts/dev/check-safe-mode-enforcement.sh http://localhost:<port>
scripts/dev/check-mutation-enforcement.sh http://localhost:<port>
```

Expected: the same backend set on every version, every Playwright project green or skipped with a
stated reason, and both enforcement scripts refusing every mutating route while armed. Record it in
`verification/feature-004-signoff.md`.
