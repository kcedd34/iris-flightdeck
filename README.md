# FlightDeck for InterSystems IRIS

A keyboard-first, safe-by-default management portal for InterSystems IRIS, built entirely on the
official **SysAdmin API** (`/api/admin/v2`).

![FlightDeck shell: glareshield, rail, section tabs and inspector](docs/img/shell.png)

- **Command palette.** Press <kbd>Ctrl</kbd>+<kbd>K</kbd> (<kbd>Cmd</kbd>+<kbd>K</kbd> on macOS) and
  type the name of any user, role, web application, task or action.
- **Safe mode by default.** Every browser tab starts read-only. Changes need an explicit
  "Turn off safe mode", scoped to that tab only, and the server enforces it too.
- **Your IRIS identity, nothing stored.** You sign in with your IRIS account. FlightDeck keeps no
  password or token anywhere. What you can do comes from the privileges the SysAdmin API declares
  for each operation.
- **Permissions you can follow.** Users, roles, resources, services and privileged routines, with the
  chain that grants each privilege: which role, through which inherited roles, granting which
  resource. Before a removal, FlightDeck says who loses access and what becomes unreachable.
- **Security and secrets.** TLS, X.509, OAuth 2.0 in its three roles, wallet, LDAP, MFT, auditing,
  web authentication and superservers. Secrets are set or replaced, never shown.
