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

Expected: `check-readme: ok (9 elements, in order)`. The Ideas Portal link was element 9 and was
removed from the README on 2026-09-20, together with its check; the licence moved up to 9. If the
idea is ever published, the section and its check go back together.

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

### Why `down -v` is not optional, and what happens without it

`docker compose up -d --build` on an **existing** volume rebuilds the image and changes nothing the
user can see. Two mechanisms, both by design, combine into one trap:

- `docker/first-start.sh` exits early if `$ISC_DATA_DIRECTORY/flightdeck.installed` is present. It
  prints `FlightDeck already installed.` and the ready line, which read like success.
- `FlightDeck.UI.Static` serves from `<ManagerDirectory>/flightdeck/web`, inside the durable volume —
  not from `/opt/flightdeck/frontend/dist` in the image. The image's copy is only the source the
  installer reads once.

So a rebuilt image on a kept volume **keeps serving the previous bundle**, and every check in this
quickstart passes against assets that are not the ones in the working tree. That is how a full matrix
ran green across three installs while all three served a bundle four UX fixes older than the working
tree — and nothing in the run could have said so, because every UI project addresses the Vite dev
server and the two that address the IRIS origin test delivery and the API, not the screen.

Two consequences for anyone verifying:

1. **Every verification install starts from an empty volume.** `docker compose -p <project> down -v`
   before `up -d --build`, per install, every time. The `-v` is the whole instruction; without it the
   run measures history.
2. **Confirm what was served, not what was built.** The bundle the instance answers with is the
   evidence:

   ```bash
   curl -s http://localhost:52780/flightdeck/ | grep -o '/flightdeck/assets/index-[^"]*\.js'
   curl -s http://localhost:52780/flightdeck/assets/index-XXXX.js | sha256sum
   sha256sum frontend/dist/assets/index-*.js      # must match
   ```

   `scripts/build/check-matrix-identity.py` does exactly this for all three installs and fails when
   any of them served something else. Run it after the matrix.

This is not a defect to fix in the installer: re-running an install over a live instance would
destroy state a user may want. It is a fact about the install path that has to be written down,
because the failure it produces looks like success.

### Proving the three installs were three products

The port does not identify the product and the docker tag does not either: `iris-flightdeck:local` is
a single tag, and building for IRIS for Health overwrites it, after which a container created from it
answers on whatever port compose gave it. Ask the instance:

```bash
for p in 52780 52791 52792; do
  curl -s -u _SYSTEM:SYS "http://localhost:$p/api/admin/info" \
    | python3 -c "import sys,json;r=json.load(sys.stdin)['result'];print(r['product'], r['apiVersion'], r['serverVersion'][:60])"
done
```

Expected: three distinct answers matching `scripts/build/matrix-installs.json`. Build each with its
own base image and tag it, so the next reader can tell them apart:

```bash
IRIS_IMAGE=intersystemsdc/iris-community:2026.2-zpm     docker compose -p iris-flightdeck up -d --build
IRIS_IMAGE=intersystemsdc/iris-community:2026.1-zpm     docker compose -p fd-v1     up -d --build
IRIS_IMAGE=intersystemsdc/irishealth-community:2026.2-zpm docker compose -p fd-health up -d --build
```

`scripts/build/check-matrix-identity.py` fails naming any install that did not run.

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
