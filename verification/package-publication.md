# The published package: 0.1.0, and why 1.0.0 replaced it

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
root, so the artefact carried a previous package inside itself. The 1.0.0 tarball is 550 300 bytes
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

## What replaced it

`1.0.0`, built from `HEAD`, aligned with the release number the Open Exchange listing shows.

| | |
|---|---|
| Version | `1.0.0` (from `0.1.0`; the registry accepts only a higher version) |
| Built from | the `HEAD` tree, exported with `git archive` so nothing untracked could enter |
| Size | 550 300 bytes |
| Bundle | `index-C0RnJ0s0.js`, `628e0cc6a55bd5a5` — identical to 0.1.0 and to the working tree |
| Code | unchanged from 0.1.0 |
| Documentation | current |

The embedded README was checked **before** publishing, on the three points that were wrong:

```
Ideas Portal mentions: 0
zpm "install iris-flightdeck"        README.md:128
FD_Demo_L1 → FD_Demo_L2 → FD_Demo_L3 README.md:338
FD_Demo_Token                        README.md:341
```

## Status of the publication

**Not yet published at the time of writing.** `zpm "iris-flightdeck publish"` answers:

```
Publish to: https://pm.community.intersystems.com
[iris-flightdeck]	Publish FAILURE
ERROR! Publishing module, authorization required.
```

The registry is configured as a read source with no publisher credential, and the credential belongs
to the author's InterSystems account. It is not stored in this repository, in any container, or in
this record — the same rule the portal itself follows about credentials.

The author publishes it with:

```objectscript
zpm "repo -n registry -r -url https://pm.community.intersystems.com/ -user <user> -pass <password>"
zpm "iris-flightdeck publish"
```

and it is confirmed afterwards by installing on an instance that has never had FlightDeck:

```objectscript
zpm "install iris-flightdeck"
```

which must report `1.0.0`.

## What to do next time

Before publishing any version, compare the artefact with the tree rather than trusting that they
agree, and do it again after publishing:

```bash
curl -s https://pm.community.intersystems.com/packages/iris-flightdeck/latest   # version, size, hash
curl -sO https://pm.community.intersystems.com/download/iris-flightdeck/-/iris-flightdeck-<v>.tgz
tar xzf iris-flightdeck-<v>.tgz && diff -rq . <working tree>
```

The check that matters is the README and the bundle hash. Both are one command.