- **Web applications and REST APIs.** Web applications are listed with graded exposure markers,
  edited through a field-by-field dry run, and linked to the roles and REST services behind them.
  Every REST service the instance serves is discovered, with its OpenAPI specification when it has
  one (FlightDeck's own API included), and can be tried from the browser.
- **Real host telemetry.** CPU and memory come from the host; IRIS shared memory and database usage
  come from the SysAdmin API.
- **One log stream from five sources.** The messages log, alerts, the interoperability event log, the
  audit trail and the journal, normalised into one line — timestamp, source, severity, namespace,
  process, user, message — with every event's original record one click away, live follow, and a jump
  from an event to the process, namespace or user it names.

> This release completes the six domains: the foundation, web applications and the REST explorer,
> permissions and security, tasks and the operating system, and the **unified log stream** — the one
> axis of the brief the official API does not cover, where five sources are normalised into one line
> that keeps every original record.

Related idea on the InterSystems Ideas Portal: _link pending publication by the author_

---

## Requirements

- **Docker Engine 24+ with Docker Compose v2.** Works on Linux, macOS and Windows (including WSL2).
- **About 3 GB of free disk space** for the IRIS Community image (5 GB for IRIS for Health).
- **Free port 52780**, or pick another one (see [Port already in use](#port-already-in-use)).
- **IRIS 2026.2 or later for the full portal.** FlightDeck uses SysAdmin API **v2**, which first
  ships in IRIS 2026.2, so the install pins the `2026.2` images for you.
- **IRIS 2026.1 runs in limited mode.** That release (still the `latest` tag of the Community
  images) only has API v1. FlightDeck translates what v1 offers, shows a **Limited**
  indicator at the top, and disables the 64 operations it cannot offer (databases, ECP, namespace
  changes, the journal and a few more), each with its reason. Namespaces can still be browsed.

## Quick start

```bash
git clone <repository-url> iris-flightdeck
cd iris-flightdeck
docker compose up -d
docker compose logs -f iris
```

Wait for this line (about 15 seconds after the image is downloaded):

```text
FlightDeck is ready at http://localhost:52780/flightdeck/ — sign in with the default account documented in the README (local evaluation only).
```

Open **http://localhost:52780/flightdeck/** and sign in:

| Username | Password |
|---|---|
| `_SYSTEM` | `SYS` |

This is the default account of the InterSystems Community image. FlightDeck does not create or
change any credential. **Use it for local evaluation only.**

Then try:

1. Press <kbd>Ctrl</kbd>+<kbd>K</kbd> and type `FD_Demo`. The demonstration roles, resources, web
   application, tasks and wallet collection appear, grouped by domain.
2. Type `delete a role` and press <kbd>Enter</kbd>. FlightDeck offers to turn off safe mode first,
   because this tab is read-only.
3. Open a second tab. It starts in safe mode again: safe mode is per tab and never remembered.

To stop: `docker compose down`. To remove everything, including IRIS data: `docker compose down -v`.

### IRIS for Health

Same procedure, one variable:

```bash
docker compose down -v
IRIS_IMAGE=intersystemsdc/irishealth-community:2026.2-zpm docker compose up -d --build
```

### Port already in use

If port 52780 is taken, `docker compose up -d` stops with:

```text
Error response from daemon: failed to set up container networking: … Bind for 0.0.0.0:52780 failed: port is already allocated
```

Pick another port:

```bash
FLIGHTDECK_PORT=52790 docker compose up -d
```

The ready line in the log shows the new URL.

## Install with IPM on an existing instance

On IRIS 2026.2 or later (2026.1 installs in limited mode), in the namespace where you want FlightDeck, from a clone of this
repository:

```objectscript
zpm "load /path/to/iris-flightdeck"
```

This installs:
- two web applications, `/flightdeck` (the interface) and `/api/flightdeck` (the API, Password
  authentication);
- a role `FlightDeck_Runtime`, which grants read access to FlightDeck's code database only, inside
  those two web applications;
- a small capture routine, also installed in `%SYS`.

Nothing else is created or changed. **Demonstration objects are off by default.** To add them:

```objectscript
zpm "load /path/to/iris-flightdeck -DDemo=1"
```

The installer creates the role and every demonstration object through the SysAdmin API. The
installing user needs `%All` (or equivalent) for the web applications and the `%SYS` routine.

## Demonstration objects

Created on the Docker install, and with `-DDemo=1` on IPM. Every object is created through the
SysAdmin API, and re-running creates no duplicates.

| Kind | Name |
|---|---|
| Resources | `FD_Demo_Reports`, `FD_Demo_Billing` |
| Roles | `FD_Demo_Operator`, `FD_Demo_Auditor` |
| Web application | `/csp/fd-demo`, intentionally unauthenticated so the exposure warning has something to show |
| Tasks | `FD Demo daily no-op`, `FD Demo nightly no-op`, `FD Demo failing task` (fails on purpose) |
| Wallet collection | `FD_Demo_Vault` (no secrets) |

## How sign-in and safe mode work

- **Credentials.** The sign-in form sends your username and password to IRIS once, in an HTTP
  Basic header. IRIS authenticates you and keeps its own session cookie. FlightDeck never stores,
  caches or logs the password, and uses no JWT or refresh token. Invalid credentials always produce
  the same message, whether or not the user exists.
- **What you can do.** Every SysAdmin API operation declares the privilege it needs (for example
  `%Admin_Secure:U`). FlightDeck crosses those declarations with the privileges IRIS reports for
  you. Actions you cannot perform stay visible, disabled, with the privilege to ask for.
- **Safe mode.** Safe mode lives in the tab's memory only. It is not in cookies, storage or the URL,
  so reloads, new tabs and duplicated tabs always start in safe mode. Every request carries the
  tab's state, and the FlightDeck API rejects any change request from a tab in safe mode before it
  reaches IRIS.
- **Changes.** Every change opens the same confirmation view: current and commanded values side by
  side, graded confirmation (deleting or disabling asks you to type the name), and the effect on
  users when it can be determined. The server recomputes the preview and refuses the change if the
  object changed in the meantime. FlightDeck refuses changes that would disable its own
  applications.
- **Session trail.** Applied, failed and blocked changes are recorded in a trail you can open from
  the confirmation view or the palette and export as JSON. The trail is local to the browser tab
  (session storage, cleared at sign-out and when the session expires), holds no secret values, and
  does **not** replace IRIS auditing.
- **Users without administrative privileges** cannot open a session. FlightDeck lists the
  privileges they would need.

## What the permissions screens claim, and what they do not

- **Every privilege comes with its origin.** A privilege is never shown without the chain of roles
  that grants it, and a chain FlightDeck could not expand is reported as not expanded, not omitted.
- **Delegated access and LDAP are not enumerated.** The official API does not report which roles an
  account receives from them, so FlightDeck marks the account and says it does not manage them there.
- **SQL privileges are read as the platform reports them.** The official listing already resolves
  provenance through roles (`Role:<name>`, `Owner Privilege`), so FlightDeck renders that and does
  not compute a second answer.
- **Before a change that could remove administrative access**, FlightDeck checks whether any enabled,
  unexpired account would still hold `%Admin_Secure:USE` or the `%All` role. If it can read what it
  needs and the answer is none, the change is refused, and the reason says what was counted. If it
  cannot read what it needs, it does not refuse and does not pretend: it says the check was
  incomplete, names what it could not read, and asks for the reinforced confirmation. The session
  trail records which of the two happened.

## Secrets, and what FlightDeck declines to do

- **Secret material is write-only** everywhere: wallet secrets, private keys, client secrets,
  passwords and tokens are set, replaced or deleted. No screen, API answer, session trail or log of
  FlightDeck carries a value, and the wallet has no operation that reads one back.
- **Encryption is read-only in FlightDeck.** Creating an encryption key file, administering one,
  activating or deactivating a key and changing the encryption settings can make an instance's data
  permanently unreadable, with no recovery through the portal. Those eight operations appear in the
  interface as disabled controls, each stating that reason and pointing at
  "System Administration > Encryption" in the platform's own management portal. They are listed in
  `docs/api-coverage.md` as declined, not missing.
- **Auditing**: FlightDeck changes the setting and performs the two writes that touch the audit trail
  — copying records to another namespace, and purging them. A purge asks for the maximum
  confirmation and states that it erases the instance's own audit trail. Reading audit records
  belongs to the logs screens.

## What the log stream reads, and what it does not

- **Five sources, one schema.** Two come from the official API (the audit trail and the journal, both
  read asynchronously); three have no API and are read natively, which is the exception the project's
  constitution names: the instance's messages log, its alerts log, and the interoperability event log.
- **The original record is always kept.** Normalisation never discards anything: every event carries
  the record it came from. Where the original can no longer be recovered — a purged journal file, a
  rotated log — the event says so where the record would be and keeps the fields FlightDeck read
  before it went. There is no third case, and nothing is invented to fill the gap.
- **Severity is mapped, never guessed.** Each source states its own level and FlightDeck maps it. A
  source that states no level gets `unknown`, a fifth value outside the ordering — not `info`, and
  never a guess from the words in the message. The minimum-severity filter says how it treats it.
- **Big files are read backwards, in pages.** A log is never read whole, at any size: each page seeks
  to an offset near the end and reads one bounded window. A 100 MB file pages at the same cost as a
  small one, wherever in it you are.
- **A source that cannot be read says why, and the others keep streaming.** A stock instance writes no
  alerts log, so that source is normally absent and explains what an alerts log is and where it comes
  from. On IRIS 2026.1 the journal operations are withheld and the journal source says so. Neither
  takes the stream with it.
- **What it is not.** FlightDeck does not store, index or forward any event: nothing is persisted,
  and the live window lives in the browser. It is a reader, not a log platform.

## REST API explorer: what a test request can and cannot do

- **Confined to this instance.** A test request names only a method, a path, query parameters,
  headers and a body. Scheme, host and port always come from the instance serving FlightDeck. Paths
  with a scheme, a host, `..` segments (plain or percent-encoded) or backslashes are refused, and so
  are `Authorization`, `Cookie`, `Proxy-Authorization` and `Host` headers. **The executor is not an
  outbound proxy**: it opens no network connection at all. The request is dispatched in-process to
  the REST application that serves the path.
- **Runs as you.** The request runs with your IRIS identity, in the application's namespace, and
  only if the application is enabled and you hold its resource. Your roles are kept or reduced,
  never raised: when an application grants extra roles to real callers (its role mapping), a test
  request does not receive them, and the result can differ from a real call. The explorer says so
  before and after running.
- **Safe mode applies.** `GET`, `HEAD` and `OPTIONS` run directly. `POST`, `PUT`, `PATCH` and
  `DELETE` are refused by the server while the tab is in safe mode; otherwise they open the shared
  confirmation view showing exactly what will be sent (a `DELETE` asks you to type the path), and
  are recorded in the session trail.
- **Copy as curl.** The copied command targets this instance and carries the literal placeholder
  `-u '<user>:<password>'`, never your credentials.
- FlightDeck's own API requires the `X-FlightDeck-Tab` header on every call, and
  `X-FlightDeck-Safe-Mode: disarmed` on changes. Its specification declares both; the explorer adds
  nothing on your behalf, so a request without them returns the API's own 400 or 403.

## Day-1 platform verification

`scripts/verify/verify_platform.py` checks, in order, the eight platform facts FlightDeck depends
on:
1. SysAdmin API v2;
2. which sign-in path works without storing credentials;
3. monitor data shapes;
4. asynchronous database metrics;
5. wallet;
6. the REST management API;
7. log file locations and the interoperability log;
8. auditing.

Each fact is classified `confirmed_present`, `confirmed_absent` or `inconclusive`, with the raw
response recorded. To run it against fresh IRIS Community and IRIS for Health containers:

```bash
scripts/verify/run-both-images.sh
```

Reports are written to `verification/<product>-<version>.json`. Exit code: `0` when nothing is
inconclusive, `1` otherwise, `2` for a usage error. The committed reports and findings are in
[`verification/`](verification/).

## Troubleshooting

- **The ready line never appears.** Look for a line starting with `FLIGHTDECK INSTALL FAILED:` in
  `docker compose logs iris`. It names the step and the IRIS error. IRIS stays running so you can
  inspect it.
- **Sign-in says "Not available on this IRIS version or edition. Requires IRIS 2026.1."** The
  instance has no SysAdmin API. Use the pinned images or upgrade.
- **The top bar shows "Limited".** The instance is IRIS 2026.1 (for example a `latest`
  Community image). Disabled actions say "Requires IRIS 2026.2"; use the pinned images for the
  full portal.
- **Sign-in says "Invalid credentials".** The default account is `_SYSTEM` / `SYS` on the Docker
  install. On an existing instance, use your own IRIS account.
- **Sign-in says "Requires Use on …".** The account has no administrative privilege. Grant one of
  the listed `%Admin_*` resources, for example through the `%Operator` or `%Manager` role.

## Development

| Area | Command |
|---|---|
| Frontend dev server (proxies the API to the Docker install) | `cd frontend && npm ci && npm run dev`, then open http://localhost:5173/flightdeck/ |
| Frontend checks | `npm run lint && npm run check:tokens && npm run check:dialect && npm run contrast && npm run test` |
| End-to-end tests (Docker install running) | `npx playwright install chromium && npm run e2e` |
| Backend unit tests (inside the container) | `zpm "iris-flightdeck test"` |
| Rebuild the committed frontend bundle | `cd frontend && npm run build` (verify with `scripts/build/check-dist.sh`) |
| Regenerate the capability map from the official spec | `python3 scripts/build/gen-capability-spec.py` (verify with `scripts/build/check-generated.sh`) |

Specifications, plan and research live in [`specs/001-foundation-shell/`](specs/001-foundation-shell/).
The project constitution is in [`.specify/memory/constitution.md`](.specify/memory/constitution.md).

## License

MIT. See [LICENSE](LICENSE).
