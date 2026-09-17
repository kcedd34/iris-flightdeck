#!/usr/bin/env python3
"""FlightDeck day-1 platform verification (docs/prd.md section 14, feature 001 User Story 1).

Runs eight probes in a fixed order against one IRIS instance, never aborts on a probe error,
classifies each probe as confirmed_present, confirmed_absent or inconclusive, records the raw
error or response for every non-present result, writes a JSON report
(contracts/verification-report.schema.json) and exits 1 if any probe is inconclusive.

Usage:
  verify_platform.py --base-url http://localhost:52773 --container <name> --label <label> [--out FILE]

Credentials come from FD_VERIFY_USER / FD_VERIFY_PASSWORD (defaults _SYSTEM / SYS for a local
throwaway container). They are never written to the report or to stdout.
FD_VERIFY_FAULT=<n> makes probe n raise, to prove the script keeps going.

Python 3.10+, standard library only.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import http.cookiejar
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

PRESENT = "confirmed_present"
ABSENT = "confirmed_absent"
INCONCLUSIVE = "inconclusive"
RAW_LIMIT = 8192
HTTP_TIMEOUT = 30
EXEC_TIMEOUT = 180
PROBE_DIR = Path(__file__).resolve().parent / "probes"
ROOT = Path(__file__).resolve().parents[2]

PROBE_KEYS = [
    (1, "admin_api", "SysAdmin API exists and responds, and the IRIS version"),
    (2, "auth_path", "Authentication path that works without storing credentials"),
    (3, "resource_shapes", "Real shape of system-resources statistics and shared-memory usage"),
    (4, "async_db_metrics", "Asynchronous database-metrics cycle"),
    (5, "wallet", "Wallet endpoints respond"),
    (6, "mgmnt_api", "REST management/discovery API is available"),
    (7, "log_sources", "messages.log, alerts and interoperability event log locations"),
    (8, "audit_enabled", "Whether auditing is enabled"),
]

SPEC_SHAPES = {
    "systemResources": {"Name", "Seize", "Nseize", "Aseize", "Bseize", "BusySet"},
    "sharedMemory": {"Description", "SMHAllocated", "SMHAvailable", "SMHUsed", "SMTUsed", "GSTUsed", "AllUsed"},
}


# --------------------------------------------------------------------------------------------
# Result model
# --------------------------------------------------------------------------------------------


class ProbeOutcome(Exception):
    """Raised inside a probe to finish it with a classification."""

    def __init__(self, classification: str, raw: str | None = None, finding: dict | None = None):
        super().__init__(classification)
        self.classification = classification
        self.raw = raw
        self.finding = finding or {}


@dataclass
class Result:
    id: int
    key: str
    title: str
    classification: str = INCONCLUSIVE
    finding: dict = field(default_factory=dict)
    raw: str | None = None
    durationMs: int = 0
    candidates: list | None = None

    def as_json(self) -> dict:
        data = {
            "id": self.id,
            "key": self.key,
            "title": self.title,
            "classification": self.classification,
            "finding": self.finding,
            "raw": self.raw,
            "durationMs": self.durationMs,
        }
        if self.candidates is not None:
            data["candidates"] = self.candidates
        return data


def redact(text: str | None) -> str | None:
    """Strip credentials and cap size. Applied to every raw value before it is stored."""
    if text is None:
        return None
    text = re.sub(r"(?i)(authorization:\s*)(basic|bearer)\s+[A-Za-z0-9+/=._-]+", r"\1\2 [REDACTED]", text)
    text = re.sub(r'(?i)("password"\s*:\s*)"[^"]*"', r'\1"[REDACTED]"', text)
    password = os.environ.get("FD_VERIFY_PASSWORD")
    if password:
        text = text.replace(password, "[REDACTED]")
    if len(text) > RAW_LIMIT:
        text = text[: RAW_LIMIT - 14] + "...[truncated]"
    return text


def aggregate_candidates(candidates: list[dict]) -> tuple[str, str | None]:
    """Probe 2 classification from its three candidates (data-model section 1)."""
    selected = next((c["key"] for c in candidates if c["classification"] == PRESENT), None)
    if selected:
        return PRESENT, selected
    if all(c["classification"] == ABSENT for c in candidates):
        return ABSENT, None
    return INCONCLUSIVE, None


def run_probes(probes: list[tuple[int, str, str, Callable[[], dict]]], fault: int | None = None) -> list[Result]:
    """Run every probe in order. A failing probe never stops the next one (FR-002)."""
    results = []
    for pid, key, title, fn in probes:
        result = Result(pid, key, title)
        started = time.monotonic()
        try:
            if fault == pid:
                raise RuntimeError(f"Injected fault in probe {pid} (FD_VERIFY_FAULT)")
            out = fn()
            result.classification = out.get("classification", PRESENT)
            result.finding = out.get("finding", {})
            result.raw = out.get("raw")
            result.candidates = out.get("candidates")
        except ProbeOutcome as outcome:
            result.classification = outcome.classification
            result.raw = outcome.raw
            result.finding = outcome.finding
        except Exception as exc:  # noqa: BLE001 - every error must become a classification
            result.classification = INCONCLUSIVE
            result.raw = f"{type(exc).__name__}: {exc}"
        if pid == 2 and result.candidates is None:
            result.candidates = [
                {"key": k, "classification": INCONCLUSIVE, "raw": result.raw or "Probe did not run", "notes": "Not reached"}
                for k in ("in_process", "jwt", "loopback_proxy")
            ]
        if result.classification != PRESENT and not result.raw:
            result.raw = "No raw response captured"
        result.raw = redact(result.raw)
        if result.candidates:
            for c in result.candidates:
                c["raw"] = redact(c.get("raw"))
        result.durationMs = int((time.monotonic() - started) * 1000)
        results.append(result)
    return results


def build_report(results: list[Result], target: dict) -> dict:
    counts = {PRESENT: 0, ABSENT: 0, INCONCLUSIVE: 0}
    for r in results:
        counts[r.classification] += 1
    return {
        "schemaVersion": 1,
        "generatedAt": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "target": target,
        "probes": [r.as_json() for r in results],
        "summary": {"counts": counts, "exitCode": 1 if counts[INCONCLUSIVE] else 0},
    }


# --------------------------------------------------------------------------------------------
# Transport helpers
# --------------------------------------------------------------------------------------------


@dataclass
class Http:
    status: int
    headers: dict
    body: str

    def json(self):
        return json.loads(self.body)


class Client:
    def __init__(self, base_url: str, user: str, password: str):
        self.base_url = base_url.rstrip("/")
        self.user = user
        self.password = password

    def basic(self) -> str:
        return "Basic " + base64.b64encode(f"{self.user}:{self.password}".encode()).decode()

    def request(self, method: str, path: str, *, auth: str | None = "basic", body=None,
                headers: dict | None = None, jar: http.cookiejar.CookieJar | None = None) -> Http:
        url = self.base_url + path
        data = None
        hdrs = {"Accept": "application/json"}
        if body is not None:
            data = json.dumps(body).encode()
            hdrs["Content-Type"] = "application/json"
        if auth == "basic":
            hdrs["Authorization"] = self.basic()
        elif auth:
            hdrs["Authorization"] = auth
        hdrs.update(headers or {})
        req = urllib.request.Request(url, data=data, headers=hdrs, method=method)
        handlers = [urllib.request.HTTPCookieProcessor(jar)] if jar is not None else []
        opener = urllib.request.build_opener(*handlers)
        try:
            with opener.open(req, timeout=HTTP_TIMEOUT) as resp:
                return Http(resp.status, dict(resp.headers), resp.read().decode("utf-8", "replace"))
        except urllib.error.HTTPError as err:
            return Http(err.code, dict(err.headers or {}), err.read().decode("utf-8", "replace"))


class Container:
    def __init__(self, name: str):
        self.name = name

    def session(self, namespace: str, script: str) -> str:
        """Run ObjectScript lines through `iris session` and return stdout+stderr."""
        proc = subprocess.run(
            ["docker", "exec", "-i", self.name, "iris", "session", "IRIS", "-U", namespace],
            input=script + "\nhalt\n", capture_output=True, text=True, timeout=EXEC_TIMEOUT,
        )
        return proc.stdout + proc.stderr

    def copy_in(self, local: Path, remote: str) -> None:
        subprocess.run(["docker", "cp", str(local), f"{self.name}:{remote}"], check=True,
                       capture_output=True, timeout=EXEC_TIMEOUT)

    def sh(self, command: str) -> str:
        proc = subprocess.run(["docker", "exec", self.name, "sh", "-c", command],
                              capture_output=True, text=True, timeout=EXEC_TIMEOUT)
        return proc.stdout + proc.stderr

    def load_class(self, filename: str, namespace: str = "USER") -> str:
        self.copy_in(PROBE_DIR / filename, f"/tmp/{filename}")
        out = self.session(namespace, f'do $system.OBJ.Load("/tmp/{filename}","ck-d") write "LOADED",!')
        if "ERROR" in out or "LOADED" not in out:
            raise ProbeOutcome(INCONCLUSIVE, f"Loading {filename} failed:\n{out}")
        return out

    def delete_class(self, classname: str, namespace: str = "USER") -> None:
        self.session(namespace, f'do $system.OBJ.Delete("{classname}","-d")')

    def create_web_app(self, name: str, dispatch: str, namespace: str = "USER") -> None:
        script = (
            f'kill p set p("NameSpace")="{namespace}",p("DispatchClass")="{dispatch}",'
            'p("AutheEnabled")=32,p("Enabled")=1,p("UseCookies")=2 '
            f'if ##class(Security.Applications).Exists("{name}") {{ do ##class(Security.Applications).Delete("{name}") }} '
            f'set sc=##class(Security.Applications).Create("{name}",.p) write "APPSC=",sc,!'
        )
        out = self.session("%SYS", script)
        if "APPSC=1" not in out:
            raise ProbeOutcome(INCONCLUSIVE, f"Creating web app {name} failed:\n{out}")

    def delete_web_app(self, name: str) -> None:
        self.session("%SYS", f'if ##class(Security.Applications).Exists("{name}") {{ do ##class(Security.Applications).Delete("{name}") }}')


# --------------------------------------------------------------------------------------------
# Probes
# --------------------------------------------------------------------------------------------


class Probes:
    def __init__(self, client: Client, container: Container):
        self.c = client
        self.k = container
        self.info: dict | None = None

    # 1 --------------------------------------------------------------------------------------
    def admin_api(self) -> dict:
        r = self.c.request("GET", "/api/admin/info")
        if r.status == 404:
            raise ProbeOutcome(ABSENT, f"HTTP 404 on /api/admin/info\n{r.body}")
        if r.status != 200:
            raise ProbeOutcome(INCONCLUSIVE, f"HTTP {r.status} on /api/admin/info\n{r.body}")
        result = r.json().get("result", {})
        self.info = result
        finding = {k: result.get(k) for k in ("apiVersion", "serverVersion", "product")}
        if (result.get("apiVersion") or 0) < 2:
            raise ProbeOutcome(ABSENT, f"SysAdmin API v2 not exposed (apiVersion={result.get('apiVersion')})\n{r.body}", finding)
        v2 = self.c.request("GET", "/api/admin/v2/web-apps?maxRows=1")
        if v2.status != 200:
            raise ProbeOutcome(INCONCLUSIVE, f"/info reports apiVersion 2 but /v2/web-apps returned HTTP {v2.status}\n{v2.body}", finding)
        return {"classification": PRESENT, "finding": finding}

    # 2 --------------------------------------------------------------------------------------
    def auth_path(self) -> dict:
        candidates = [
            self._candidate("in_process", self._in_process),
            self._candidate("jwt", self._jwt),
            self._candidate("loopback_proxy", self._loopback),
        ]
        classification, selected = aggregate_candidates(candidates)
        raw = None
        if classification != PRESENT:
            raw = "\n---\n".join(f"{c['key']}: {c['classification']}: {c['raw']}" for c in candidates)
        return {"classification": classification, "finding": {"selected": selected}, "raw": raw, "candidates": candidates}

    def _candidate(self, key: str, fn: Callable[[], tuple[str, str | None, str]]) -> dict:
        try:
            classification, raw, notes = fn()
        except ProbeOutcome as outcome:
            classification, raw, notes = outcome.classification, outcome.raw, "Probe setup or call failed"
        except Exception as exc:  # noqa: BLE001
            classification, raw, notes = INCONCLUSIVE, f"{type(exc).__name__}: {exc}", "Unexpected error"
        if classification != PRESENT and not raw:
            raw = "No raw response captured"
        return {"key": key, "classification": classification, "raw": raw, "notes": notes}

    def _cookie_candidate(self, cls_file: str, cls_name: str, app: str, whoami: bool) -> tuple[str, str | None, str]:
        try:
            self.k.load_class(cls_file)
            self.k.create_web_app(app, cls_name)
            jar = http.cookiejar.CookieJar()
            first_path = f"{app}/whoami" if whoami else f"{app}/admin/info"
            first = self.c.request("GET", first_path, jar=jar)
            if first.status != 200:
                return INCONCLUSIVE, f"Basic sign-in to {first_path}: HTTP {first.status}\n{first.body}", "Could not establish the IRIS session"
            if not any("CSPSESSIONID" in ck.name for ck in jar):
                return INCONCLUSIVE, f"No IRIS session cookie issued. Headers: {first.headers}", "Session not established"
            if whoami:
                me = self.c.request("GET", f"{app}/whoami", auth=None, jar=jar)
                if me.status != 200 or me.json().get("user") != self.c.user:
                    return INCONCLUSIVE, f"Cookie-only whoami: HTTP {me.status}\n{me.body}", "Session did not carry the identity"
            call = self.c.request("GET", f"{app}/admin/v2/security/roles?maxRows=1", auth=None, jar=jar)
            if call.status == 200 and '"result"' in call.body:
                return PRESENT, None, "Cookie-only request reached the official API under the signed-in user; no credential kept"
            if call.status in (401, 403, 404):
                return ABSENT, f"Cookie-only official call: HTTP {call.status}\n{call.body}", "Official API did not accept the forwarded session"
            return INCONCLUSIVE, f"Cookie-only official call: HTTP {call.status}\n{call.body}", "Unexpected response"
        finally:
            self.k.delete_web_app(app)
            self.k.delete_class(cls_name)

    def _in_process(self):
        return self._cookie_candidate("FDVerify.InProcess.cls", "FDVerify.InProcess", "/fdverify-inproc", whoami=True)

    def _loopback(self):
        return self._cookie_candidate("FDVerify.Loopback.cls", "FDVerify.Loopback", "/fdverify-loopback", whoami=True)

    def _jwt(self):
        login = self.c.request("POST", "/api/admin/login", auth=None, body={"user": self.c.user, "password": self.c.password})
        if login.status == 404:
            return ABSENT, f"HTTP 404 on /api/admin/login\n{login.body}", "JWT endpoints not present"
        if login.status != 200:
            return INCONCLUSIVE, f"HTTP {login.status} on /api/admin/login\n{login.body}", "Login did not succeed"
        token = login.json().get("access_token")
        if not token:
            return INCONCLUSIVE, "Login 200 without access_token", "Unexpected login shape"
        info = self.c.request("GET", "/api/admin/info", auth=f"Bearer {token}")
        if info.status == 200:
            return PRESENT, None, "Present, but refresh requires holding a refresh token (a credential); not selected by design"
        return INCONCLUSIVE, f"Bearer /info: HTTP {info.status}\n{info.body}", "Token not accepted"

    # 3 --------------------------------------------------------------------------------------
    def resource_shapes(self) -> dict:
        finding, raws, ok = {}, [], True
        for key, path in (("systemResources", "/api/admin/v2/monitor/dashboard/system-resources"),
                          ("sharedMemory", "/api/admin/v2/monitor/system-usage/shared-memory")):
            r = self.c.request("GET", path)
            if r.status == 404:
                raise ProbeOutcome(ABSENT, f"HTTP 404 on {path}\n{r.body}")
            if r.status != 200:
                raise ProbeOutcome(INCONCLUSIVE, f"HTTP {r.status} on {path}\n{r.body}")
            result = r.json().get("result")
            rows = result if isinstance(result, list) else []
            keys = sorted(rows[0].keys()) if rows and isinstance(rows[0], dict) else []
            matches = bool(keys) and SPEC_SHAPES[key].issubset(keys)
            finding[key] = {"sampleKeys": keys, "rows": len(rows), "matchesSpec": matches}
            if not matches:
                ok = False
                raws.append(f"{path} sample: {json.dumps(rows[:1])}")
        if not ok:
            raise ProbeOutcome(INCONCLUSIVE, "\n".join(raws), finding)
        return {"classification": PRESENT, "finding": finding}

    # 4 --------------------------------------------------------------------------------------
    def async_db_metrics(self) -> dict:
        dirs = self.c.request("GET", "/api/admin/v2/database-dirs?maxRows=50")
        if dirs.status == 404:
            raise ProbeOutcome(ABSENT, f"HTTP 404 on /v2/database-dirs\n{dirs.body}")
        if dirs.status != 200:
            raise ProbeOutcome(INCONCLUSIVE, f"HTTP {dirs.status} on /v2/database-dirs\n{dirs.body}")
        rows = dirs.json().get("result") or []
        directory = next((d.get("Directory") for d in rows if str(d.get("Directory", "")).rstrip("/").endswith("user")), None) \
            or (rows[0].get("Directory") if rows else None)
        if not directory:
            raise ProbeOutcome(INCONCLUSIVE, f"No database directory listed\n{dirs.body}")
        started = time.monotonic()
        start = self.c.request("POST", "/api/admin/v2/database-dir/info?dir=" + urllib.request.quote(directory, safe=""))
        finding = {"directory": directory, "taskStarted": start.status == 202, "startStatus": start.status}
        if start.status != 202:
            raise ProbeOutcome(INCONCLUSIVE, f"POST database-dir/info: HTTP {start.status}\n{start.body}", finding)
        location = next((v for k, v in start.headers.items() if k.lower() == "location"), "")
        match = re.search(r"id=([^&]+)", location) or re.search(r'"id"\s*:\s*"?([^",}]+)', start.body)
        if not match:
            raise ProbeOutcome(INCONCLUSIVE, f"No task id. Headers: {start.headers}\n{start.body}", finding)
        task_id = match.group(1)
        polls, last = 0, None
        while time.monotonic() - started < 60:
            polls += 1
            last = self.c.request("GET", f"/api/admin/v2/async-result?id={task_id}")
            body = last.json() if last.status == 200 else {}
            result = body.get("result") or {}
            status = str(result.get("Status", result.get("status", ""))).lower()
            inner = result.get("Result") or {}
            if isinstance(inner, dict) and ({"DiskFree", "AvailableSpace", "Full"} & set(inner)):
                finding.update({"pollCount": polls, "latencyMs": int((time.monotonic() - started) * 1000),
                                "resultKeys": sorted(inner.keys()), "status": status, "sample": inner})
                return {"classification": PRESENT, "finding": finding}
            if status in ("error", "failed", "cancelled", "canceled"):
                raise ProbeOutcome(INCONCLUSIVE, f"Async task ended with {status}\n{last.body}", finding)
            time.sleep(0.5)
        finding["pollCount"] = polls
        raise ProbeOutcome(INCONCLUSIVE, f"No completed metrics within 60 s. Last: HTTP {last.status if last else '-'}\n{last.body if last else ''}", finding)

    # 5 --------------------------------------------------------------------------------------
    def wallet(self) -> dict:
        r = self.c.request("GET", "/api/admin/v2/wallet/collections")
        finding = {"collectionsStatus": r.status}
        if r.status == 200:
            return {"classification": PRESENT, "finding": finding}
        if r.status == 404:
            raise ProbeOutcome(ABSENT, f"HTTP 404\n{r.body}", finding)
        raise ProbeOutcome(INCONCLUSIVE, f"HTTP {r.status}\n{r.body}", finding)

    # 6 --------------------------------------------------------------------------------------
    def mgmnt_api(self) -> dict:
        r = self.c.request("GET", "/api/mgmnt/")
        if r.status == 404:
            raise ProbeOutcome(ABSENT, f"HTTP 404\n{r.body}")
        if r.status != 200:
            raise ProbeOutcome(INCONCLUSIVE, f"HTTP {r.status}\n{r.body}")
        data = r.json()
        if not isinstance(data, list):
            raise ProbeOutcome(INCONCLUSIVE, f"Expected a JSON array\n{r.body}")
        return {"classification": PRESENT, "finding": {"serviceCount": len(data)}}

    # 7 --------------------------------------------------------------------------------------
    def log_sources(self) -> dict:
        try:
            self.k.load_class("FDVerify.Files.cls", "%SYS")
            out = self.k.session("%SYS", 'do ##class(FDVerify.Files).Report()')
        finally:
            self.k.delete_class("FDVerify.Files", "%SYS")
        match = re.search(r"FDVERIFY-JSON:(\{.*\})", out)
        if not match:
            raise ProbeOutcome(INCONCLUSIVE, f"No report from FDVerify.Files\n{out}")
        report = json.loads(match.group(1))
        tail = self.k.sh(f"tail -n 1 '{report['messagesLog']['path']}'") if report["messagesLog"]["exists"] else ""
        finding = {
            "messagesLog": {"path": report["messagesLog"]["path"], "exists": report["messagesLog"]["exists"],
                            "sampleLine": (report["messagesLog"]["lastLine"] or tail.strip())[:300]},
            "alerts": report["alerts"],
            "interop": {"queryAvailable": report["interop"]["queryClassExists"],
                        "namespacesWithProductions": report["interop"]["namespacesWithInterop"]},
        }
        if not report["messagesLog"]["exists"]:
            raise ProbeOutcome(INCONCLUSIVE, f"messages.log not found\n{out}", finding)
        if not report["interop"]["namespacesWithInterop"]:
            raise ProbeOutcome(ABSENT, "No namespace has interoperability enabled, so there is no event log to query", finding)
        if not report["interop"]["queryClassExists"]:
            raise ProbeOutcome(INCONCLUSIVE, f"Interop namespaces exist but Ens.Util.Log is not visible in them\n{out}", finding)
        return {"classification": PRESENT, "finding": finding}

    # 8 --------------------------------------------------------------------------------------
    def audit_enabled(self) -> dict:
        r = self.c.request("GET", "/api/admin/v2/security/audit/enabled")
        if r.status == 404:
            raise ProbeOutcome(ABSENT, f"HTTP 404\n{r.body}")
        if r.status != 200:
            raise ProbeOutcome(INCONCLUSIVE, f"HTTP {r.status}\n{r.body}")
        result = r.json().get("result")
        enabled = result.get("Enabled", result.get("enabled")) if isinstance(result, dict) else result
        return {"classification": PRESENT, "finding": {"enabled": bool(enabled), "result": result}}

    def ordered(self):
        fns = [self.admin_api, self.auth_path, self.resource_shapes, self.async_db_metrics,
               self.wallet, self.mgmnt_api, self.log_sources, self.audit_enabled]
        return [(pid, key, title, fn) for (pid, key, title), fn in zip(PROBE_KEYS, fns)]


# --------------------------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------------------------


def print_table(report: dict) -> None:
    print(f"\nFlightDeck platform verification — {report['target']['label']}")
    print(f"  {report['target'].get('serverVersion') or 'version unknown'}\n")
    print(f"  {'#':<2} {'probe':<18} {'classification':<18} ms")
    for p in report["probes"]:
        print(f"  {p['id']:<2} {p['key']:<18} {p['classification']:<18} {p['durationMs']}")
        for c in p.get("candidates") or []:
            print(f"       - {c['key']:<15} {c['classification']}")
        if p["classification"] == INCONCLUSIVE:
            first = (p["raw"] or "").splitlines()[0] if p["raw"] else ""
            print(f"       raw: {first[:120]}")
    counts = report["summary"]["counts"]
    print(f"\n  present {counts[PRESENT]} · absent {counts[ABSENT]} · inconclusive {counts[INCONCLUSIVE]}"
          f" → exit {report['summary']['exitCode']}")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--container", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--out")
    try:
        args = parser.parse_args(argv)
    except SystemExit:
        return 2
    fault_env = os.environ.get("FD_VERIFY_FAULT")
    fault = int(fault_env) if fault_env and fault_env.isdigit() else None
    client = Client(args.base_url, os.environ.get("FD_VERIFY_USER", "_SYSTEM"), os.environ.get("FD_VERIFY_PASSWORD", "SYS"))
    probes = Probes(client, Container(args.container))
    results = run_probes(probes.ordered(), fault)
    info = probes.info or {}
    target = {
        "baseUrl": args.base_url,
        "label": args.label,
        "product": info.get("product") or "unknown",
        "serverVersion": info.get("serverVersion"),
        "apiVersion": info.get("apiVersion"),
    }
    report = build_report(results, target)
    if args.out:
        out = Path(args.out)
    else:
        version = re.search(r"\b(\d{4}\.\d+)\b", target["serverVersion"] or "")
        out = ROOT / "verification" / f"{target['product']}-{version.group(1) if version else 'unknown'}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print_table(report)
    print(f"  report: {out}")
    return report["summary"]["exitCode"]


if __name__ == "__main__":
    sys.exit(main())
