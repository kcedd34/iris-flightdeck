#!/usr/bin/env bash
# Runs the backend %UnitTest suite in a container where the repository is at /opt/flightdeck.
# Usage: scripts/dev/test-backend.sh [TestClassShortName]   e.g. AdminClient (default: all)
# Prints passed/total per class and exits 1 on any failure or when no test ran at all.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
case_filter=""
[ -n "${1:-}" ] && case_filter=":FlightDeck.Test.$1"
out="$("$here/iris.sh" USER <<OS
set ^UnitTestRoot = "/opt/flightdeck/backend/test"
set sc = \$system.OBJ.LoadDir("/opt/flightdeck/backend/test", "ck-d", , 1)
set sc = ##class(%UnitTest.Manager).RunTest("FlightDeck/Test${case_filter}", "/noload/nodelete/norecursive")
set result = \$get(^UnitTest.Result), failed = 0, methods = 0, suite = ""
for { set suite = \$order(^UnitTest.Result(result, suite)) quit:suite=""  set case = "" for { set case = \$order(^UnitTest.Result(result, suite, case)) quit:case=""  set m = "", n = 0, ok = 0, bad = "" for { set m = \$order(^UnitTest.Result(result, suite, case, m)) quit:m=""  set n = n + 1, methods = methods + 1 if \$listget(^UnitTest.Result(result, suite, case, m), 1) { set ok = ok + 1 } else { set failed = failed + 1, bad = bad _ " " _ m } } write "FD-CASE ", case, " ", ok, "/", n, bad, ! } }
write "FD-TEST-METHODS=", methods, " FD-TEST-FAILED=", failed, !
OS
)"
echo "$out" | grep -aE "FD-CASE|FD-TEST|\(failed\)" || true
echo "$out" | grep -qE "FD-TEST-METHODS=[1-9][0-9]* FD-TEST-FAILED=0" || exit 1

# Without a filter, every test class in the repository must have run on this instance. A reduced
# set is how FlightDeck.Test.CapabilityMap went unrun on IRIS 2026.1 through all of feature 001,
# hiding a real failure; a class missing here also means the container copy is stale.
if [ -z "$case_filter" ]; then
  missing=""
  for file in "$here/../../backend/test/FlightDeck/Test"/*.cls; do
    grep -q "Method Test" "$file" || continue   # abstract support classes have no test methods
    name="FlightDeck.Test.$(basename "$file" .cls)"
    grep -qa "FD-CASE $name " <<<"$out" || missing="$missing $name"
  done
  if [ -n "$missing" ]; then
    echo "test-backend: these test classes did not run on this instance:$missing"
    echo "test-backend: load them first (scripts/dev/load-backend.sh, or docker cp backend/. <container>:/opt/flightdeck/backend/)"
    exit 1
  fi
fi
