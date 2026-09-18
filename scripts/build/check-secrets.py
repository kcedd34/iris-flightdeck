#!/usr/bin/env python3
"""Offline check that Constitution VI stays enforceable as the official API changes.

Every field of the official specification that looks like secret material must be either
  - declared in a descriptor's "secretFields" (FlightDeck.Domain.EntityTypes or
    FlightDeck.Mutation.Descriptors), so the mutation layer removes and masks it, or
  - listed in scripts/build/secret-exemptions.json with a reason.

"Looks like secret material" is: the field name contains password, secret, token or credential,
or the specification marks it writeOnly. The check is by field name, not by operation: a name
that is secret anywhere is secret everywhere, which is the conservative direction.

Usage: check-secrets.py
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "docs" / "sysadmin-api-v2.json"
CLS = ROOT / "backend" / "cls" / "FlightDeck"
ENTITY_TYPES = CLS / "Domain" / "EntityTypes.cls"
MUTATIONS = CLS / "Mutation" / "Descriptors.cls"
# Build data, not a class: anything under backend/cls is imported by the ZPM module, and a
# non-class file there fails the whole install.
EXEMPTIONS = Path(__file__).resolve().parent / "secret-exemptions.json"
PATTERN = re.compile(r"password|secret|token|credential", re.I)


def fail(message):
    print(f"check-secrets: {message}", file=sys.stderr)
    sys.exit(1)


def xdata(path, name):
    text = path.read_text(encoding="utf-8")
    start = text.index("XData " + name)
    body = text[text.index("{", start) + 1:].lstrip()
    document, _ = json.JSONDecoder().raw_decode(body)
    return document


def candidates(node, where, found):
    """Collects (field, where) for every property that looks like secret material."""
    if isinstance(node, dict):
        properties = node.get("properties")
        if isinstance(properties, dict):
            for field, schema in properties.items():
                if PATTERN.search(field) or (isinstance(schema, dict) and schema.get("writeOnly")):
                    found.setdefault(field, set()).add(where)
        if node.get("writeOnly") and isinstance(properties, dict):
            for field in properties:
                found.setdefault(field, set()).add(where)
        for key, value in node.items():
            candidates(value, f"{where}/{key}" if where else str(key), found)
    elif isinstance(node, list):
        for index, value in enumerate(node):
            candidates(value, f"{where}[{index}]", found)


def declared():
    names = set()
    for path, block in ((ENTITY_TYPES, "EntityTypes"), (MUTATIONS, "Mutations")):
        for entry in xdata(path, block).values():
            for field in entry.get("secretFields", []) or []:
                names.add(field)
    return names


def main():
    found = {}
    candidates(json.loads(SPEC.read_text(encoding="utf-8")), "", found)
    known = declared()
    exemptions = json.loads(EXEMPTIONS.read_text(encoding="utf-8")) if EXEMPTIONS.exists() else {}
    exemptions.pop("_comment", None)
    for field, reason in exemptions.items():
        if not str(reason).strip():
            fail(f"exemption '{field}' has no reason")
    missing = sorted(f for f in found if f not in known and f not in exemptions)
    if missing:
        print("check-secrets: secret-looking fields neither declared nor exempted:", file=sys.stderr)
        for field in missing:
            print(f"  {field}  (in {', '.join(sorted(found[field]))[:160]})", file=sys.stderr)
        print(f"Declare them in a descriptor's secretFields, or list them with a reason in {EXEMPTIONS.relative_to(ROOT)}.", file=sys.stderr)
        sys.exit(1)
    stale = sorted(f for f in exemptions if f not in found)
    if stale:
        fail("exemptions that no longer match any field of the official specification: " + ", ".join(stale))
    print(f"check-secrets: ok ({len(found)} candidate fields, {len(known)} declared, {len(exemptions)} exempted)")


if __name__ == "__main__":
    main()
