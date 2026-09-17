#!/usr/bin/env bash
# FR-015a / SC-002a: the FlightDeck API must reject every mutating request from an armed tab,
# with a missing or bogus safe-mode header, before routing. Needs a running install.
# Usage: scripts/dev/check-safe-mode-enforcement.sh [base-url]   (default http://localhost:52780)
set -uo pipefail
base="${1:-http://localhost:${FLIGHTDECK_PORT:-52780}}/api/flightdeck/v1"
user="${FD_USER:-_SYSTEM}"
pass="${FD_PASSWORD:-SYS}"
jar="$(mktemp)"
trap 'rm -f "$jar"' EXIT
fail=0

code=$(curl -s -o /dev/null -w '%{http_code}' -c "$jar" -b "$jar" -u "$user:$pass" -X POST \
  -H 'X-FlightDeck-Tab: enforcement-check' -H 'X-FlightDeck-Safe-Mode: armed' "$base/session")
[ "$code" = "200" ] || { echo "sign-in failed: HTTP $code"; exit 1; }

check() { # method path safe-header-or-NONE tab-header-or-NONE expected-code expected-error
  local args=(-s -o /tmp/fd-enf.$$ -w '%{http_code}' -b "$jar" -X "$1")
  [ "$4" != "NONE" ] && args+=(-H "X-FlightDeck-Tab: $4")
  [ "$3" != "NONE" ] && args+=(-H "X-FlightDeck-Safe-Mode: $3")
  local got; got=$(curl "${args[@]}" "$base$2")
  local body; body=$(cat /tmp/fd-enf.$$); rm -f /tmp/fd-enf.$$
  if [ "$got" = "$5" ] && grep -q "\"$6\"" <<<"$body"; then
    printf '  ok    %-6s %-26s safe=%-8s tab=%-4s -> %s %s\n' "$1" "$2" "$3" "$4" "$got" "$6"
  else
    printf '  FAIL  %-6s %-26s safe=%-8s tab=%-4s -> %s %s\n' "$1" "$2" "$3" "$4" "$got" "$body"
    fail=1
  fi
}

echo "Safe-mode enforcement against $base"
for method in PUT POST PATCH DELETE; do
  for path in /session/capabilities /vitals /palette/entities /nothing; do
    for safe in armed NONE bogus DISARMED; do
      check "$method" "$path" "$safe" yes 403 SAFE_MODE_ON
    done
  done
done
check PUT /session armed yes 403 SAFE_MODE_ON
check GET /vitals armed NONE 400 MISSING_TAB_ID
check POST /vitals armed NONE 400 MISSING_TAB_ID

# Nothing changed in IRIS: the demo role is untouched (read through the official API).
roles=$(curl -s -u "$user:$pass" "${base%/api/flightdeck/v1}/api/admin/v2/security/role?name=FD_Demo_Operator" -o /dev/null -w '%{http_code}')
echo "  FD_Demo_Operator still readable: HTTP $roles"

[ "$fail" = 0 ] && echo "safe-mode enforcement: all requests rejected as expected" || echo "safe-mode enforcement: FAILURES"
exit "$fail"
