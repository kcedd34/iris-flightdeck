#!/usr/bin/env bash
# Runs the backend %UnitTest suite in a dev container where the repo is mounted at /opt/flightdeck.
# Usage: scripts/dev/test-backend.sh [TestClass]   (default: all of FlightDeck.Test)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
spec="${1:-}"
out="$("$here/iris.sh" USER <<OS
set ^UnitTestRoot = "/opt/flightdeck/backend/test"
set sc = \$system.OBJ.LoadDir("/opt/flightdeck/backend/test", "ck-d", , 1)
set spec = "FlightDeck/Test$( [ -n "$spec" ] && echo ":$spec" )"
set sc = ##class(%UnitTest.Manager).RunTest(spec, "/noload/nodelete/norecursive")
set result = \$get(^UnitTest.Result)
set failed = 0
set suite = ""
for { set suite = \$order(^UnitTest.Result(result, suite)) quit:suite=""  set case = "" for { set case = \$order(^UnitTest.Result(result, suite, case)) quit:case=""  if '\$listget(^UnitTest.Result(result, suite, case), 1) { set failed = failed + 1 } } }
write !, "FD-TEST-FAILED=", failed, !
OS
)"
echo "$out" | grep -aE "Passed|Failed|FAILED|AssertEquals|AssertTrue|AssertStatus|FD-TEST" | grep -avE "^\s*$" | tail -60
echo "$out" | grep -q "FD-TEST-FAILED=0" || exit 1
