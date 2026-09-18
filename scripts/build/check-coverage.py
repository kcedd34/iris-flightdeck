#!/usr/bin/env python3
"""Every operation a domain claims must be reachable or declared declined (feature 004 SC-001).

Partial coverage is a defect, not a scope choice: the brief asks for the whole of each domain, and a
silently missing operation is indistinguishable from one nobody noticed. This check reads the
operation tables of docs/api-coverage.md and fails naming any operation of a shipped domain that is
neither reachable through a descriptor (an entity type's list or detail read, or a mutation) nor
declared in FlightDeck.Capability.Policy.

Domains are opted in as their feature ships, so a domain still to be built does not fail the build.
There is no list of accepted gaps: one existed while feature 003's fifteen unreached operations were
being closed, and it was removed when they were. A gate with a tolerated list means less every time
a line is added to it.

Usage: check-coverage.py
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COVERAGE = ROOT / "docs" / "api-coverage.md"
CLS = ROOT / "backend" / "cls" / "FlightDeck"
ENTITY_TYPES = CLS / "Domain" / "EntityTypes.cls"
MUTATIONS = CLS / "Mutation" / "Descriptors.cls"
POLICY = CLS / "Capability" / "Policy.cls"

# Section heading -> the feature that ships it. A section absent here is not checked yet.
SHIPPED = {
    "1. Web apps e APIs": "002",
    "2. Permissões": "003",
    "3. Segurança e segredos": "003",
    "4. Tarefas": "004",
    "5. Sistema operacional": "004",
    "6. Logs": "005",
}

ROW = re.compile(r"^\|\s*(GET|PUT|POST|DELETE|PATCH)\s*\|\s*`([^`]+)`")




def xdata(path, name):
    text = path.read_text(encoding="utf-8")
    start = text.index("XData " + name)
    body = text[text.index("{", start) + 1:].lstrip()
    document, _ = json.JSONDecoder().raw_decode(body)
    return document


def operations_by_section():
    sections, current = {}, None
    for line in COVERAGE.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            current = line[3:].split(" — ")[0].strip()
            sections.setdefault(current, [])
            continue
        match = ROW.match(line)
        if match and current is not None:
            sections[current].append(f"{match.group(1)} {match.group(2)}")
    return sections


def reachable():
    """Operations the shipped code can call.

    Anything the backend names is reachable: a descriptor's read or mutation, a link provider's call,
    a composed read, the telemetry service. Scanning the whole class tree is the honest definition —
    a narrower scan would call an operation "missing" only because this script did not look where it
    lives.
    """
    reached = set()
    for entity in xdata(ENTITY_TYPES, "EntityTypes").values():
        for key in ("listOperation", "detailOperation"):
            if key in entity:
                reached.add(entity[key])
    reached |= set(xdata(MUTATIONS, "Mutations"))
    verbs = "GET|PUT|POST|DELETE|PATCH"
    # Generated catalogues list every official operation as data. Counting them as reachable would
    # make this check unable to fail, which is worse than not having it.
    catalogues = {
        CLS / "Capability" / "Spec.cls",
        CLS / "Admin" / "V1Routes.cls",
        CLS / "API" / "OpenAPI.cls",
        CLS / "Domain" / "Schemas.cls",
        # Read structurally above. Scanning their text too would count an operation an entity type
        # merely names as reachable, even with no descriptor behind it — and then the gate would
        # pass on exactly the gap it exists to catch.
        ENTITY_TYPES,
        MUTATIONS,
    }
    for path in CLS.rglob("*.cls"):
        if path in catalogues:
            continue
        text = path.read_text(encoding="utf-8")
        # "GET /v2/..." written whole, and Call("GET", "/v2/...") / Get("/v2/...") forms.
        for match in re.finditer(rf'"({verbs}) (/v2/[A-Za-z0-9_\-/]+)"', text):
            reached.add(f"{match.group(1)} {match.group(2)}")
        for match in re.finditer(rf'Call\(\s*"({verbs})",\s*"(/v2/[A-Za-z0-9_\-/]+)"', text):
            reached.add(f"{match.group(1)} {match.group(2)}")
        for match in re.finditer(r'\bGet\(\s*"(/v2/[A-Za-z0-9_\-/]+)"', text):
            reached.add("GET " + match.group(1))
    return reached


def main():
    sections = operations_by_section()
    declined = set(xdata(POLICY, "Declined"))
    reached = reachable()
    problems, counted = [], 0
    for section, feature in SHIPPED.items():
        if section not in sections:
            problems.append(f"section '{section}' is not in docs/api-coverage.md")
            continue
        for operation in sections[section]:
            counted += 1
            if operation in reached or operation in declined:
                continue
            problems.append(f"{operation} ({section}, feature {feature}) is neither reachable nor declined")
    if problems:
        for problem in problems:
            print(f"check-coverage: {problem}", file=sys.stderr)
        print(f"check-coverage: {len(problems)} of {counted} operations are not accounted for", file=sys.stderr)
        sys.exit(1)
    print(f"check-coverage: ok ({counted} operations across {len(SHIPPED)} shipped domains, {len(declined)} declined)")


if __name__ == "__main__":
    main()
