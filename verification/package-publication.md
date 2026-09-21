# The published package: 0.1.0, and why 1.0.1 replaces it

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

**One other thing the comparison showed**: the 0.1.0 tarball contains a copy of a `.tgz` at its own
root, so the artefact carried a previous package inside itself. The rebuilt tarball is 550 300 bytes
against 0.1.0's 1 802 662.

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

## What replaces it

`1.0.1`, built from `HEAD`.

The number is `1.0.1` and not `1.0.0` because the Open Exchange listing **already shows a release
1.0.0**, dated 19 September, while the registry still serves the package `0.1.0`. The page advertises
one number and hands out another. `1.0.1` is free on both sides, so the release and the package can
finally read the same.

| | |
|---|---|
| Version | `1.0.1` (from `0.1.0`; the registry accepts only a higher version, and 1.0.0 is taken as a release) |
| Built from | the `HEAD` tree, exported with `git archive` so nothing untracked could enter |
| Size | 550 300 bytes (measured on the 1.0.0 build; the version bump does not change it materially) |
| Bundle | `index-C0RnJ0s0.js`, `628e0cc6a55bd5a5` — identical to 0.1.0 and to the working tree |
| Code | unchanged from 0.1.0 |
| Documentation | current |

The embedded README was checked on the three points that were wrong, from a package built locally
before any release is created:

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

## The real path, and why it waits

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

   which must report `1.0.1`.

**Step 2 waits until the submission is approved.** The submission is in moderation now, and on Open
Exchange an edit is not live until it is reviewed: "As soon as you send your edits for approval and
they are approved, you will no longer see these signs"
([Update an application](https://docs.openexchange.intersystems.com/apps/update/)). Creating a
release while the original submission is still under review would put a second pending change on top
of one already being read, so the moderator would be reviewing a moving target — and a release also
publishes release notes to subscribers, which is not something to send twice while the listing is
still provisional. That last part is reasoning rather than a quotation: the documentation states that
edits require approval, not what happens when they overlap a pending submission.

**Nothing is published by this repository.** Releasing is the author's action, after approval.

## What to do next time

Open Exchange publishes the package, so the check belongs **after** a release: compare the artefact
the registry serves with the tree that produced it, rather than trusting that they agree.

```bash
curl -s https://pm.community.intersystems.com/packages/iris-flightdeck/latest   # version, size, hash
curl -sO https://pm.community.intersystems.com/download/iris-flightdeck/-/iris-flightdeck-<v>.tgz
tar xzf iris-flightdeck-<v>.tgz && diff -rq . <working tree>
```

The check that matters is the README and the bundle hash. Both are one command. Had this run once
after the submission, 0.1.0's stale documentation would have been found the same day instead of two
days later.
