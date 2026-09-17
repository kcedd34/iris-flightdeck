#!/usr/bin/env bash
# Runs the day-1 verification against fresh IRIS Community and IRIS for Health Community
# containers (2026.2), writes verification/<product>-<version>.json for each, validates them,
# and removes the containers. Exit code: the highest exit code of the two runs.
#
# The stock image entrypoint crashes on start (research R2), so IRIS is started with iris-main
# directly. The image ships _SYSTEM with an expired password (research R3), so default passwords
# are unexpired in these throwaway containers only.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
images=(
  "intersystemsdc/iris-community:2026.2-zpm"
  "intersystemsdc/irishealth-community:2026.2-zpm"
)
labels=("iris-community-2026.2" "irishealth-community-2026.2")
port=52791
worst=0

wait_running() {
  local name="$1"
  for _ in $(seq 1 100); do
    if docker exec "$name" iris qlist 2>/dev/null | grep -q running; then
      # the web server answers slightly after the instance reports running
      for _ in $(seq 1 60); do
        curl -s -o /dev/null "http://localhost:$2/api/admin/info" && return 0
        sleep 2
      done
      return 1
    fi
    sleep 3
  done
  return 1
}

for i in "${!images[@]}"; do
  image="${images[$i]}"
  label="${labels[$i]}"
  name="fd-verify-$label"
  echo "==> $label ($image)"
  docker rm -f "$name" >/dev/null 2>&1
  if ! docker run -d --name "$name" -p "$port:52773" --entrypoint /tini "$image" -- /iris-main --check-caps false >/dev/null; then
    echo "    could not start $image"; worst=1; continue
  fi
  if ! wait_running "$name" "$port"; then
    echo "    IRIS did not become ready"; docker logs "$name" 2>&1 | tail -20; docker rm -f "$name" >/dev/null; worst=1; continue
  fi
  printf 'do ##class(Security.Users).UnExpireUserPasswords("*")\nhalt\n' | docker exec -i "$name" iris session IRIS -U %SYS >/dev/null
  python3 "$here/verify_platform.py" --base-url "http://localhost:$port" --container "$name" --label "$label"
  code=$?
  (( code > worst )) && worst=$code
  docker rm -f "$name" >/dev/null
done

python3 "$here/validate_report.py" "$root"/verification/*-2026.2.json || worst=1
exit "$worst"
