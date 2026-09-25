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
FUNCTIONAL = ROOT / "verification" / "functional-coverage.md"
MODULE = ROOT / "module.xml"

# Where each fast-path line must lead. The fast path is for a reader with a few minutes, so a line
# that stops leading where it says is worse than no line.
FAST_PATH_TARGETS = {
    "the live demo": r"\(#try-it-without-installing-anything\)",
    "the install": r"\(#install\)",
    "the coverage by domain": r"\(docs/api-coverage\.md\)",
    "the functional coverage": r"\(verification/functional-coverage\.md\)",
    "the platform findings": r"\(verification/README\.md[^)]*\)",
}

# Element 11's groups. Each declined operation must fall in exactly one, and the README must name it.
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


def functional_counts():
    """Verified, exempt and open, as the functional-coverage record states them."""
    text = FUNCTIONAL.read_text(encoding="utf-8")
    counts = {}
    for key, pattern in (
        ("verified", r"^\|\s*Executed by a test[^|]*\|\s*\*\*(\d+)\*\*"),
        ("exempt", r"^\|\s*Exempt by name[^|]*\|\s*\*\*(\d+)\*\*"),
        ("open", r"^\|\s*No such test yet\s*\|\s*\*\*(\d+)\*\*"),
    ):
        match = re.search(pattern, text, re.M)
        counts[key] = int(match.group(1)) if match else None
    return counts


def module_version():
    match = re.search(r"<Version>([^<]+)</Version>", MODULE.read_text(encoding="utf-8"))
    return match.group(1).strip() if match else None


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


def blocks(text):
    """Blank-line separated blocks, each with its start offset."""
    return [(m.start(), m.group(0).strip()) for m in re.finditer(r"(?:^[^\n]*\S[^\n]*\n?)+", text, re.M)]


def top(readme):
    """The blocks between the title and the first `## ` heading, which is everything above the fold."""
    title = re.search(r"^#\s+.+$", readme.text, re.M)
    if not title:
        return []
    heading = re.search(r"^##\s+", readme.text, re.M)
    end = heading.start() if heading else len(readme.text)
    return [(title.end() + at, body) for at, body in blocks(readme.text[title.end():end])]


def check_fast_path(readme, total, problems):
    """Element 1: at most five linked lines, leading the page, pointing where they say."""
    head = top(readme)
    if not head or not head[0][1].startswith(("- ", "* ")):
        problems.append("element 1 (fast path) — the first thing after the title is not a list")
        return None
    at, body = head[0]
    items = re.findall(r"^[-*]\s+.*(?:\n(?![-*]\s).*)*", body, re.M)
    if len(items) > 5:
        problems.append(f"element 1 (fast path) — expected at most 5 lines, found {len(items)}")
    for item in items:
        if not re.search(r"\]\([^)]+\)", item):
            problems.append(f"element 1 (fast path) — a line carries no link: {item[:60]!r}")
    for name, target in FAST_PATH_TARGETS.items():
        if not re.search(target, body):
            problems.append(f"element 1 (fast path) — no line links to {name}")
    # The numbers a reader will quote are checked against the records they summarise.
    if not re.search(rf"\b{total}\b", body):
        problems.append(f"element 1 (fast path) — does not state the {total} operations the coverage document assigns")
    for key, value in functional_counts().items():
        if value is None:
            problems.append(f"element 1 (fast path) — verification/functional-coverage.md states no '{key}' count")
        elif not re.search(rf"\b{value}\b", body):
            problems.append(f"element 1 (fast path) — the functional coverage has {value} {key}; that count does not appear")
    version = module_version()
    if version and version not in body:
        problems.append(f"element 1 (fast path) — does not state version {version}, which module.xml declares")
    return at


def check_pitch(readme, problems):
    """Element 2: three sentences, straight after the fast path."""
    head = top(readme)
    if len(head) < 2 or head[1][1].startswith(("-", "*", "!", "#", ">", "|")):
        problems.append("element 2 (what it does) — no paragraph follows the fast path")
        return None
    at, body = head[1]
    count = len(sentences(body))
    if count != 3:
        problems.append(f"element 2 (what it does) — expected 3 sentences, found {count}")
    for needle in ("logs", "security", "server"):
        if needle not in body.lower():
            problems.append(f"element 2 (what it does) — does not mention {needle}")
    return at


