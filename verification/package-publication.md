# The published package: 0.1.0, and the 1.0.1 that replaced it

**2026-09-21.** `iris-flightdeck` was published to the community registry with documentation two
commits out of date. The code in it was current; the README in it was not. This records what was
wrong, how it was found, and what replaced it.

## What was published, and when

| | |
|---|---|
| Package | `iris-flightdeck` |
| Version | `0.1.0` |
| Published | 2026-09-19 19:48 |
| Registry | `https://pm.community.intersystems.com` |
| Size | 1 802 662 bytes |

The publication timestamp comes from the registry's own metadata
(`/packages/iris-flightdeck/0.1.0`), not from memory.

## How the mismatch was found

Not by remembering what was published. The tarball was downloaded from the registry and compared
file by file against `HEAD`:

```bash
curl -o iris-flightdeck-0.1.0.tgz \
  https://pm.community.intersystems.com/download/iris-flightdeck/-/iris-flightdeck-0.1.0.tgz
tar xzf iris-flightdeck-0.1.0.tgz && diff -rq . /path/to/working/tree
```

**The code was current.** `frontend/dist/assets/index-C0RnJ0s0.js` in the package hashes to
`628e0cc6a55bd5a5`, identical to the working tree, and `backend/` matched byte for byte. Anyone who
installed 0.1.0 got the same product.

**The documentation was not.** Eight files differed, all documentation or test tooling. The one that
mattered is `README.md`, which in the published package still:

- led the IPM path with `zpm "load /path/to/iris-flightdeck"` rather than
  `zpm "install iris-flightdeck"`, the published command;
- carried a section promising a link to an idea on the InterSystems Ideas Portal, **with the
  placeholder still unfilled** — the section was removed in `6bf2574` because that link is not a
  requirement of this contest (`docs/contest.md` §2.3);
- described the demonstration objects wrongly in three rows: the `FD_Demo_L1 → L2 → L3` role chain
  was missing, `/csp/fd-demo-reports` was missing, and the wallet collection was called empty when
  the install puts `FD_Demo_Token` in it.

Matching the packaged README against each commit placed the build at `e2f650d` (19:36), twelve
minutes before the publication. The two documentation commits that followed — `91f03cf` and
`6bf2574` — never reached the registry.

**A claim made here earlier, and withdrawn.** This record said the 0.1.0 tarball "contains a copy of
a `.tgz` at its own root, so the artefact carried a previous package inside itself". **That is false.**
Both 0.1.0 and 1.0.1 were listed with `tar tzf | grep -iE '\.(tgz|tar|zip)$'` and neither contains an
archive. What happened is that the download was extracted into the directory that held it, so `ls`
showed the downloaded file beside the extracted tree and it was read as package content. The size
difference has a different and legitimate explanation, below.

## Why this happened, and what would have caught it

Publishing was a single action performed once, and nothing afterwards compared the artefact on the
registry with the tree. Every other claim in this project has a gate over it —
`check-readme` over the README's structure, `check-dist` over the committed bundle,
`check-matrix-identity` over what the matrix ran against. The published package had none, so two
documentation commits could land without anyone noticing the registry was behind.

The general shape is the one this project keeps meeting: **an artefact nobody re-reads drifts from
the tree that produced it.** It is the same failure as the double-encoded assets, which no test
fetched from the server that serves them, and as the matrix that ran twice against IRIS for Health
while reporting three products.

## What replaced it

`1.0.1`, built from `HEAD`. Published on 2026-09-21 and verified below.

The number is `1.0.1` and not `1.0.0` because the Open Exchange listing **already shows a release
1.0.0**, dated 19 September, while the registry still serves the package `0.1.0`. The page advertises
one number and hands out another. `1.0.1` is free on both sides, so the release and the package can
finally read the same.

| | |
|---|---|
| Version | `1.0.1` (from `0.1.0`; the registry accepts only a higher version, and 1.0.0 is taken as a release) |
| Built from | the `HEAD` tree, exported with `git archive` so nothing untracked could enter |
| Size | 1 822 054 bytes as published (a locally built `zpm package` of the same tree is 550 300; see "Why the sizes differ") |
| Bundle | `index-C0RnJ0s0.js`, `628e0cc6a55bd5a5` — identical to 0.1.0 and to the working tree |
| Code | unchanged from 0.1.0 |
| Documentation | current |

