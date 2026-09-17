#!/usr/bin/env bash
# Run ObjectScript from stdin in a container: scripts/dev/iris.sh [NAMESPACE] [CONTAINER] <<'OS' ... OS
set -euo pipefail
ns="${1:-USER}"
container="${2:-${FD_DEV_CONTAINER:-fd-dev}}"
{ cat; printf '\nhalt\n'; } | docker exec -i "$container" iris session IRIS -U "$ns" | grep -avE "^(${ns}|%SYS)>\s*$" || true