def check_image(readme, install_at, problems):
    """Element 3: the instrument cluster, above the fold.

    The fold used to be a character count. The fast path's link targets inflate that count without
    taking a rendered line, so it is now structural: nothing but the fast path and the paragraph
    under it may stand between the title and the cluster.
    """
    at = readme.find(r"!\[[^\]]*\]\(docs/img/instruments\.[a-z0-9]+\)")
    if at is None:
        problems.append("element 3 (instrument cluster) — no image reference to docs/img/instruments.* found")
        return None
    head = top(readme)
    if len(head) < 3 or head[2][0] != at:
        problems.append("element 3 (instrument cluster) — it must be the third block after the title, right after the fast path and the paragraph under it")
    if install_at is not None and at > install_at:
        problems.append("element 3 (instrument cluster) — appears after the installation section; it must come before it")
    return at


def check_opening(readme, problems):
    """Element 4: what it is, at most two sentences, right under the cluster; then the no-video line."""
    head = top(readme)
    if len(head) < 4 or head[3][1].startswith(("-", "*", "!", "#", ">", "|")):
        problems.append("element 4 (what it is) — no paragraph follows the instrument cluster")
        return None
    at, body = head[3]
    count = len(sentences(body))
    if count > 2:
        problems.append(f"element 4 (what it is) — expected at most 2 sentences, found {count}")
    # The contest asks for a video or a description. The choice is stated, and points at the description.
    rest = " ".join(b for _, b in head[4:])
    if "no video" not in rest.lower() or "(#a-tour-in-place-of-a-video)" not in rest:
        problems.append("element 4 (what it is) — the statement that there is no video, linking to the tour, is missing above the installation section")
    return at


def check_tour(readme, problems):
    """Element 8: the description of how it works, which stands in for the video."""
    at = readme.heading("A tour, in place of a video")
    if at is None:
        problems.append('element 8 (tour) — no "## A tour, in place of a video" heading found')
        return None
    steps = re.findall(r"^\d+\.\s+\S", readme.section("A tour, in place of a video"), re.M)
    if len(steps) < 6:
        problems.append(f"element 8 (tour) — expected a numbered walk-through, found {len(steps)} steps")
    return at


def check_install(readme, problems):
    """Element 5: container path first, package second, port conflict inside the section."""
    at = readme.heading("Install")
    if at is None:
        problems.append('element 5 (installation) — no "## Install" heading found')
        return None
    body = readme.section("Install")
    container = body.find("docker compose up")
    # The published package name, which does not change once it is on the registry: the evaluator's
    # command is `zpm "install iris-flightdeck"`. `zpm "load <path>"` is the from-a-clone variant and
    # is not what the README must lead the package path with.
    package = body.find('zpm "install iris-flightdeck"')
    if container < 0:
        problems.append("element 5 (installation) — the one-command container path is not in the installation section")
    if package < 0:
        problems.append('element 5 (installation) — the package path does not give `zpm "install iris-flightdeck"`, which is the published command')
    if container >= 0 and package >= 0 and package < container:
        problems.append("element 5 (installation) — the package path comes before the one-command path; the order is required")
    version = module_version()
    if version and f"**{version}**" not in body:
        problems.append(f"element 5 (installation) — the package path does not state the current version, {version}, as module.xml declares it")
    if not re.search(r"port .*(already )?(in use|allocated)|FLIGHTDECK_PORT", body, re.I):
        problems.append("element 5 (installation) — the port-conflict case is not documented inside the installation section")
    return at


def check_domains(readme, problems):
    """Element 6: exactly six domains, one line each."""
    at = readme.heading("The six domains")
    if at is None:
        problems.append('element 6 (the six domains) — no "## The six domains" heading found')
        return None
    items = re.findall(r"^[-*]\s+\S", readme.section("The six domains"), re.M)
    if len(items) != 6:
        problems.append(f'element 6 (the six domains) — expected 6 list items under "## The six domains", found {len(items)}')
    return at


def check_different(readme, problems):
    """Element 7: the five claims, each present by name."""
    at = readme.heading("What makes it different")
    if at is None:
        problems.append('element 7 (differentiators) — no "## What makes it different" heading found')
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
            problems.append(f"element 7 (differentiators) — the claim '{claim}' is not stated")
    return at


