"""Unit tests for verify_platform.py. No container needed: probes are fakes."""
import os
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_report  # noqa: E402
import verify_platform as vp  # noqa: E402


def fake(classification, raw=None, **extra):
    def run():
        if classification == "raise":
            raise ValueError("boom")
        return {"classification": classification, "raw": raw, "finding": {}, **extra}
    return run


def probes(overrides=None):
    overrides = overrides or {}
    out = []
    for pid, key, title in vp.PROBE_KEYS:
        fn = overrides.get(pid, fake(vp.PRESENT))
        if pid == 2 and pid not in overrides:
            fn = fake(vp.PRESENT, candidates=[
                {"key": "in_process", "classification": vp.PRESENT, "raw": None, "notes": ""},
                {"key": "jwt", "classification": vp.PRESENT, "raw": None, "notes": ""},
                {"key": "loopback_proxy", "classification": vp.ABSENT, "raw": "404", "notes": ""},
            ])
        out.append((pid, key, title, fn))
    return out


TARGET = {"baseUrl": "http://x", "label": "t", "product": "iris", "serverVersion": "2026.2", "apiVersion": 2}


class Aggregation(unittest.TestCase):
    def test_first_present_candidate_is_selected(self):
        cands = [{"key": "in_process", "classification": vp.ABSENT}, {"key": "jwt", "classification": vp.PRESENT},
                 {"key": "loopback_proxy", "classification": vp.PRESENT}]
        self.assertEqual(vp.aggregate_candidates(cands), (vp.PRESENT, "jwt"))

    def test_all_absent_is_absent(self):
        cands = [{"key": k, "classification": vp.ABSENT} for k in ("in_process", "jwt", "loopback_proxy")]
        self.assertEqual(vp.aggregate_candidates(cands), (vp.ABSENT, None))

    def test_mixed_absent_and_inconclusive_is_inconclusive(self):
        cands = [{"key": "in_process", "classification": vp.INCONCLUSIVE}, {"key": "jwt", "classification": vp.ABSENT},
                 {"key": "loopback_proxy", "classification": vp.ABSENT}]
        self.assertEqual(vp.aggregate_candidates(cands), (vp.INCONCLUSIVE, None))


class RunAndReport(unittest.TestCase):
    def test_all_present_exits_zero_and_validates(self):
        report = vp.build_report(vp.run_probes(probes()), TARGET)
        self.assertEqual(report["summary"]["exitCode"], 0)
        self.assertEqual(validate_report.validate(report), [])

    def test_fault_keeps_running_all_probes(self):
        results = vp.run_probes(probes(), fault=3)
        self.assertEqual([r.id for r in results], list(range(1, 9)))
        self.assertEqual(results[2].classification, vp.INCONCLUSIVE)
        self.assertIn("Injected fault", results[2].raw)
        report = vp.build_report(results, TARGET)
        self.assertEqual(report["summary"]["exitCode"], 1)
        self.assertEqual(validate_report.validate(report), [])

    def test_exception_in_probe_two_still_yields_three_candidates(self):
        results = vp.run_probes(probes({2: fake("raise")}))
        self.assertEqual(len(results[1].candidates), 3)
        self.assertEqual(validate_report.validate(vp.build_report(results, TARGET)), [])

    def test_absent_without_raw_gets_placeholder(self):
        results = vp.run_probes(probes({5: fake(vp.ABSENT)}))
        self.assertTrue(results[4].raw)

    def test_absent_is_not_inconclusive_for_exit_code(self):
        report = vp.build_report(vp.run_probes(probes({8: fake(vp.ABSENT, "404")})), TARGET)
        self.assertEqual(report["summary"]["exitCode"], 0)


class Redaction(unittest.TestCase):
    def test_basic_and_bearer_are_redacted(self):
        text = "Authorization: Basic X1NZU1RFTTpTWVM=\nauthorization: Bearer eyJ.abc.def"
        out = vp.redact(text)
        self.assertNotIn("X1NZU1RFTTpTWVM=", out)
        self.assertNotIn("eyJ.abc.def", out)

    def test_password_env_value_is_redacted(self):
        os.environ["FD_VERIFY_PASSWORD"] = "s3cret-value"
        try:
            self.assertNotIn("s3cret-value", vp.redact('login failed for s3cret-value {"password":"x"}'))
        finally:
            del os.environ["FD_VERIFY_PASSWORD"]

    def test_raw_is_capped(self):
        self.assertLessEqual(len(vp.redact("x" * 20000)), vp.RAW_LIMIT)


if __name__ == "__main__":
    unittest.main()
