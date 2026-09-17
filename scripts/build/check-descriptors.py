#!/usr/bin/env python3
"""Offline check of FlightDeck's declarative descriptors (feature 002 research R3, data-model §1).

Mirrors FlightDeck.Domain.Descriptor.Validate so a bad descriptor fails the build, not a request:
  - every operationId exists in the generated capability data (FlightDeck.Capability.Spec);
  - no descriptor states a privilege (Constitution III: privileges come only from the capability map);
  - entity types have keys; delete and request mutations, and graded ones, have a target;
  - predicates use known operators and allowed path roots.

Usage: check-descriptors.py [entity-types.cls mutations.cls]   (defaults: the shipped classes)
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CLS = ROOT / "backend" / "cls" / "FlightDeck"
SPEC = CLS / "Capability" / "Spec.cls"
ENTITY_TYPES = CLS / "Domain" / "EntityTypes.cls"
MUTATIONS = CLS / "Mutation" / "Descriptors.cls"
FORBIDDEN = {"requires", "privilege", "privileges", "resource", "permission", "permissions"}
OPERATORS = {"true", "and", "or", "not", "equals", "in", "defined", "empty", "contains", "changed", "bitsCleared", "lacksTargetRole"}


def xdata(path, name):
    text = path.read_text(encoding="utf-8")
    start = text.index("XData " + name)
    body = text[text.index("{", start) + 1:].lstrip()
    # Decode exactly one JSON document; the XData block's own closing brace follows it.
    document, _ = json.JSONDecoder().raw_decode(body)
    return document


def forbidden(node, where, problems):
    if isinstance(node, dict):
        for key, value in node.items():
            if key.lower() in FORBIDDEN:
                problems.append(f"{where} declares '{key}': privileges come only from the capability map")
            forbidden(value, where, problems)
    elif isinstance(node, list):
        for value in node:
            forbidden(value, where, problems)


def predicate(expr, roots):
    if not isinstance(expr, dict):
        return "predicate is not an object"
    op = expr.get("op")
    if op not in OPERATORS:
        return f"unknown operator '{op}'"
    if op in ("and", "or"):
        for part in expr.get("all" if op == "and" else "any", []):
            problem = predicate(part, roots)
            if problem:
                return problem
        return ""
    if op == "not":
        return predicate(expr.get("expr"), roots)
    for key in ("path", "bitsPath", "rolePath"):
        if key in expr and expr[key].split(".")[0] not in roots:
            return f"path '{expr[key]}' is outside {','.join(sorted(roots))}"
    return ""


def main():
    entity_path = Path(sys.argv[1]) if len(sys.argv) > 2 else ENTITY_TYPES
    mutation_path = Path(sys.argv[2]) if len(sys.argv) > 2 else MUTATIONS
    operations = {op["operationId"] for op in xdata(SPEC, "Operations")}
    entity_types = xdata(entity_path, "EntityTypes")
    mutations = xdata(mutation_path, "Mutations")
    problems = []
    for tid, t in entity_types.items():
        forbidden(t, f"entity type {tid}", problems)
        for key in ("listOperation", "detailOperation"):
            if key in t and t[key] not in operations:
                problems.append(f"entity type {tid} {key} names unknown operation '{t[key]}'")
        if not t.get("keys"):
            problems.append(f"entity type {tid} has no keys")
        for marker in t.get("markers", []):
            problem = predicate(marker.get("when"), {"object", "facts"})
            if problem:
                problems.append(f"entity type {tid} marker {marker.get('id')}: {problem}")
        for op in t.get("mutations", []):
            if op not in mutations:
                problems.append(f"entity type {tid} names mutation {op} without a descriptor")
    for op, m in mutations.items():
        forbidden(m, f"mutation {op}", problems)
        if m.get("kind") != "request":
            for candidate in (op, m.get("readOperation")):
                if candidate not in operations:
                    problems.append(f"mutation {op} names unknown operation '{candidate}'")
        if (m.get("kind") in ("delete", "request") or "grade" in m) and not m.get("target"):
            problems.append(f"mutation {op} has no target")
        if "impactWhen" in m:
            problem = predicate(m["impactWhen"], {"current", "proposed", "isSystem", "isFlightDeck", "facts", "request", "kind"})
            if problem:
                problems.append(f"mutation {op} impactWhen: {problem}")
        for key in ("grade", "selfProtection"):
            for rule in m.get(key, []):
                problem = predicate(rule.get("when"), {"current", "proposed", "isSystem", "isFlightDeck", "facts", "request", "kind"})
                if problem:
                    problems.append(f"mutation {op} {key}: {problem}")
    if problems:
        for p in problems:
            print(f"check-descriptors: {p}", file=sys.stderr)
        sys.exit(1)
    print(f"check-descriptors: ok ({len(entity_types)} entity types, {len(mutations)} mutations)")


if __name__ == "__main__":
    main()
