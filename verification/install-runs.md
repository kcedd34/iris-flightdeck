# Install runs (T073, T074), 2026-09-17

Host: WSL2, Docker Engine 29.5.2, 4 CPUs, 12 GB RAM. The base images were already pulled, so the
timings below exclude the one-time image download (about 2.7 GB for IRIS Community, 4.7 GB for
IRIS for Health). The README states the download size.

## One-command install (T073, SC-005, SC-010)

| Run | Command | Ready line after `up` | Demo objects | Palette search `FD_Demo` |
|---|---|---|---|---|
| IRIS Community 2026.2 | `docker compose down -v && docker compose up -d --build` | 12 s | 9 created (2 resources, 2 roles, 1 web app, 3 tasks, 1 wallet collection) | 9 results: Web application 1, Resource 2, Role 2, Wallet collection 1, Task 3 |
| IRIS for Health Community 2026.2 | `IRIS_IMAGE=intersystemsdc/irishealth-community:2026.2-zpm docker compose up -d --build` | 12 s | same 9 created | 9 results |

Both runs:
- **Sign-in**: `_SYSTEM`/`SYS` → `GET /api/flightdeck/v1/session` 200, `capabilitySummary` 273/273,
  `edition: "Community"`. Product `iris` on CE and `irisforhealth` on IRIS for Health.
- **Vitals** agree with `top`/`free` in the container. IRIS for Health: Memory 18.4 % vs 18.7 %
  from `free`; CPU 3.5 % while idle.
- **SPA**: deep link `/flightdeck/security/tls` returns 200 (index fallback), hashed assets 200,
  container `healthy`.
- **Restart**: `docker compose restart iris` prints `FlightDeck already installed.` and the ready
  line; nothing is reinstalled.

**R4 open item (a), IRIS for Health 2026.2.** `fd_e2e_operator` (`%Operator`) gets 200 with 58/273;
`fd_e2e_none` gets 403 `NO_ADMIN_PRIVILEGE`. This is the same behavior as IRIS Community.

## Failure paths (T074)

**(a) Port 52780 already in use.** A second stack on the same port prints:

```text
Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint fdportcheck-iris-1 (…): Bind for 0.0.0.0:52780 failed: port is already allocated
```

`FLIGHTDECK_PORT=52790 docker compose up -d` then works, and the ready line reports port 52790.

**(b) Compile error.** A copy of the repository with a missing parenthesis in
`FlightDeck.API.Vitals` produces, in `docker compose logs iris`:

```text
ERROR: FlightDeck.API.Vitals.cls(Get+2) #1010: Missing right parenthesis : '…' : Offset:111 [Get+1^FlightDeck.API.Vitals.1]
FLIGHTDECK INSTALL FAILED: compile/install: ERROR: FlightDeck.API.Vitals.cls(Get+2) #1010: Missing right parenthesis …
IRIS keeps running so you can inspect it: docker compose logs iris
```

The container stays up, so no restart loop.

**(c) IPM on an existing instance without demo** (clean `intersystemsdc/iris-community:2026.2-zpm`,
`zpm "load /tmp/fd"`):
- `FlightDeck: install complete (demo=0)`;
- `GET /v2/security/role?name=FD_Demo_Operator`, `/v2/web-app?name=/csp/fd-demo` and
  `/v2/wallet/collection?name=FD_Demo_Vault` all return 404;
- `GET /v2/tasks?filter=FD Demo` returns 0 tasks;
- only `FlightDeck_Runtime` exists (200).

## Defects found and fixed during these runs

1. **The stock image entrypoint shuts IRIS down** (research R2). Fixed by the entrypoint override.
2. **Web apps created unauthenticated.** `PasswordAuthEnabled` in `module.xml` is ignored by IPM
   0.10. Fixed with `AutheEnabled`.
3. **A failed first start stopped IRIS and triggered a restart loop.** `first-start.sh` now always
   exits 0 after printing the failure line.
4. **`npm ci` timed out inside `docker build`.** The frontend is now prebuilt and committed
   (research R13).
5. **Official handler output leaked into HTTP responses** (`/v2/journal/files`). Capture now uses
   I/O redirection, with the capture routine deployed to `%SYS` (research R4).


---

# Feature 006: clean-environment verification for the submission, 2026-09-18

