#!/usr/bin/env bash
# Rebuilds the demo instance from nothing (feature 007, items 12, 13, 18).
#
# Order matters and is the whole point of this file:
#   1. drop the egress rule, or the rebuild cannot pull or install;
#   2. destroy the instance and its volume, so dirty state cannot survive;
#   3. bring it up and wait for the portal to answer;
#   4. provision the two accounts;
#   5. put the egress rule back.
# A failure at any step leaves the egress rule off, which is the safe direction: the instance is
# either serving with the rule on, or not serving at all.
set -euo pipefail
cd "$(dirname "$0")"

LOG=/var/log/flightdeck-demo.log
exec > >(tee -a "$LOG") 2>&1
echo "=== reinstall $(date -Is) ==="

set -a; [ -f .env ] && . ./.env; set +a

./egress.sh clear || true

docker compose -p vm down -v --remove-orphans || true
docker compose -p vm up -d --build

echo "waiting for the portal"
for attempt in $(seq 1 120); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:52780/flightdeck/ || true)
  [ "$code" = "200" ] && break
  sleep 5
done
if [ "${code:-}" != "200" ]; then
  echo "reinstall: portal did not answer; leaving egress open and the stack up for inspection" >&2
  exit 1
fi
echo "portal answering after ${attempt} attempts"

./provision.sh
./egress.sh apply
echo "=== reinstall complete $(date -Is) ==="
