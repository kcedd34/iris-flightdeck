#!/usr/bin/env bash
# Feature 002 SC-003 and SC-004: the server, not the UI, refuses
#  - every mutation from an armed tab (mutation service and the REST executor's mutating methods);
#  - any change that would disable, delete or make unreachable FlightDeck's own web applications;
#  - an apply whose typed confirmation does not match.
# Requests go straight to FlightDeck's API with a CSP session cookie; no UI is involved. Nothing is
# changed in IRIS (checked at the end through the official API). Needs a running install.
# Usage: scripts/dev/check-mutation-enforcement.sh [base-url]   (default http://localhost:52780)
set -uo pipefail
root="${1:-http://localhost:${FLIGHTDECK_PORT:-52780}}"
base="$root/api/flightdeck/v1"
user="${FD_USER:-_SYSTEM}"
pass="${FD_PASSWORD:-SYS}"
jar="$(mktemp)"; out="$(mktemp)"
trap 'rm -f "$jar" "$out"' EXIT
fail=0

code=$(curl -s -o /dev/null -w '%{http_code}' -c "$jar" -b "$jar" -u "$user:$pass" -X POST -H 'X-FlightDeck-Tab: mutation-check' "$base/session")
[ "$code" = "200" ] || { echo "sign-in failed: HTTP $code"; exit 1; }

post() { # path safe-header-or-NONE json -> sets got/body
  local args=(-s -o "$out" -w '%{http_code}' -b "$jar" -X POST -H 'X-FlightDeck-Tab: mutation-check' -H 'Content-Type: application/json' --data "$3")
  [ "$2" != "NONE" ] && args+=(-H "X-FlightDeck-Safe-Mode: $2")
  got=$(curl "${args[@]}" "$base$1"); body=$(cat "$out")
}

expect() { # label expected-code expected-error-code
  if [ "$got" = "$2" ] && grep -q "\"code\":\"$3\"" <<<"$body"; then
    printf '  ok    %-62s -> %s %s\n' "$1" "$got" "$3"
  else
    printf '  FAIL  %-62s -> %s %s\n' "$1" "$got" "$(cut -c1-200 <<<"$body")"
    fail=1
  fi
}

fingerprint() { # json -> echoes the preview fingerprint
  post /mutations/preview NONE "$1"
  python3 -c 'import json,sys; print(json.load(sys.stdin).get("fingerprint",""))' <<<"$body"
}

echo "Mutation enforcement against $base"
echo "Armed tab (no or armed safe-mode header):"
for req in \
  '{"operationId":"PUT /v2/web-app","keys":{"name":"/csp/fd-demo"},"proposed":{"Description":"x"},"fingerprint":"any"}' \
  '{"operationId":"DELETE /v2/web-app","keys":{"name":"/csp/fd-demo"},"fingerprint":"any","confirmation":"/csp/fd-demo"}' \
  '{"operationId":"PUT /v2/web-app/pct-access","keys":{"name":"/csp/fd-demo","allowType":"AllowClass","class":"%X"},"proposed":{"AllowAccess":true},"fingerprint":"any"}' \
  '{"operationId":"DELETE /v2/web-app/pct-access","keys":{"name":"all-applications","allowType":"AllowClass","class":"%SYS.Python.WSGI"},"fingerprint":"any"}' \
  '{"operationId":"FLIGHTDECK REST execute","request":{"method":"DELETE","path":"/api/flightdeck/v1/session"},"fingerprint":"any"}'; do
  for safe in NONE armed bogus; do
    post /mutations/apply "$safe" "$req"
    expect "apply $(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["operationId"])' "$req") safe=$safe" 403 SAFE_MODE_ON
  done
done
for method in POST PUT PATCH DELETE; do
  post /rest/execute armed "{\"method\":\"$method\",\"path\":\"/api/flightdeck/v1/session\"}"
  expect "execute $method (method under test) safe=armed" 403 SAFE_MODE_ON