Run with **the README's own commands**, not with the scripts the repository uses internally — the
README is the artifact under test. Version and capability counts are read from the running portal,
never from the image tag: a tag is a claim about a version, the portal is the fact.

Host: WSL2, Docker Engine 29.5.2. The base images were already pulled and the layer cache was warm,
so the timings below exclude the first download and build, which the README says takes a few minutes.

## Run 1 — IRIS Community Edition 2026.2

| Field | Value |
|---|---|
| Commands | `docker compose down -v` then `docker compose up -d` (the README's one-command path, verbatim) |
| Image | `intersystemsdc/iris-community:2026.2-zpm`, pinned in `docker-compose.yml` |
| Reported by the portal | `product: iris`, `version: 2026.2`, `edition: Community`, `apiVersion: 2`, `dialect: v2`, `namespace: USER` |
| Ready line after `up` | 12 s (16 s including `down -v`) |
| Capability summary | `allowed 262, unavailable 0, declined 11, total 273` — matches the README's compatibility table |
| Content on first access | web applications 5, users 5, TLS configurations 1, tasks 5, processes 5, and the log stream 20 events across 5 available sources. **Last screen checked: the logs stream**, because it is the one that depends on five separate readers |
| Outcome | ok |

The full Playwright suite was then run against this install: **128 passed, 22 skipped**, two failures
that were not defects — one a test race fixed in this feature (`count()` called before the section
tabs had rendered), one an artifact collision caused by running a second Playwright job against the
same `test-results/` directory at the same time. Both re-run green in isolation.

## Run 2 — IRIS for Health Community Edition 2026.2

| Field | Value |
|---|---|
| Commands | `docker compose down -v` then `IRIS_IMAGE=intersystemsdc/irishealth-community:2026.2-zpm docker compose up -d --build` (the README's variant, verbatim) |
| Reported by the portal | `product: irisforhealth`, `version: 2026.2`, `edition: Community`, `apiVersion: 2`, `dialect: v2`, `namespace: USER` |
| Ready line after `up` | 18 s (21 s including `down -v`) |
| Capability summary | `allowed 262, unavailable 0, declined 11, total 273` — **identical to IRIS 2026.2**, which is what the README claims and what a reader would otherwise have to spend 5 GB to check |
| Content on first access | web applications 5, users 5, TLS configurations 2, tasks 5, processes 5, log stream 20 events across 5 available sources |
| Outcome | ok |

## Run 3 — the port-conflict path

The port was occupied with `python3 -m http.server 52780`, then the README's instructions were
followed verbatim.

- `docker compose up -d` failed, naming the port, as the README says it would.
- `FLIGHTDECK_PORT=52790 docker compose up -d` succeeded, ready after 5 s, and the ready line carried
  the new URL.
- **Defect found and fixed**: the README quoted an older Docker's wording (*"Bind for 0.0.0.0:52780
  failed: port is already allocated"*). Docker 29 says *"failed to bind host port 0.0.0.0:52780/tcp:
  address already in use"*. The README now quotes the current message and says the wording varies by
  Docker version but always names the port.

## Run 4 — the IPM path, on an instance that is not the container build

This is the path no gate covers, and the one a reader with their own instance uses. A stock
`intersystemsdc/iris-community:2026.2-zpm` container was started with **no FlightDeck in it**, the
repository was copied in, and the README's command was run as written:

```objectscript
zpm "load /opt/flightdeck"
```

The installer reported, in order: capture routine deployed to `%SYS`; SysAdmin API v2 present; role
`FlightDeck_Runtime` created (`%DB_USER:R`); web applications `/api/flightdeck` and `/flightdeck`
present; 2 web applications recorded for self-protection; **`install complete (demo=0)`**.

Verified afterwards against the instance's own security tables:

| Claim in the README | Result |
|---|---|
| Two web applications, and nothing else | `/api/flightdeck` and `/flightdeck` — exactly two |
| A role `FlightDeck_Runtime` | present |
| A capture routine in `%SYS` | reported by the installer |
| **Demonstration objects are off by default on this path** | 0 demo resources, and `/csp/fd-demo` **absent** |
| The portal serves | `GET /flightdeck/` → 200 |

Note for anyone reproducing this: the stock Community image's own entrypoint shuts IRIS down on
start (the same finding as feature 001 research R2), so the throwaway instance was started the way
this project's Dockerfile starts it, with `/tini -- /iris-main --check-caps false`.
