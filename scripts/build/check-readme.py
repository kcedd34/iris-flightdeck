#!/usr/bin/env python3
"""The README is a contract, and this is its gate (feature 006, contracts/readme-contract.md).

Two of the five published judging criteria — Clarity of Instructions and Developer Experience — are
decided by the README. It is also the only artifact in this repository that carries checkable facts
and is never compiled: the capability map, the descriptors and the domain coverage all fail a build
when they drift, and the front door does not.

What a gate over prose can enforce is presence, order and arithmetic. It cannot enforce that a
sentence is clear, or that two sentences lead with the interaction model. That is the cold read's
job (spec SC-005). This gate is the floor, the cold read is the ceiling, and neither substitutes for
the other — which is why the contract states the intent of every element, including the ones only a
human can judge.

Usage: check-readme.py
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
README = ROOT / "README.md"
LICENSE = ROOT / "LICENSE"
POLICY = ROOT / "backend" / "cls" / "FlightDeck" / "Capability" / "Policy.cls"
COVERAGE = ROOT / "docs" / "api-coverage.md"

# The marker the README carries while the Ideas Portal URL is an author action. The gate warns on it
# and still passes: a pending author action is not a build failure, but it must never be silent.
IDEA_PLACEHOLDER = "<!-- idea-link-pending -->"

# Element 8's groups. Each declined operation must fall in exactly one, and the README must name it.
DECLINED_GROUPS = {
    "encryption": lambda op: "/encryption" in op,
    "storage": lambda op: any(part in op for part in ("/database", "/namespace")),
}


def xdata(path, name):
    """Read a class's XData block as JSON, the way check-coverage.py does."""
    text = path.read_text(encoding="utf-8")
    start = text.index("XData " + name)
    body = text[text.index("{", start) + 1:].lstrip()
    document, _ = json.JSONDecoder().raw_decode(body)
    return document


def total_operations():
    """The official operations the coverage document assigns, which is the README's total."""
    rows = re.findall(r"^\|\s*(?:GET|PUT|POST|DELETE|PATCH)\s*\|\s*`([^`]+)`", COVERAGE.read_text(encoding="utf-8"), re.M)
    return len(rows)


def sentences(paragraph):
    """Sentence count, ignoring the dots inside code spans, links and abbreviations like v2.1."""
    text = re.sub(r"`[^`]*`", "X", paragraph)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"(?<=\d)\.(?=\d)", "", text)
    return [s for s in re.split(r"[.!?](?:\s|$)", text) if s.strip()]


class Readme:
    """The README as the gate sees it: raw text, plus where each anchor sits in it."""

    def __init__(self, text):
        self.text = text
        self.lines = text.splitlines()

    def find(self, pattern, flags=0):
        """Character offset of the first match, or None."""
        match = re.search(pattern, self.text, flags)
        return match.start() if match else None

    def heading(self, title):
        return self.find(rf"^##\s+{re.escape(title)}\s*$", re.M | re.I)

    def section(self, title):
        """The body of a `## ` section, up to the next `## `."""
        start = self.heading(title)
        if start is None:
            return ""
        body = self.text[start:]
        nxt = re.search(r"^##\s+", body[body.index("\n"):], re.M)
        return body[: nxt.start() + body.index("\n")] if nxt else body


def check_opening(readme, problems):
    """Element 1: two sentences, leading the page, with nothing between them and the title."""
    match = re.search(r"^#\s+.+?\n+(.+?)(?:\n\s*\n|\Z)", readme.text, re.S)
    if not match:
        problems.append("element 1 (what it is) — no paragraph follows the title")
        return None
    opening = match.group(1).strip()
    if opening.startswith(("-", "*", "!", "#", ">", "|")):
        problems.append("element 1 (what it is) — the first thing after the title is a list, image or quote, not a paragraph")
        return match.end()
    count = len(sentences(opening))
    if count > 2:
        problems.append(f"element 1 (what it is) — expected at most 2 sentences, found {count}")
    return match.end()


def check_image(readme, install_at, problems):
    """Element 2: the instrument cluster, above the fold and before installation."""
    at = readme.find(r"!\[[^\]]*\]\(docs/img/instruments\.[a-z0-9]+\)")
    if at is None:
        problems.append("element 2 (instrument cluster) — no image reference to docs/img/instruments.* found")
        return None
    if at > 1200:
        problems.append(f"element 2 (instrument cluster) — sits {at} characters in; it must be within the first 1200 to stay above the fold")
    if install_at is not None and at > install_at:
        problems.append("element 2 (instrument cluster) — appears after the installation section; it must come before it")
    return at