done

echo "Disarmed tab, FlightDeck's own applications:"
for req in \
  '{"operationId":"PUT /v2/web-app","keys":{"name":"/api/flightdeck"},"proposed":{"Enabled":false}}' \
  '{"operationId":"PUT /v2/web-app","keys":{"name":"/flightdeck"},"proposed":{"Enabled":false}}' \
  '{"operationId":"PUT /v2/web-app","keys":{"name":"/api/flightdeck"},"proposed":{"NameSpace":"%SYS"}}' \
  '{"operationId":"PUT /v2/web-app","keys":{"name":"/api/flightdeck"},"proposed":{"DispatchClass":"%Api.Admin"}}' \
  '{"operationId":"PUT /v2/web-app","keys":{"name":"/flightdeck"},"proposed":{"AutheEnabled":32}}' \
  '{"operationId":"PUT /v2/web-app","keys":{"name":"/api/flightdeck"},"proposed":{"MatchRoles":[]}}' \
  '{"operationId":"DELETE /v2/web-app","keys":{"name":"/api/flightdeck"}}' \
  '{"operationId":"DELETE /v2/web-app","keys":{"name":"/flightdeck"}}'; do
  fp=$(fingerprint "$req")
  name=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["keys"]["name"])' "$req")
  signed=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); d["fingerprint"]=sys.argv[2]; d["confirmation"]=sys.argv[3]; d["acknowledged"]=True; print(json.dumps(d))' "$req" "$fp" "$name")
  post /mutations/apply disarmed "$signed"
  expect "$(cut -c1-62 <<<"$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d["operationId"], d["keys"]["name"], json.dumps(d.get("proposed","")))' "$req")")" 403 SELF_PROTECTION
done

echo "Disarmed tab, confirmation:"
req='{"operationId":"PUT /v2/web-app","keys":{"name":"/csp/fd-demo"},"proposed":{"Enabled":false}}'
fp=$(fingerprint "$req")
post /mutations/apply disarmed "$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); d["fingerprint"]=sys.argv[2]; d["confirmation"]="wrong"; print(json.dumps(d))' "$req" "$fp")"
expect "reinforced grade with a wrong typed name" 422 CONFIRMATION_REQUIRED
post /mutations/apply disarmed '{"operationId":"PUT /v2/web-app","keys":{"name":"/csp/fd-demo"},"proposed":{"Description":"x"},"fingerprint":"stale"}'
expect "stale fingerprint" 409 STATE_CHANGED

echo "Nothing changed in IRIS (official API):"
state=$(curl -s -u "$user:$pass" "$root/api/admin/v2/web-app?name=/api/flightdeck" | python3 -c 'import json,sys; r=json.load(sys.stdin)["result"]; print(r["Enabled"], r["NameSpace"], r["DispatchClass"], r["AutheEnabled"], len(r["MatchRoles"]))')
spa=$(curl -s -u "$user:$pass" "$root/api/admin/v2/web-app?name=/flightdeck" | python3 -c 'import json,sys; r=json.load(sys.stdin)["result"]; print(r["Enabled"], r["AutheEnabled"])')
demo=$(curl -s -u "$user:$pass" "$root/api/admin/v2/web-app?name=/csp/fd-demo" | python3 -c 'import json,sys; r=json.load(sys.stdin)["result"]; print(r["Enabled"], r["Description"])')
echo "  /api/flightdeck: $state"; echo "  /flightdeck: $spa"; echo "  /csp/fd-demo: $demo"
[ "$state" = "True USER FlightDeck.API.Router 32 1" ] && [ "$spa" = "True 64" ] && [ "${demo%% *}" = "True" ] || { echo "  FAIL  IRIS state changed"; fail=1; }

[ "$fail" = 0 ] && echo "mutation enforcement: all requests refused as expected" || echo "mutation enforcement: FAILURES"
exit "$fail"
