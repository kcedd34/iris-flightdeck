#!/usr/bin/env bash
# Compares the package the public registry serves with the tree that should have produced it.
#
# Open Exchange publishes to pm.community.intersystems.com from the GitHub repository, so nobody runs
# a publish command and nothing local proves what was shipped. Version 0.1.0 went out with a README
# two commits stale and it took two days and a manual download to notice
# (verification/package-publication.md). This is that download, as a command.
#
# What it checks, and why each one:
#   1. the version the registry calls latest, against module.xml;
#   2. the SHA-1 of the download against the SHA-1 the registry declares — a truncated transfer
#      otherwise passes every later check by looking like a smaller package;
#   3. the tree against `git archive <ref>`, in BOTH directions. An earlier check filtered one
#      direction out and could only ever see files the package added, never ones it lacked;
#   4. no archive inside the archive. A packager run in a directory holding a previous tarball can
#      swallow it, and the result is a package that carries its own ancestor;
#   5. the size, against a declared expectation. A package that doubles or halves without anyone
#      deciding it should is the symptom that reached a human last time, late.
#
# Needs network. Not a build gate: it asks the internet a question, and the build cannot.
#
# Usage: scripts/dev/check-published-package.sh [git-ref]
set -euo pipefail

REF="${1:-HEAD}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REGISTRY="https://pm.community.intersystems.com"
PACKAGE="iris-flightdeck"

# The compressed size the repository is expected to produce, and the slack allowed before this asks
# for a human. Open Exchange packages the whole repository, so this tracks the repository's growth:
# when it trips legitimately, update the number in the same commit that grew the tree.
EXPECTED_BYTES=1822054
TOLERANCE_PCT=25

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fail=0
note() { printf '  %s\n' "$*"; }
bad() { printf 'check-published-package: %s\n' "$*" >&2; fail=1; }

echo "check-published-package: asking $REGISTRY what it serves"
curl -sf --max-time 60 "$REGISTRY/packages/$PACKAGE/latest" -o "$work/meta.json" \
  || { bad "the registry did not answer for $PACKAGE"; exit 1; }

published=$(python3 -c "import json;print(json.load(open('$work/meta.json'))['version'])")
declared_hash=$(python3 -c "import json;print(json.load(open('$work/meta.json'))['hash'])")
declared_size=$(python3 -c "import json;print(json.load(open('$work/meta.json'))['size'])")
url=$(python3 -c "import json;print(json.load(open('$work/meta.json'))['url'])")
local_version=$(grep -oP '(?<=<Version>)[^<]+' "$ROOT/module.xml")

note "registry latest : $published"
note "module.xml      : $local_version"
[ "$published" = "$local_version" ] \
  || bad "the registry serves $published while module.xml says $local_version"

# 2. Integrity of what came down.
curl -sf --max-time 300 "$url" -o "$work/pkg.tgz" || { bad "could not download $url"; exit 1; }
actual_hash=$(sha1sum "$work/pkg.tgz" | cut -d' ' -f1)
actual_size=$(stat -c%s "$work/pkg.tgz")
note "sha1            : $actual_hash"
[ "$actual_hash" = "$declared_hash" ] \
  || bad "the download hashes to $actual_hash but the registry declares $declared_hash"
[ "$actual_size" = "$declared_size" ] \
  || bad "the download is $actual_size bytes but the registry declares $declared_size"

# 5. Size, against what this repository is expected to produce.
low=$(( EXPECTED_BYTES * (100 - TOLERANCE_PCT) / 100 ))
high=$(( EXPECTED_BYTES * (100 + TOLERANCE_PCT) / 100 ))
note "size            : $actual_size bytes (expected ~$EXPECTED_BYTES, ±$TOLERANCE_PCT%)"
if [ "$actual_size" -lt "$low" ] || [ "$actual_size" -gt "$high" ]; then
  bad "the package is $actual_size bytes, outside $low..$high. Either the repository changed size for
    a reason somebody decided, and EXPECTED_BYTES in this script should move with it, or something is
    in there that should not be. Check the largest entries:
      tar tzvf <pkg> | sort -k3 -rn | head -15"
fi

# 4. No archive inside the archive.
nested=$(tar tzf "$work/pkg.tgz" | grep -iE '\.(tgz|tar|tar\.gz|zip)$' || true)
if [ -n "$nested" ]; then
  bad "the package contains an archive, which means the packager swallowed one from its working
    directory:"
  printf '    %s\n' $nested >&2
else
  note "nested archives : none"
fi

# 3. The tree, both directions.
mkdir -p "$work/pkg" "$work/ref"
tar xzf "$work/pkg.tgz" -C "$work/pkg"
git -C "$ROOT" archive "$REF" | tar -x -C "$work/ref"
differences=$(diff -rq "$work/pkg" "$work/ref" 2>/dev/null | sed "s|$work/pkg|<package>|; s|$work/ref|<$REF>|" || true)
if [ -n "$differences" ]; then
  bad "the package does not match \`git archive $REF\`:"
  printf '    %s\n' "$differences" >&2
  note "(commits made after the release was cut show up here and are expected; anything else is not)"
else
  note "tree            : identical to git archive $REF, both directions"
fi

if [ "$fail" -ne 0 ]; then
  echo "check-published-package: the published package does not match this tree" >&2
  exit 1
fi
echo "check-published-package: ok ($PACKAGE $published, $actual_size bytes, tree identical to $REF)"
