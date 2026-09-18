#!/usr/bin/env bash
# Fails if the committed generated classes differ from what the generators produce now.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
python3 "$root/scripts/build/gen-capability-spec.py" "$tmp/Spec.cls" >/dev/null
diff -u "$root/backend/cls/FlightDeck/Capability/Spec.cls" "$tmp/Spec.cls"
python3 "$root/scripts/build/gen-openapi-cls.py" "$tmp/OpenAPI.cls" >/dev/null
diff -u "$root/backend/cls/FlightDeck/API/OpenAPI.cls" "$tmp/OpenAPI.cls"
python3 "$root/scripts/build/gen-v1-dialect.py" "$tmp/V1Routes.cls" >/dev/null
diff -u "$root/backend/cls/FlightDeck/Admin/V1Routes.cls" "$tmp/V1Routes.cls"
python3 "$root/scripts/build/gen-schemas.py" "$tmp/schemas.ts" "$tmp/Schemas.cls" >/dev/null
diff -u "$root/frontend/src/domains/generated/schemas.ts" "$tmp/schemas.ts"
diff -u "$root/backend/cls/FlightDeck/Domain/Schemas.cls" "$tmp/Schemas.cls"
python3 "$root/scripts/build/check-descriptors.py"
# Constitution VI: a field of the official specification that looks like secret material must be
# declared secret in a descriptor or exempted with a reason. Feature 003 T003 wrote this gate and
# left it out of the build while the descriptors did not exist; T050 turned it on.
python3 "$root/scripts/build/check-secrets.py"
echo "check-generated: up to date"
