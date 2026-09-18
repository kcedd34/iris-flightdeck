# Quickstart: Validating Feature 006

**Feature**: `006-packaging-submission`

Runnable checks that prove the packaging end to end. Contract:
[`contracts/readme-contract.md`](./contracts/readme-contract.md). Record shapes:
[`data-model.md`](./data-model.md). Findings: [`research.md`](./research.md).

## 0. Prerequisites

The prerequisites of features 001 to 005 (Docker Engine, Node 20), and nothing else. This feature's
whole point is that a reader needs nothing the README does not name.

## 1. The README gate

```bash
scripts/build/check-readme.py
scripts/build/check-generated.sh     # the gate also runs here, with the others
```

Expected: `check-readme: ok (10 elements, in order; …)`. While the Ideas Portal URL is still an
author action, the gate prints a warning naming it and still passes — a pending author action is not
a build failure, but it must never be silent.

**Prove the gate bites** before trusting it: move one required section below another, and confirm it
fails naming both neighbours; change a compatibility count, and confirm the arithmetic check fails.

## 2. The documentation images

```bash
cd frontend && FLIGHTDECK_PORT=52780 FD_CONTAINER=iris-flightdeck-iris-1 \
  npx playwright test --project=docs
```

Expected: `docs/img/instruments.png` and `docs/img/dry-run.png` are written from the running portal,
with live readings and a real impact analysis. If a screen or its test id no longer exists, the
capture **fails** rather than leaving the previous file in place.

Then confirm nothing secret was photographed:

```bash
cd frontend && FLIGHTDECK_PORT=52780 npx playwright test --project=audit
```

## 3. The demo driver, at the portal's real speed

```bash
cd frontend && FLIGHTDECK_PORT=52780 FD_CONTAINER=iris-flightdeck-iris-1 \
  npx playwright test --project=demo --headed
```

Expected: the portal is driven through `docs/demo-script.md` in order, starting on the instrument
cluster with live readings, then the dry-run before anything is applied, then the six domains, then
the log stream with more than one source in one list.

**The check that matters**: the elapsed time the driver reports for each shot must match the elapsed
time of that operation performed by hand. No wait is shortened, stubbed, skipped or simulated
(FR-019a). A run that finishes noticeably faster than the script's stated timings is a defect in the
driver, not a faster portal.

## 4. Installation from clean, both Community images

One image at a time, from nothing — no cached volumes, nothing from a previous run.

```bash
docker compose down -v
docker compose up -d && scripts/dev/wait-ready.sh 600

docker compose down -v
IRIS_IMAGE=intersystemsdc/irishealth-community:2026.2-zpm docker compose up -d --build \
  && scripts/dev/wait-ready.sh 600
```

Run **the README's own commands**, not these, if the two ever differ — the README is the artifact
under test. Record each run in `verification/install-runs.md` with the shape `data-model.md` §1 gives,
reading the version and the capability summary from the portal rather than from the tag.

Expected: each reaches a signed-in portal; every domain screen shows content on first access.

## 5. The port-conflict path

```bash
# occupy the port, then follow the README's instructions verbatim
python3 -m http.server 52780 &
docker compose up -d           # expected to fail, with the message the README quotes
FLIGHTDECK_PORT=52790 docker compose up -d && scripts/dev/wait-ready.sh 600
kill %1
```

Expected: the failure message matches what the README quotes, and the documented alternative works
without editing any file the instructions do not name.

## 6. The IPM path

The one install path no gate covers (research R7). On an instance that is **not** the container build:

```objectscript
zpm "load /path/to/iris-flightdeck"
zpm "iris-flightdeck test"
```

Expected: the two web applications, the runtime role and the capture routine are created and nothing
else; demonstration objects are **absent**, because they are off by default on this path. Then with
`-DDemo=1`, they appear. If any of this differs from the README, the README is wrong.

## 7. The compatibility claims, on both versions

```bash
curl -s -u "$FD_VERIFY_USER:$FD_VERIFY_PASSWORD" -H 'X-FlightDeck-Tab: qs' \
  http://localhost:52780/api/flightdeck/v1/session | python3 -m json.tool | head -20
```

Expected: `capabilitySummary` and `instance` match what the README's compatibility section claims for
that version, number for number. Repeat against the 2026.1 install. A mismatch is a README defect.

## 8. The cold read

**Agent pass**: a session with no project context, given the repository and the README only, performs
§4 and records every question it cannot answer from the README. Each becomes a README change. Repeat
until a pass raises none.

**Human pass**: a reader who knows IRIS and has never seen FlightDeck, timed from first opening the
repository page to a signed-in portal with content on every domain screen. Record it in
`verification/cold-read.md` with the shape `data-model.md` §2 gives.

Expected: under 10 minutes (SC-001), zero unanswered questions (SC-005).

## 9. The conformance checklist

Read `docs/contest.md` §7 straight through.

Expected: every line is closed with a pointer to its evidence, or marked as an author action with
what it needs and its deadline. No line is ticked without a pointer, and no line is blank.
