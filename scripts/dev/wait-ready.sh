#!/usr/bin/env bash
# Waits for the FlightDeck ready line in `docker compose logs iris`.
# Exit 0 when ready, 1 on "FLIGHTDECK INSTALL FAILED" or timeout (default 600 s).
set -uo pipefail
timeout="${1:-600}"
start=$(date +%s)
while true; do
  logs="$(docker compose logs iris 2>&1)"
  if grep -q "FLIGHTDECK INSTALL FAILED" <<<"$logs"; then
    grep -A20 "FLIGHTDECK INSTALL FAILED" <<<"$logs" | head -40
    exit 1
  fi
  if grep -q "FlightDeck is ready at" <<<"$logs"; then
    echo "ready after $(( $(date +%s) - start ))s"
    grep "FlightDeck is ready at" <<<"$logs" | tail -1
    exit 0
  fi
  if (( $(date +%s) - start > timeout )); then
    echo "timeout after ${timeout}s"; tail -40 <<<"$logs"; exit 1
  fi
  sleep 5
done
