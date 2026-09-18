#!/usr/bin/env bash
# Every five minutes: can a visitor still sign in? (feature 007, item 11)
#
# This is the failure that actually happens on a public demo with a full-privilege account: somebody
# changes the demo password, or disables the account, and the portal is intact but nobody can get in
# until the next hourly rebuild. Waiting an hour for that is the difference between an evaluator
# seeing the product and an evaluator seeing a login form that refuses them.
#
# It checks what a visitor does — authenticate against FlightDeck's own API — and not merely that a
# port is open.
set -euo pipefail
cd "$(dirname "$0")"
set -a; [ -f .env ] && . ./.env; set +a
LOG=/var/log/flightdeck-demo.log

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
  -u "${FD_DEMO_USER}:${FD_DEMO_PASSWORD}" \
  -H 'X-FlightDeck-Tab: watchdog' \
  http://127.0.0.1:52780/api/flightdeck/v1/session || true)

if [ "$code" = "200" ]; then
  exit 0
fi

echo "$(date -Is) watchdog: demo sign-in answered ${code:-no response}; rebuilding now" >> "$LOG"
./reinstall.sh
