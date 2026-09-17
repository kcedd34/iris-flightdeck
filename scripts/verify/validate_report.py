#!/usr/bin/env python3
"""Structural validator for FlightDeck verification reports.

Checks the rules of specs/001-foundation-shell/contracts/verification-report.schema.json with the
standard library only. Usage: validate_report.py REPORT.json [...]. Exit 1 on any violation.
"""
import json
import sys

KEYS = ["admin_api", "auth_path", "resource_shapes", "async_db_metrics", "wallet", "mgmnt_api", "log_sources", "audit_enabled"]
CLASSES = {"confirmed_present", "confirmed_absent", "inconclusive"}


def validate(report: dict) -> list[str]:
    errors = []
    if report.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1")
    target = report.get("target", {})
    for k in ("baseUrl", "product", "serverVersion", "apiVersion", "label"):
        if k not in target:
            errors.append(f"target.{k} missing")
    if "@" in str(target.get("baseUrl", "")):
        errors.append("target.baseUrl must not contain credentials")
    probes = report.get("probes", [])
    if len(probes) != 8:
        errors.append(f"expected 8 probes, found {len(probes)}")
    counts = {c: 0 for c in CLASSES}
    for index, p in enumerate(probes, start=1):
        where = f"probe {index}"
        if p.get("id") != index or (index <= 8 and p.get("key") != KEYS[index - 1]):
            errors.append(f"{where}: out of order (id={p.get('id')}, key={p.get('key')})")
        cls = p.get("classification")
        if cls not in CLASSES:
            errors.append(f"{where}: invalid classification {cls!r}")
            continue
        counts[cls] += 1
        raw = p.get("raw")
        if cls != "confirmed_present" and not raw:
            errors.append(f"{where}: raw is required when {cls}")
        if raw is not None and len(raw) > 8192:
            errors.append(f"{where}: raw exceeds 8192 characters")
        if raw and ("Basic " in raw and "[REDACTED]" not in raw):
            errors.append(f"{where}: raw may contain an unredacted Authorization value")
        if not isinstance(p.get("finding"), dict):
            errors.append(f"{where}: finding must be an object")
        if not isinstance(p.get("durationMs"), int):
            errors.append(f"{where}: durationMs must be an integer")
        if index == 2:
            cands = p.get("candidates") or []
            if [c.get("key") for c in cands] != ["in_process", "jwt", "loopback_proxy"]:
                errors.append("probe 2: candidates must be in_process, jwt, loopback_proxy")
            for c in cands:
                if c.get("classification") not in CLASSES:
                    errors.append(f"probe 2 candidate {c.get('key')}: invalid classification")
                elif c["classification"] != "confirmed_present" and not c.get("raw"):
                    errors.append(f"probe 2 candidate {c.get('key')}: raw required")
    summary = report.get("summary", {})
    if summary.get("counts") != counts:
        errors.append(f"summary.counts {summary.get('counts')} does not match probes {counts}")
    if summary.get("exitCode") != (1 if counts["inconclusive"] else 0):
        errors.append("summary.exitCode inconsistent with inconclusive count")
    return errors


def main(paths: list[str]) -> int:
    if not paths:
        print("usage: validate_report.py REPORT.json [...]", file=sys.stderr)
        return 2
    failed = False
    for path in paths:
        with open(path, encoding="utf-8") as fh:
            errors = validate(json.load(fh))
        if errors:
            failed = True
            print(f"{path}: INVALID")
            for e in errors:
                print(f"  - {e}")
        else:
            print(f"{path}: valid")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
