#!/usr/bin/env bash
# FlightDeck first start (container install path). Runs after IRIS is up, via iris-main -a.
# Everything it prints appears in `docker compose logs iris`.
set -euo pipefail

port="${FLIGHTDECK_PORT:-52780}"
marker="${ISC_DATA_DIRECTORY:-/usr/irissys}/flightdeck.installed"
ready="FlightDeck is ready at http://localhost:${port}/flightdeck/ — sign in with the default account documented in the README (local evaluation only)."

if [ -f "$marker" ]; then
  echo "FlightDeck already installed."
  echo "$ready"
  exit 0
fi

echo "FlightDeck: installing into namespace USER (first start, about a minute)..."

# The Community image ships default accounts with expired passwords (research R3). Keep the
# documented defaults usable; no credential is created or changed.
iris session IRIS -U %SYS <<'OS' >/dev/null
do ##class(Security.Users).UnExpireUserPasswords("*")
halt
OS

log="$(mktemp)"
iris session IRIS -U USER <<'OS' 2>&1 | tee "$log"
zpm "load /opt/flightdeck -v -DDemo=1"
halt
OS

# Success is the installer's own last line. Any IPM "ERROR!" or installer failure line means failure.
if ! grep -q "FlightDeck: install complete" "$log" || grep -q "ERROR!" "$log"; then
  if ! grep -q "FLIGHTDECK INSTALL FAILED" "$log"; then
    reason="$(grep -m1 -A2 "ERROR" "$log" | tr -s '\r\n' ' ' | sed 's/\x1b\[[0-9;]*m//g')"
    echo "FLIGHTDECK INSTALL FAILED: compile/install: ${reason:-see the IPM output above}"
  fi
  echo "IRIS keeps running so you can inspect it: docker compose logs iris"
  rm -f "$log"
  # Exit 0 on purpose: a non-zero exit makes iris-main shut IRIS down, and the restart policy would
  # loop the install. The failure line above is what the operator needs (FR-041).
  exit 0
fi
rm -f "$log"

touch "$marker"
echo "$ready"
