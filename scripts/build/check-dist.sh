#!/usr/bin/env bash
# Rebuilds the frontend and fails if the committed frontend/dist differs (research R13).
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -r "$root/frontend/dist" "$tmp/committed"
(cd "$root/frontend" && npm run build >/dev/null)
if ! diff -r "$tmp/committed" "$root/frontend/dist" >/dev/null; then
  echo "check-dist: frontend/dist is out of date; commit the rebuilt files"
  exit 1
fi
echo "check-dist: up to date"
