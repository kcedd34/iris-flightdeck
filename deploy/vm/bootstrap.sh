#!/usr/bin/env bash
# First-time setup of the demo VM (feature 007).
#
# Generates both passwords HERE, on the machine that will use them, so neither is ever chosen
# somewhere else and carried over. The demo password is meant to be published; the _SYSTEM password
# is not, and this file is the only place it exists. deploy/vm/.env is covered by .gitignore.
#
# Idempotent: run it again and existing values are kept.
set -euo pipefail
cd "$(dirname "$0")"

password() {
  # 24 characters from a set with no shell metacharacters and no visually ambiguous glyphs, so the
  # demo one can be read off a screen and typed without a second attempt.
  tr -dc 'A-HJ-NP-Za-km-z2-9' < /dev/urandom | head -c 24
}

if [ -f .env ]; then
  echo "bootstrap: .env exists, keeping the values in it"
else
  umask 077
  # Values are quoted: these files are sourced by the scripts, and an unquoted value with a space in
  # it is executed rather than assigned. FD_DEMO_RESET is prose, so it always has spaces.
  cat > .env <<ENV
FD_DEMO_USER="demo"
FD_DEMO_PASSWORD="$(password)"
FD_DEMO_RESET="every hour"
FD_SYSTEM_PASSWORD="$(password)"
ENV
  echo "bootstrap: .env written with freshly generated passwords"
fi
chmod 600 .env

set -a; . ./.env; set +a
echo
echo "The published demo credential (this one is public by design):"
echo "  user:     $FD_DEMO_USER"
echo "  password: $FD_DEMO_PASSWORD"
echo
echo "The _SYSTEM password is in $(pwd)/.env and is deliberately not printed here."
