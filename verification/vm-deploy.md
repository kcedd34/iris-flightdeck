# Deploying the public demo to a real server, 2026-09-18

The online demo at **http://109.123.244.170/**, on a dedicated disposable VM. Written so the worst
case is known rather than assumed.

Half the point of this exercise was validation: what behaves differently on a real server than on a
development localhost. It found **three product defects**, two of which had been shipping since the
features that introduced them, and one of which no test in this repository could have caught.

## The machine

| | |
|---|---|
| Host | Ubuntu 24.04.5 LTS, x86-64, 4 CPUs, 7.9 GB RAM, 145 GB disk |
| Public address | `109.123.244.170`, no domain, plain HTTP by decision (a self-signed certificate's browser warning costs more than it buys) |
| Purpose | Runs FlightDeck and nothing else. Disposable: if it is compromised, it is reinstalled |

## What the README required that it does not say

**Docker was absent.** The README lists "Docker Engine 24+ with Docker Compose v2" under
Requirements but gives no way to get it, and a clean Ubuntu has neither. Installing it from Docker's
own apt repository took **35 seconds** and five commands. Most projects assume this; on a bare VM it
is the first thing a reader hits. Landed: Docker 29.8.1, Compose v5.5.1.

**`git clone` failed**, and this one is temporary but real:

```
fatal: could not read Username for 'https://github.com': No such device or address
```

The repository is private. The README's first command cannot work for anyone without access, which
today is everyone. It resolves when the repository goes public; until then, the clone URL in the
README is a promise it cannot keep. For this deployment the working tree was transferred directly.

**Everything after that worked as written.** `docker compose up -d` to the portal answering 200:
**94 seconds**, including pulling the base image and building. No step diverged.

## The exposure window I opened, and closed

The README's compose publishes `0.0.0.0:52780`. On a laptop that is fine; on a public IP it put an
IRIS administration portal with the Community image's documented default credentials on the internet
for as long as the measurement ran. Confirmed afterwards from the listening sockets:

```
LISTEN 0 4096 0.0.0.0:52780  users:(("docker-proxy",...))
```

It was closed by taking that stack down and moving to `deploy/vm/docker-compose.yml`, which binds
`127.0.0.1:52780`. **This is not a README defect** — the README's install is for a local machine and
says so — but it is the thing to get right first when that same command runs somewhere reachable, and
it is why the demo compose is a separate file rather than an environment variable on the original.

## Exposure, as it stands

| Path | Answer from the internet |
|---|---|
| `/` | 302 to `/flightdeck/` |
| `/flightdeck/` | 200 |
| `/api/flightdeck/v1/session` | 401 (the portal's own API, authentication required) |
| `/csp/sys/UtilHome.csp`, `/csp/sys/` | 404 |
| `/api/admin/info`, `/api/admin/v2/security/users` | 404 |
| `/api/mgmnt/`, `/csp/user/`, `/isc/studio/`, `/api/atelier/` | 404 |
| `/csp/fd-demo/` | 404 |
| `109.123.244.170:52780` (IRIS directly) | no route at all |

nginx forwards two locations and returns 404 for everything else. 404 rather than 403 on purpose: a
refusal that distinguishes "exists but forbidden" from "not here" tells a stranger which paths are
worth attacking. The IRIS port is bound to loopback, so the proxy is the entire public surface.

## Accounts

| Account | What it is |
|---|---|
| `demo` | The published visitor account, holding `%All`. Printed on the sign-in form and in the README |
| `_SYSTEM` | The instance's own administrator. Strong password, generated on the VM, living only in `deploy/vm/.env` (mode 600, covered by `.gitignore`) |

Both passwords were generated **on the machine that uses them**, by `deploy/vm/bootstrap.sh`, so
neither was chosen elsewhere and carried over. Verified afterwards: `demo` signs in (200), and the
README's local-install credential `_SYSTEM`/`SYS` does **not** (401).

`%All` is deliberate. Permissions and security are what this portal is for — impact analysis, the
last-administrator predicate, the dry-run with provenance — and a reduced account would hide exactly
the part worth evaluating. Recovery replaces restriction; see below.

The unauthenticated `/csp/fd-demo` **is** created. It was removed at first and then restored: the
exposure marker is a real feature and with nothing unauthenticated on the instance it has nothing to
point at. What the marker reports is a fact about the instance's own web application list, not an
opening into it — the proxy answers 404 for `/csp/*` from outside regardless. Verified on the VM:

```
/csp/fd-demo          facts: {'unauthenticated': True, 'unauthenticatedOnly': True}
/csp/fd-demo-reports  facts: {'unauthenticated': False, ...}
```

## Recovery, which is what makes a full-privilege demo account safe

| Mechanism | Cadence | What it covers |
|---|---|---|
| `flightdeck-demo-watchdog.timer` | every 5 minutes | Authenticates `demo` against the portal's own API. A visitor who changes the demo password or disables the account leaves the portal intact and nobody able to enter; waiting an hour for that is the difference between an evaluator seeing the product and seeing a login form that refuses them. On failure it rebuilds immediately |
| `flightdeck-demo-reinstall.timer` | hourly | Destroys the instance and its volume and rebuilds from nothing. Covers dirty state that still permits sign-in |

**Both were run once, for real.** The hourly rebuild completes in **28 seconds**. The watchdog was
tested by disabling the `demo` account the way a visitor would: sign-in went to 401, the watchdog
noticed, rebuilt, and sign-in returned 200 with the demonstration objects present.

The rebuild order is the part that matters and is explicit in `reinstall.sh`: clear the egress rule →
destroy → build → wait for the portal → provision the accounts → re-apply the egress rule. A failure
at any step leaves the egress rule **off** and the stack down, which is the safe direction: the
instance is either serving with the rule on, or not serving at all.

## Container containment

Read off the running container:

```
user=[irisowner] privileged=false capdrop=[ALL] readonly=false
volume vm_flightdeck-demo-data -> /durable rw=true
docker.sock mounted: 0
```

- Unprivileged, `no-new-privileges`, every capability dropped and only the seven IRIS needs added back.
- **No bind mount of any kind.** Whoever administers IRIS through the portal can read and write
  anything mounted into it, and on a public demo that is everyone. Durable data is a named volume.
- The Docker socket is not mounted, so the portal cannot reach the daemon that runs it.

### Egress, restricted at runtime

The VM keeps full internet — it needs it to pull, update and accept SSH. The **container** does not,
once it is serving. The rule is on `DOCKER-USER`, scoped to the container's subnet, with established
connections returned first so the proxy keeps talking to the published port.

Verified in both directions:

| | Result |
|---|---|
| Before the rule, from inside the container | `REACHED` (https to an external host) |
| After the rule, from inside the container | `blocked` (https, and plain http to 1.1.1.1) |
| Portal, after the rule | 200 |
| Full rebuild with the rule in the cycle | works from nothing, 28 s |

This is the one risk that would travel beyond a disposable machine: someone who takes administrative
control of IRIS through the public portal using it to reach a third party, which arrives as an abuse
notice rather than as damage here.

## VM surface

- **SSH is key-only.** `PasswordAuthentication no`, `KbdInteractiveAuthentication no`,
  `PermitRootLogin no`, in `/etc/ssh/sshd_config.d/01-flightdeck.conf` — named `01-` because sshd
  keeps the **first** value it reads for a keyword and the image's `50-cloud-init.conf` enables
  password authentication.
- Administration is through the unprivileged `flightdeck` user with sudo.
- **Firewall**: 22 and 80 only.

The change was made with a session held open throughout, and validated before that session was
closed: a new connection as `flightdeck` succeeded, root was refused (`Permission denied (publickey)`),
and password authentication was refused. Only then was the held session released.

> Note for anyone repeating this: UFW does not filter Docker-published ports, because Docker inserts
> its own rules ahead of UFW's chain. The demo is safe because the port is bound to loopback, not
> because the firewall covers it. Verified from outside: `109.123.244.170:52780` has no route.

---

# What running the suite against a real server found

The full Playwright matrix was run against the VM's instance (through an SSH tunnel to its loopback,
so the harness could reach the admin API the proxy correctly refuses from outside):

**106 passed, 43 skipped, 4 failed.** The four are worth their own sections, because three were real
and one was the server being far away.

## 1. Every non-ASCII character was mangled on every real install

**The worst of the three, and the one no test here could have caught.**

`FlightDeck.UI.Static` sets `%response.CharSet = "utf-8"` and then writes files that are *already*
UTF-8. CSP translates on the way out, so every non-ASCII byte was encoded twice:

| | bytes for `—` |
|---|---|
| the file on disk | `e2 80 94` |
| what the server delivered | `c3 a2 c2 80 c2 94` |

The served bundle was **183 bytes larger** than the file it came from. The shipped interface contains
`·`, `×`, `—`, `"`, `"`, `…`, `↑` and `→`, so all of them arrived as mojibake — on **every** install,
Docker or IPM, since the static server was written.

**Why nothing caught it:** every Playwright project points at `127.0.0.1:5173`, the Vite dev server.
`FlightDeck.UI.Static` serves no test in this repository. The suite has never fetched a single byte
from the server that real users are served by.

Fixed with `%response.NoCharSetConvert = 1`, and `index.html` is now read and spliced as bytes rather
than as characters. Served bytes are now identical to the file on disk. A test was added that fetches
the bundle **from the IRIS origin** and asserts no double-encoded sequence — and it was confirmed to
fail with the fix removed before being accepted.

Found by opening the deployed page and reading it.

## 2. A test that hard-coded an account name

`last-admin.spec.ts` parameterises on `ADMIN.user` everywhere except one `page.evaluate`, which names
`_SYSTEM` literally. On the development container those are the same, so it passed. Here the
administrator is `demo`, so the test disabled every other administrator and then asked the server to
disable `_SYSTEM` — which the loop had already disabled. The server correctly answered 422 ("nothing
would change") and the self-protection rule was never reached, which the test read as a failure of
self-protection.

Latent on any install whose administrator is not `_SYSTEM`. Fixed; passes against the VM.

## 3. A race that only latency makes visible

`processes.spec.ts` called `count()` on the process rows immediately after asserting the list
container was visible. `count()` does not wait. On loopback the rows are already there; over a link
with real latency they are not, and the count came back 0.

This is the third instance of this exact mistake in this repository (the others were in `shell.spec.ts`
and were found the same way — by running somewhere slower). Fixed by waiting for the first row.

## 4. The 2-second budget, and what it actually costs at a distance

`shell.spec.ts` asserts first useful content in under 2 seconds. Against the VM it measured
**3129 ms**. Measured properly, the VM is not slow:

| Path | index.html |
|---|---|
| On the VM, loopback | **4 ms** |
| From here, through the public proxy | 435 ms (of which 214 ms is TCP connect) |
| Through the SSH tunnel the suite used | 426 ms |
| The JS bundle, from here | **1.50 s for 573 KB** |

So the budget is not violated by the server; it is violated by ~210 ms of round-trip latency and a
573 KB bundle. The assertion is a product claim measured on a local install and it still holds there.
**The actionable number is the bundle**: for an evaluator on another continent it is the dominant
cost of the first screen.

Not changed, deliberately: the claim is about a local install, and weakening it to accommodate
transatlantic latency would make it mean nothing.

## 5. One intermittent failure, not diagnosed

`processes.spec.ts` SC-006 (the server refusing to terminate the process serving this session) failed
once in the full run with an empty block message, and **passed on re-run with no change made**. The
preview was verified directly against the VM and returns the correct refusal:

> "This is the process running your own session. Terminating it would end your session mid-request…"

The likely cause is the instability feature 004 already recorded — IRIS serves consecutive requests
from different processes, so the process the list reports as serving this request may not be the one
serving the next call. It is recorded as intermittent rather than as fixed, because nothing was
fixed.

## What the demo shows that a local install does not

The credential block under the sign-in form, from `FD_DEMO_USER`/`FD_DEMO_PASSWORD` in the VM's
compose, injected by the server into `index.html` as a meta tag. Verified on both sides, which is the
property that matters:

- on the demo: the meta tag is present and the block renders with the user, the password, the hourly
  reset and the plain-HTTP warning;
- on a clean local install: neither the tag nor the block, asserted by an end-to-end test and by four
  unit tests on the parser.

Nobody who installs FlightDeck at home finds a password printed under the sign-in form.

## A rebuild used to show a bare 404

The hourly rebuild takes about 30 seconds, and during it a visitor got IRIS's own Apache page:

> **Not Found** — The requested URL /flightdeck/ was not found on this server.

Caught by screenshotting the demo while a rebuild happened to be running. On a demo whose entire job
is to be looked at, that is the worst 30 seconds it has. nginx now intercepts 404 and 5xx **on the
portal path only** — legitimate under `/flightdeck/`, since the SPA answers index.html for every path
there — and serves a page that says the instance is rebuilding, why, and that it will take about half
a minute. The API path is not intercepted: its 404s and 403s are answers the portal needs.

## Cadence and worst case

| | |
|---|---|
| Watchdog | every 5 minutes; rebuilds on a failed demo sign-in |
| Rebuild | hourly, and on watchdog failure; 28 seconds |
| Worst case for a visitor | arriving during a rebuild: a page saying so, that reloads itself |
| Worst case for the machine | a visitor with `%All` does something destructive; the next rebuild erases it, and at most an hour of other visitors' changes go with it — which is stated on the sign-in form |
| Worst case that leaves the machine | a visitor uses IRIS to attack a third party. This is what the egress rule exists to prevent, and it is verified in both directions |
