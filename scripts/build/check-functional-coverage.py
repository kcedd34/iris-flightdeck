#!/usr/bin/env python3
"""Every shipped operation must have been executed and had its effect read back (feature 008).

`check-coverage.py` asks whether an operation is reachable, and the answer has been yes for all 268
of them. This asks whether anything has ever actually run it, and the first measurement said no for
165 — the gate reported them covered because a descriptor existed.

The difference matters here for a reason with three examples behind it. This project has shipped a
canvas series that never drew and passed every assertion about it, a correlation test whose skip was
always taken so its assertions never ran, and a static server that double-encoded every asset because
no test ever fetched one from it. All three are the same failure: verification that cannot fail.

**This gate detects and fails. It never repairs anything.** It writes no test, edits no test and
adjusts no expectation. A mechanism that fixed its own findings would end up making the test pass
rather than making the operation work, which is how the three defects above survived.

Evidence comes from `frontend/e2e/setup/effect.ts`, which appends to the record only after a test has
re-read the object through the official API and asserted on it. Mentioning an operation proves
nothing here; the record is written by execution.

Usage: check-functional-coverage.py
Requires a Playwright run first, the way check-dist requires a build.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COVERAGE = ROOT / "docs" / "api-coverage.md"
POLICY = ROOT / "backend" / "cls" / "FlightDeck" / "Capability" / "Policy.cls"
RECORD = ROOT / "frontend" / "test-results" / "effects.ndjson"
EXEMPTIONS = ROOT / "scripts" / "build" / "functional-exemptions.json"

# Section heading -> the feature that ships it, exactly as check-coverage.py counts them.
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
    return json.JSONDecoder().raw_decode(body)[0]


def operations_by_section():
    sections, current = {}, None
    for line in COVERAGE.read_text(encoding="utf-8").splitlines():
        heading = re.match(r"^##\s+(.+?)\s*$", line)
        if heading:
            current = heading.group(1).split(" — ")[0]
            if current in SHIPPED:
                sections.setdefault(current, [])
        row = ROW.match(line)
        if row and current in SHIPPED:
            sections[current].append(f"{row.group(1)} {row.group(2)}")
    return sections


def verified():
    """Operations a test executed and read back, from the record the effect helper writes."""
    if not RECORD.exists():
        return None
    seen = {}
    for line in RECORD.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        operation = entry.get("operationId")
        if operation:
            seen.setdefault(operation, []).append(entry)
    return seen


def exemptions():
    """Operations excused by name, each with its own written reason.

    Never a generic tolerated list: a list that accepts "the rest" grows until the gate means
    nothing. Every entry here names one operation and says why no test can execute it.
    """
    if not EXEMPTIONS.exists():
        return {}
    declared = json.loads(EXEMPTIONS.read_text(encoding="utf-8"))
    return {operation: entry["reason"] for operation, entry in declared.items()}


def main():
    sections = operations_by_section()
    record = verified()
    if record is None:
        print(
            f"check-functional-coverage: no execution record at {RECORD.relative_to(ROOT)}.\n"
            "  This gate reads what the end-to-end suite actually ran. Run it first:\n"
            "    cd frontend && npx playwright test",
            file=sys.stderr,
        )
        sys.exit(1)

    excused = exemptions()
    declined = set(xdata(POLICY, "Declined"))
    problems, counted, proven, excused_count = [], 0, 0, 0

    for section, operations in sections.items():
        for operation in operations:
            counted += 1
            if operation in record:
                proven += 1
                continue
            if operation in excused:
                excused_count += 1
                continue
            why = " (declined by policy, but not declared in the exemptions file)" if operation in declined else ""
            problems.append(f"{operation} ({section}) was never executed with its effect verified{why}")

    for operation in sorted(set(excused) - {o for ops in sections.values() for o in ops}):
        problems.append(f"{operation} is exempted but is not a shipped operation; remove the exemption")

    for operation in sorted(set(excused) & set(record)):
        problems.append(f"{operation} is exempted but a test does verify it; remove the exemption")

    if problems:
        for problem in problems:
            print(f"check-functional-coverage: {problem}", file=sys.stderr)
        print(
            f"check-functional-coverage: {len(problems)} of {counted} operations are not functionally covered",
            file=sys.stderr,
        )
        sys.exit(1)

    print(
        f"check-functional-coverage: ok ({proven} of {counted} operations executed and verified, "
        f"{excused_count} exempted by name)"
    )


if __name__ == "__main__":
    main()