The embedded README was checked on the three points that were wrong, first on a package built
locally and again on the artefact the registry actually serves:

```
Ideas Portal mentions: 0
zpm "install iris-flightdeck"        README.md:128
FD_Demo_L1 → FD_Demo_L2 → FD_Demo_L3 README.md:338
FD_Demo_Token                        README.md:341
```

## How this registry is actually fed

`zpm "iris-flightdeck publish"` answers `ERROR! Publishing module, authorization required.`, and the
first version of this record read that as a missing credential and gave two commands to obtain one.
**That was wrong, and the commands could not have worked.** The Open Exchange documentation is
explicit:

> "Open exchange is **the only place** to publish applications to the public IPM registry
> (pm.community.intersystems.com)."
> — [Publishing IPM applications](https://docs.openexchange.intersystems.com/apps/ipm/)

There is no publisher credential to obtain for the public registry. `zpm publish` is documented only
for testing, against your own registry or `https://test.pm.community.intersystems.com/registry/`.

**This also explains how 0.1.0 got there without anyone running publish.** The submission form
carries a checkbox:

> "Publish in Package Manager : if you use IPM (former ZPM) module in your app you can publish it to
> public IPM registry checking this box"
> — [Submit an application](https://docs.openexchange.intersystems.com/apps/submit/)

With it ticked, Open Exchange reads `module.xml` from the repository and pushes the package itself.
The version comes from `<Version>` at that moment — which was `0.1.0` — and **not** from the release
number on the listing, which is why the page shows a 1.0.0 release beside a 0.1.0 package.

## 1.0.1, published and verified

Released on Open Exchange on 2026-09-21; the registry published it at 14:48. Verified afterwards
rather than assumed.

| | |
|---|---|
| Registry `latest` | `1.0.1` |
| Published | 2026-09-21 14:48 |
| Size | 1 822 054 bytes |
| SHA-1 (registry metadata) | `25da0f7b01dcc5236c8fd2515387cfadbe675520` |
| SHA-1 (downloaded twice) | `25da0f7b01dcc5236c8fd2515387cfadbe675520` |

**The artefact matches the tree.** The tarball was downloaded from the registry and compared against
`HEAD` with `diff -rq`: **no file differs**. The bundle inside is `index-C0RnJ0s0.js`, hashing to
`628e0cc6a55bd5a5`, the same as the working tree.

**The README inside it is the current one**, checked on the three points that were wrong in 0.1.0:

```
Ideas Portal mentions: 0
zpm "install iris-flightdeck"        README.md:128
FD_Demo_L1 → FD_Demo_L2 → FD_Demo_L3 README.md:338
FD_Demo_Token                        README.md:341
```

**It installs on an instance that has never had FlightDeck.** A plain
`intersystemsdc/iris-community:2026.2-zpm` container was started, confirmed to have no FlightDeck
class, and the registry's own artefact was installed into it:

```
FlightDeck: SysAdmin API v2 present
FlightDeck: role FlightDeck_Runtime created (%DB_USER:R)
FlightDeck: web application /api/flightdeck present
FlightDeck: web application /flightdeck present
FlightDeck: install complete (demo=0)

zpm "list"            -> iris-flightdeck 1.0.1
GET /flightdeck/      -> 200, serving index-C0RnJ0s0.js
```

`demo=0`, which is right for this path: the demonstration objects only appear with `-DDemo=1`.

### Why the sizes differ, and why 1 822 054 is right

1.0.1 weighs 1 822 054 bytes, almost exactly what 0.1.0 weighed (1 802 662), while a `zpm package`
built locally from the same tree is 550 300. That gap was the reason to look, and the explanation is
that the two are packaged by different things with different scope:

- **`zpm package` ships what `module.xml` declares** — the resources, the README, the LICENSE and
  `frontend/dist`. Hence 550 300.
- **Open Exchange ships the repository.** The package is `git archive` of the released commit:
  615 entries, 6 674 152 bytes uncompressed, identical in both directions to `git archive eaa0555`.

Where the weight is, uncompressed:

| | |
|---|---|
| `docs/` | 1 581 975 — of which `docs/sysadmin-api-v2.json` alone is 1 004 473, the official API specification this project derives from |
| `backend/` | 1 133 914 |
| `specs/` | 915 212 |
| `frontend/dist` | 814 304 |
| `verification/` | 365 780 |

So the size is documentation and specifications, not a stowaway. Nothing in the package is untracked:
`node_modules`, `test-results`, `.git`, `__pycache__`, `frontend/.matrix` and `verification/demo-run.md`
are all present in the working tree and all correctly absent from the artefact.

### What this run could not prove

**`zpm "install iris-flightdeck"` was not exercised against the registry from here.** Outbound TCP
443 is blocked from every Docker container on this machine while the host has it, so IPM reports the
registry as `Available? No` and answers `'iris-flightdeck' not found in any repository`. The block is
this environment's, not the package's.

What was installed instead is **the byte-identical artefact the registry serves**, downloaded over
the host's network and verified twice against the registry's own SHA-1. So everything downstream of
the fetch is proven; the fetch itself is IPM's transport and is what anyone with network access
exercises. Worth re-running from a machine whose containers have outbound access before relying on
it.

One incidental note for whoever repeats this: the stock `intersystemsdc/iris-community` entrypoint
shuts IRIS down on start, which is why this project's own `Dockerfile` runs `/iris-main --check-caps
false` directly (feature 001 research R2). A bare `docker run` of the stock image will not stay up.

## The path that got it there, and why it waited

1. `module.xml` carries the new version and is pushed to GitHub. **Done**: `1.0.1` is on the default
   branch.
2. On Open Exchange, edit the application and choose **Release app** rather than **Send edits**.
   That is what triggers the package: "Release app : will guide you through filling out a release
   form where you can specify the release number"
   ([Update an application](https://docs.openexchange.intersystems.com/apps/update/)).
3. Afterwards, confirm on an instance that has never had FlightDeck:

   ```objectscript
   zpm "install iris-flightdeck"
   ```

   which must report `1.0.1`. **Done** — see above, with the caveat about the fetch.

**Step 2 waited until the submission was approved.** The submission is in moderation now, and on Open
Exchange an edit is not live until it is reviewed: "As soon as you send your edits for approval and
they are approved, you will no longer see these signs"
([Update an application](https://docs.openexchange.intersystems.com/apps/update/)). Creating a
release while the original submission is still under review would put a second pending change on top
of one already being read, so the moderator would be reviewing a moving target — and a release also
publishes release notes to subscribers, which is not something to send twice while the listing is
still provisional. That last part is reasoning rather than a quotation: the documentation states that
edits require approval, not what happens when they overlap a pending submission.

**Nothing is published by this repository.** The release was the author's action, taken after the
submission was approved, and the registry published the package from it.

## What to do next time

Open Exchange publishes the package, so the check belongs **after** a release: compare the artefact
the registry serves with the tree that produced it, rather than trusting that they agree. That is now
a command rather than a habit:

```bash
scripts/dev/check-published-package.sh <the commit the release was cut from>
```

It checks the version against `module.xml`, the SHA-1 against the one the registry declares, the size
against a declared expectation, that no archive is nested inside, and the tree against
`git archive <ref>` **in both directions**. Against the released commit it answers:

```
check-published-package: ok (iris-flightdeck 1.0.1, 1822054 bytes, tree identical to eaa0555)
```

Each of those five checks exists because something got past its absence. The size one is there
because a doubling was noticed by a human reading a number, two days late. The both-directions one is
there because the first comparison written for this record filtered one side out and could only ever
have seen files the package added, never ones it lacked. The nested-archive one is there because this
record confidently described a nesting that was never in the package.

Had it run once after the submission, 0.1.0's stale documentation would have been found the same day
instead of two days later.
