#!/usr/bin/env bash
# Load and compile backend/cls (and backend/test) into a dev container at /opt/flightdeck.
# Exit 1 and print the compiler output if anything fails.
#
# The image carries its own copy of the repository, so the working tree is copied in first. Without
# that, this script silently loads whatever the image was built with and reports success, and the
# change under test never runs (feature 003 lost an hour to exactly this).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
ns="${1:-USER}"
container="${FD_DEV_CONTAINER:-fd-dev}"
docker cp "$root/backend/." "$container:/opt/flightdeck/backend/" >/dev/null
out="$("$here/iris.sh" "$ns" <<'OS'
set sc = $system.OBJ.LoadDir("/opt/flightdeck/backend/cls", "ck-d", .errors, 1)
// A test class that does not parse must fail the load: otherwise the container keeps running the
// last version that compiled, and the suite reports a stale result (feature 003).
set scTest = $system.OBJ.LoadDir("/opt/flightdeck/backend/test", "ck-d", .errors2, 1)
if sc, 'scTest set sc = scTest
if sc set sc = ##class(FlightDeck.Install.Installer).DeployCapture()
write "FD-LOAD-STATUS=", +sc, " errors=", +$get(errors), !
if 'sc do $system.Status.DisplayError(sc)
OS
)"
echo "$out" | grep -E "ERROR|FD-LOAD-STATUS|Compilation finished" || true
echo "$out" | grep -q "FD-LOAD-STATUS=1" || { echo "$out"; exit 1; }