def check_install(readme, problems):
    """Element 3: container path first, package second, port conflict inside the section."""
    at = readme.heading("Install")
    if at is None:
        problems.append('element 3 (installation) — no "## Install" heading found')
        return None
    body = readme.section("Install")
    container = body.find("docker compose up")
    package = body.find('zpm "load')
    if container < 0:
        problems.append("element 3 (installation) — the one-command container path is not in the installation section")
    if package < 0:
        problems.append("element 3 (installation) — the package (IPM) path is not in the installation section")
    if container >= 0 and package >= 0 and package < container:
        problems.append("element 3 (installation) — the package path comes before the one-command path; the order is required")
    if not re.search(r"port .*(already )?(in use|allocated)|FLIGHTDECK_PORT", body, re.I):
        problems.append("element 3 (installation) — the port-conflict case is not documented inside the installation section")
    return at


def check_domains(readme, problems):
    """Element 4: exactly six domains, one line each."""
    at = readme.heading("The six domains")
    if at is None:
        problems.append('element 4 (the six domains) — no "## The six domains" heading found')
        return None
    items = re.findall(r"^[-*]\s+\S", readme.section("The six domains"), re.M)
    if len(items) != 6:
        problems.append(f'element 4 (the six domains) — expected 6 list items under "## The six domains", found {len(items)}')
    return at


def check_different(readme, problems):
    """Element 5: the five claims, each present by name."""
    at = readme.heading("What makes it different")
    if at is None:
        problems.append('element 5 (differentiators) — no "## What makes it different" heading found')
        return None
    body = readme.section("What makes it different").lower()
    for claim, needle in (
        ("command palette", "command palette"),
        ("entity graph", "entit"),
        ("dry-run with impact analysis", "dry run" if "dry run" in body else "dry-run"),
        ("safe mode", "safe mode"),
        ("unified log stream", "log stream"),
    ):
        if needle not in body:
            problems.append(f"element 5 (differentiators) — the claim '{claim}' is not stated")
    return at


def check_compatibility(readme, declined_count, total, problems):
    """Element 6: v2 required, both versions named, and the counts that must add up."""
    at = readme.heading("Compatibility")
    if at is None:
        problems.append('element 6 (compatibility) — no "## Compatibility" heading found')
        return None
    body = readme.section("Compatibility")
    if not re.search(r"\bv2\b", body):
        problems.append("element 6 (compatibility) — does not name SysAdmin API v2 as required")
    for version in ("2026.2", "2026.1"):
        if version not in body:
            problems.append(f"element 6 (compatibility) — does not name IRIS {version}")
    # Every row that declares a set of counts must be arithmetically sound and attributed to a version.
    rows = re.findall(r"^\|([^|\n]*\d{4}\.\d[^|\n]*)\|([^\n]*)\|\s*$", body, re.M)
    checked = 0
    for label, rest in rows:
        numbers = [int(n.replace(",", "")) for n in re.findall(r"\b(\d{1,4})\b", rest)]
        if len(numbers) < 4:
            continue
        allowed, unavailable, declined, declared = numbers[:4]
        checked += 1
        if allowed + unavailable + declined != declared:
            problems.append(
                f"element 6 (compatibility) —{label.strip()}: {allowed} + {unavailable} + {declined} = "
                f"{allowed + unavailable + declined}, declared total {declared}"
            )
        if declared != total:
            problems.append(f"element 6 (compatibility) —{label.strip()}: declared total {declared}, the API assigns {total}")
        if declined != declined_count:
            problems.append(f"element 6 (compatibility) —{label.strip()}: declares {declined} declined, the policy declines {declined_count}")
    if checked == 0:
        problems.append("element 6 (compatibility) — no table row declares allowed / withheld / declined / total against a version")
    return at


def check_executor(readme, problems):
    """Element 7: the exact phrase, because this is a claim about reach.

    Matched across line breaks: the README is hard-wrapped, so a required phrase routinely straddles
    two lines with the second indented. A gate that only matched it on one line would be asking the
    prose to wrap where the gate finds convenient.
    """
    at = readme.find(r"not\s+an\s+outbound\s+proxy")
    if at is None:
        problems.append('element 7 (REST executor) — the phrase "not an outbound proxy" does not appear')
    return at


