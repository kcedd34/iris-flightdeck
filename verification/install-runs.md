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
