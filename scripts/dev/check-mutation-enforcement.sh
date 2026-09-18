#!/usr/bin/env bash
# Feature 002 SC-003 and SC-004, extended by feature 003 SC-005: the server, not the UI, refuses
#  - every mutation from an armed tab (mutation service, permissions writes, and the REST executor's
#    mutating methods);
#  - any change that would disable, delete or make unreachable FlightDeck's own web applications;
#  - an apply whose typed confirmation does not match;
#  - and, for a permissions change that is not the last administrative access, previews it without
#    a block and without an incomplete-check notice.
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
  '{"operationId":"FLIGHTDECK REST execute","request":{"method":"DELETE","path":"/api/flightdeck/v1/session"},"fingerprint":"any"}' \
  '{"operationId":"PUT /v2/security/user","keys":{"name":"Admin"},"proposed":{"Enabled":false},"fingerprint":"any"}' \
  '{"operationId":"DELETE /v2/security/role","keys":{"name":"FD_Demo_Operator"},"fingerprint":"any","confirmation":"FD_Demo_Operator"}' \
  '{"operationId":"POST /v2/security/user/password","keys":{"name":"Admin"},"params":{"name":"Admin","newPassword":"never-sent"},"fingerprint":"any"}' \
  '{"operationId":"POST /v2/security/sql-privilege/revoke","keys":{},"params":{"namespace":"USER","grantee":"FD_Demo_Operator","type":"TABLE","object":"FDT.Nothing","action":"SELECT"},"fingerprint":"any"}'; do
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

# The affirmative block and the partial-mode notice change roles, so they live in the last-admin and
# security Playwright projects. Here, where nothing may change, the checked claim is the other half:
# a role deletion that is not the last administrative access previews with a grade and a fingerprint,
# blocks nothing and raises no incomplete-check notice.
echo "Disarmed tab, permissions: a deletion that is not the last administrative access:"
req='{"operationId":"DELETE /v2/security/role","keys":{"name":"FD_Demo_Operator"}}'
post /mutations/preview NONE "$req"
read -r ok detail <<<"$(python3 -c '
import json, sys
d = json.load(sys.stdin)
problems = []
if d.get("grade") != "reinforced": problems.append("grade=%s" % d.get("grade"))
if not d.get("fingerprint"): problems.append("no fingerprint")
if d.get("blocked") is not None: problems.append("blocked=%s" % d.get("blocked"))
if d.get("notice") is not None: problems.append("notice=%s" % d.get("notice"))
print("no" if problems else "ok", ", ".join(problems) or "grade=reinforced, not blocked, no notice")
' <<<"$body")"
if [ "$got" = "200" ] && [ "$ok" = "ok" ]; then
  printf '  ok    %-62s -> %s\n' "preview of a role deletion" "$detail"
else
  printf '  FAIL  %-62s -> HTTP %s %s\n' "preview of a role deletion" "$got" "$detail"; fail=1
fi

# Feature 004: the process serving this very request. The screen hides the control; the server is
# what refuses, and this check calls the server directly (RN-FD-12, spec FR-031).
echo "Disarmed tab, the session's own process:"
own=$(curl -s -b "$jar" -H 'X-FlightDeck-Tab: mutation-check' "$base/domains/system/process?maxRows=500" | python3 -c '
import json, sys
try:
    items = json.load(sys.stdin).get("items", [])
except Exception:
    items = []
own = [i for i in items if i.get("facts", {}).get("isOwnSession")]
print(own[0]["keys"]["id"] if own else "")
')
if [ -z "$own" ]; then
  printf '  FAIL  %-62s -> the process list marks no process as this session\n' "own-session refusal"; fail=1
else
  post /mutations/preview NONE "{\"operationId\":\"POST /v2/process/terminate\",\"keys\":{\"id\":\"$own\"},\"params\":{\"id\":\"$own\"}}"
  if grep -q "your own session" <<<"$body"; then
    printf '  ok    %-62s -> refused, explained\n' "terminate the session's own process (pid $own)"
  else
    printf '  FAIL  %-62s -> HTTP %s %s\n' "terminate the session's own process (pid $own)" "$got" "$(head -c 160 <<<"$body")"; fail=1
  fi
fi

echo "Nothing changed in IRIS (official API):"
# The same object reads on either dialect: these paths are the same under /v1 and /v2, so only the
# version segment changes. Asking a v1 instance for /v2 answers 404 and would report, wrongly, that
# the state changed.
adminv="v$(curl -s -u "$user:$pass" "$root/api/admin/info" | python3 -c 'import json,sys; print(2 if json.load(sys.stdin)["result"]["apiVersion"] >= 2 else 1)')"
state=$(curl -s -u "$user:$pass" "$root/api/admin/$adminv/web-app?name=/api/flightdeck" | python3 -c 'import json,sys; r=json.load(sys.stdin)["result"]; print(r["Enabled"], r["NameSpace"], r["DispatchClass"], r["AutheEnabled"], len(r["MatchRoles"]))')
spa=$(curl -s -u "$user:$pass" "$root/api/admin/$adminv/web-app?name=/flightdeck" | python3 -c 'import json,sys; r=json.load(sys.stdin)["result"]; print(r["Enabled"], r["AutheEnabled"])')
demo=$(curl -s -u "$user:$pass" "$root/api/admin/$adminv/web-app?name=/csp/fd-demo" | python3 -c 'import json,sys; r=json.load(sys.stdin)["result"]; print(r["Enabled"], r["Description"])')
admin=$(curl -s -u "$user:$pass" "$root/api/admin/$adminv/security/user?name=Admin" | python3 -c 'import json,sys; r=json.load(sys.stdin)["result"]; print(r["Enabled"], ",".join(r["Roles"]))')
role=$(curl -s -u "$user:$pass" "$root/api/admin/$adminv/security/role?name=FD_Demo_Operator" -o /dev/null -w '%{http_code}')
echo "  Admin: $admin"; echo "  FD_Demo_Operator: HTTP $role"
[ "${admin%% *}" = "True" ] && [ "$role" = "200" ] || { echo "  FAIL  permissions state changed"; fail=1; }
echo "  /api/flightdeck: $state"; echo "  /flightdeck: $spa"; echo "  /csp/fd-demo: $demo"
[ "$state" = "True USER FlightDeck.API.Router 32 1" ] && [ "$spa" = "True 64" ] && [ "${demo%% *}" = "True" ] || { echo "  FAIL  IRIS state changed"; fail=1; }

[ "$fail" = 0 ] && echo "mutation enforcement: all requests refused as expected" || echo "mutation enforcement: FAILURES"
exit "$fail"
