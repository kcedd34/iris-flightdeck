#!/usr/bin/env python3
"""The matrix must have run against three distinct products, and against this build (feature 008).

Two things had to be true and were assumed instead:

1. **That the three installs were three products.** They were not. `iris-flightdeck:local` had been
   overwritten by an IRIS for Health build and a container pinned to it, so the matrix reported for
   IRIS 2026.2, IRIS 2026.1 and IRIS for Health 2026.2 had in fact run IRIS for Health twice. The
   port was read as if it named the image. **A port is not an identity and neither is a docker tag**;
   only the instance's own answer is.

2. **That the instances were serving this build.** A rebuilt image on an existing volume does not
   update anything: `docker/first-start.sh` exits early on its marker, and `FlightDeck.UI.Static`
   serves from the manager directory inside the durable volume, not from the image. So a matrix can
   pass in full against assets built weeks ago. This is the same shape as the double-encoded assets
   that shipped from feature 001 to 007: the suite was green about something it never fetched.

Evidence comes from `frontend/e2e/setup/identity.ts`, which asks `/api/admin/info` what the instance
is and hashes the bundle that instance actually served, once per Playwright run, before any fixture
touches it. This gate reads those records and requires all three expected installs, each serving the
committed `frontend/dist`.

**This gate detects and fails. It never repairs anything.** It starts no container, rebuilds no image
and runs no test; it reports what the last runs prove and what they do not.

**What it does not prove.** The record is written by the run's global setup, so it says *which
instance a run addressed and what that instance served* — not that the whole suite ran, nor that it
passed. A single-project run writes a record just like a full matrix does. That is deliberate: this
gate answers the question that was answered wrongly for weeks, and inventing a completeness claim it
cannot check would repeat the original mistake in a new place. Completeness stays where it already
is: the suite's own exit code and the counts recorded in verification/functional-coverage.md.

Usage: check-matrix-identity.py
Requires a full matrix first, the way check-functional-coverage requires a Playwright run.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / "frontend" / ".matrix" / "instances.ndjson"
EXPECTED = ROOT / "scripts" / "build" / "matrix-installs.json"
DIST = ROOT / "frontend" / "dist" / "assets"


def committed_bundle():
    """The bundle this working tree would install, by the same hash the run records."""
    candidates = sorted(DIST.glob("index-*.js"))
    if len(candidates) != 1:
        return None, f"expected exactly one index-*.js in {DIST.relative_to(ROOT)}, found {len(candidates)}"
    data = candidates[0].read_bytes()
    return (candidates[0].name, hashlib.sha256(data).hexdigest()), None


def records():
    """The latest record per (product, apiVersion, release), newest wins."""
    if not RECORD.exists():
        return None
    latest = {}
    for line in RECORD.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        release = release_of(entry.get("serverVersion", ""))
        key = (entry.get("product"), entry.get("apiVersion"), release)
        if key not in latest or entry.get("at", "") >= latest[key].get("at", ""):
            latest[key] = entry
    return latest


def release_of(server_version):
    """`IRIS for UNIX (...) 2026.2 (Build 221U) ...` -> `2026.2`."""
    found = re.search(r"\b(\d{4}\.\d+)\b", server_version or "")
    return found.group(1) if found else ""


def main():
    expected = json.loads(EXPECTED.read_text(encoding="utf-8"))["installs"]
    seen = records()
    if seen is None:
        print(
            f"check-matrix-identity: no run record at {RECORD.relative_to(ROOT)}.\n"
            "  This gate reads what the matrix actually ran against. Run it first, once per install:\n"
            "    cd frontend && FLIGHTDECK_PORT=<port> FD_CONTAINER=<container> npx playwright test",
            file=sys.stderr,
        )
        sys.exit(1)

    bundle, error = committed_bundle()
    if error:
        print(f"check-matrix-identity: {error}", file=sys.stderr)
        sys.exit(1)
    name, sha = bundle

    problems = []
    for want in expected:
        key = (want["product"], want["apiVersion"], want["release"])
        got = seen.get(key)
        if got is None:
            problems.append(
                f"{want['label']} never ran: no record of product={want['product']} "
                f"apiVersion={want['apiVersion']} release={want['release']} "
                f"(build it from {want['image']})"
            )
            continue
        if got.get("servedSha256") != sha:
            problems.append(
                f"{want['label']} ran against a different build: it served {got.get('servedBundle')} "
                f"(sha {str(got.get('servedSha256'))[:12]}…) while this tree holds {name} (sha {sha[:12]}…). "
                "A rebuilt image on an existing volume keeps serving the old assets; reinstall it with "
                "an empty volume (docker compose -p <project> down -v, then up -d --build)."
            )

    wanted_keys = {(w["product"], w["apiVersion"], w["release"]) for w in expected}
    for key, entry in sorted(seen.items(), key=lambda kv: str(kv[0])):
        if key not in wanted_keys:
            problems.append(
                f"an install ran that is not one of the three: product={key[0]} apiVersion={key[1]} "
                f"release={key[2]} at {entry.get('origin')}. Either it belongs in matrix-installs.json "
                "with its reason, or it should not be in the matrix."
            )

    if problems:
        for problem in problems:
            print(f"check-matrix-identity: {problem}", file=sys.stderr)
        print(
            f"check-matrix-identity: {len(problems)} of {len(expected)} installs are not proven "
            "to have run against this build",
            file=sys.stderr,
        )
        sys.exit(1)

    print(
        f"check-matrix-identity: ok ({len(expected)} distinct installs, each serving {name}; "
        "product and apiVersion read from the instance, not from the port)"
    )


if __name__ == "__main__":
    main()