def check_declined(readme, declined, problems):
    """Element 8: every declined operation accounted for, and the journal stated apart from them."""
    at = readme.heading("What FlightDeck declines to do")
    if at is None:
        problems.append('element 8 (declined operations) — no "## What FlightDeck declines to do" heading found')
        return None
    body = readme.section("What FlightDeck declines to do")
    groups = {name: [op for op in declined if test(op)] for name, test in DECLINED_GROUPS.items()}
    unaccounted = [op for op in declined if not any(op in ops for ops in groups.values())]
    for op in unaccounted:
        problems.append(f"element 8 (declined operations) — {op} falls in no group this gate knows; add it to DECLINED_GROUPS and to the README")
    for name, ops in groups.items():
        if not ops:
            continue
        if not re.search(rf"\b{name}\b", body, re.I):
            problems.append(f"element 8 (declined operations) — the {name} group ({len(ops)} operations) is not named")
        if str(len(ops)) not in body:
            problems.append(f"element 8 (declined operations) — the {name} group has {len(ops)} operations; that count does not appear")
    # The journal is not declined. It is the one place this project refuses to substitute a native
    # provider for an authorization decision, and flattening it into the list loses that statement.
    if "journal" not in body.lower():
        problems.append("element 8 (declined operations) — the journal statement is missing; it is a separate category, not a decline")
    return at


def check_idea(readme, warnings, problems):
    """Element 9: present in final wording, with the URL as a declared author action."""
    at = readme.find(r"Ideas Portal")
    if at is None:
        problems.append("element 9 (idea link) — the InterSystems Ideas Portal is not named")
        return None
    if IDEA_PLACEHOLDER in readme.text:
        warnings.append("element 9 (idea link) — the URL is still pending; this is an author action, due before submission")
    elif not re.search(r"\[[^\]]+\]\(https?://[^)]*ideas\.intersystems\.com[^)]*\)", readme.text):
        problems.append("element 9 (idea link) — no link to ideas.intersystems.com, and the pending marker is absent")
    return at


def check_license(readme, problems):
    at = readme.heading("License")
    if at is None:
        problems.append('element 10 (licence) — no "## License" heading found')
    elif "MIT" not in readme.section("License"):
        problems.append("element 10 (licence) — the License section does not name MIT")
    if not LICENSE.exists():
        problems.append("element 10 (licence) — the LICENSE file is missing from the repository root")
    return at


def main():
    if not README.exists():
        print("check-readme: README.md is missing", file=sys.stderr)
        sys.exit(1)
    readme = Readme(README.read_text(encoding="utf-8"))
    declined = list(xdata(POLICY, "Declined").keys())
    total = total_operations()

    problems, warnings = [], []
    # Installation is located first: elements 1 and 2 are checked against where it sits.
    install_at = check_install(readme, problems)
    positions = {
        1: check_opening(readme, problems),
        2: check_image(readme, install_at, problems),
        3: install_at,
        4: check_domains(readme, problems),
        5: check_different(readme, problems),
        6: check_compatibility(readme, len(declined), total, problems),
        7: check_executor(readme, problems),
        8: check_declined(readme, declined, problems),
        9: check_idea(readme, warnings, problems),
        10: check_license(readme, problems),
    }

    # Order is the requirement a well-meaning edit is most likely to break, so a violation names both
    # neighbours rather than only the element that moved.
    names = {
        1: "what it is", 2: "instrument cluster", 3: "installation", 4: "the six domains",
        5: "differentiators", 6: "compatibility", 7: "REST executor", 8: "declined operations",
        9: "idea link", 10: "licence",
    }
    ordered = [(n, at) for n, at in sorted(positions.items()) if at is not None]
    for (before, at_before), (after, at_after) in zip(ordered, ordered[1:]):
        if at_after < at_before:
            problems.append(
                f"order — element {after} ({names[after]}) appears before element {before} ({names[before]}); "
                f"the README's order is the requirement"
            )

    for warning in warnings:
        print(f"check-readme: warning: {warning}")
    if problems:
        for problem in problems:
            print(f"check-readme: {problem}", file=sys.stderr)
        print(f"check-readme: {len(problems)} problem(s)", file=sys.stderr)
        sys.exit(1)
    pending = "; idea link pending — author action" if warnings else ""
    print(f"check-readme: ok (10 elements, in order{pending})")


if __name__ == "__main__":
    main()