def check_compatibility(readme, declined_count, total, problems):
    """Element 9: v2 required, both versions named, and the counts that must add up."""
    at = readme.heading("Compatibility")
    if at is None:
        problems.append('element 9 (compatibility) — no "## Compatibility" heading found')
        return None
    body = readme.section("Compatibility")
    if not re.search(r"\bv2\b", body):
        problems.append("element 9 (compatibility) — does not name SysAdmin API v2 as required")
    for version in ("2026.2", "2026.1"):
        if version not in body:
            problems.append(f"element 9 (compatibility) — does not name IRIS {version}")
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
                f"element 9 (compatibility) —{label.strip()}: {allowed} + {unavailable} + {declined} = "
                f"{allowed + unavailable + declined}, declared total {declared}"
            )
        if declared != total:
            problems.append(f"element 9 (compatibility) —{label.strip()}: declared total {declared}, the API assigns {total}")
        if declined != declined_count:
            problems.append(f"element 9 (compatibility) —{label.strip()}: declares {declined} declined, the policy declines {declined_count}")
    if checked == 0:
        problems.append("element 9 (compatibility) — no table row declares allowed / withheld / declined / total against a version")
    return at


def check_executor(readme, problems):
    """Element 10: the exact phrase, because this is a claim about reach.

    Matched across line breaks: the README is hard-wrapped, so a required phrase routinely straddles
    two lines with the second indented. A gate that only matched it on one line would be asking the
    prose to wrap where the gate finds convenient.
    """
    at = readme.find(r"not\s+an\s+outbound\s+proxy")
    if at is None:
        problems.append('element 10 (REST executor) — the phrase "not an outbound proxy" does not appear')
    return at


def check_declined(readme, declined, problems):
    """Element 11: every declined operation accounted for, and the journal stated apart from them."""
    at = readme.heading("What FlightDeck declines to do")
    if at is None:
        problems.append('element 11 (declined operations) — no "## What FlightDeck declines to do" heading found')
        return None
    body = readme.section("What FlightDeck declines to do")
    groups = {name: [op for op in declined if test(op)] for name, test in DECLINED_GROUPS.items()}
    unaccounted = [op for op in declined if not any(op in ops for ops in groups.values())]
    for op in unaccounted:
        problems.append(f"element 11 (declined operations) — {op} falls in no group this gate knows; add it to DECLINED_GROUPS and to the README")
    for name, ops in groups.items():
        if not ops:
            continue
        if not re.search(rf"\b{name}\b", body, re.I):
            problems.append(f"element 11 (declined operations) — the {name} group ({len(ops)} operations) is not named")
        if str(len(ops)) not in body:
            problems.append(f"element 11 (declined operations) — the {name} group has {len(ops)} operations; that count does not appear")
    # The journal is not declined. It is the one place this project refuses to substitute a native
    # provider for an authorization decision, and flattening it into the list loses that statement.
    if "journal" not in body.lower():
        problems.append("element 11 (declined operations) — the journal statement is missing; it is a separate category, not a decline")
    return at



def check_license(readme, problems):
    at = readme.heading("License")
    if at is None:
        problems.append('element 12 (licence) — no "## License" heading found')
    elif "MIT" not in readme.section("License"):
        problems.append("element 12 (licence) — the License section does not name MIT")
    if not LICENSE.exists():
        problems.append("element 12 (licence) — the LICENSE file is missing from the repository root")
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
        1: check_fast_path(readme, total, problems),
        2: check_pitch(readme, problems),
        3: check_image(readme, install_at, problems),
        4: check_opening(readme, problems),
        5: install_at,
        6: check_domains(readme, problems),
        7: check_different(readme, problems),
        8: check_tour(readme, problems),
        9: check_compatibility(readme, len(declined), total, problems),
        10: check_executor(readme, problems),
        11: check_declined(readme, declined, problems),
        12: check_license(readme, problems),
    }

    # Order is the requirement a well-meaning edit is most likely to break, so a violation names both
    # neighbours rather than only the element that moved.
    names = {
        1: "fast path", 2: "what it does", 3: "instrument cluster", 4: "what it is", 5: "installation",
        6: "the six domains", 7: "differentiators", 8: "tour", 9: "compatibility", 10: "REST executor",
        11: "declined operations", 12: "licence",
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
    print(f"check-readme: ok ({len(positions)} elements, in order)")


if __name__ == "__main__":
    main()
