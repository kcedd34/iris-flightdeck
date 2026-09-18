# The test that passed while the feature did nothing

*Notes from building a management portal on the SysAdmin API — on what the platform actually answers,
where a native provider stops being legitimate, and one bug that every assertion I had was blind to.*

---

I have been building FlightDeck, a keyboard-first administration portal for InterSystems IRIS built
entirely on the official SysAdmin API. This is not a tour of it. It is four things I got wrong or
found out the hard way, written down because each cost me time — and one of them let a broken feature
through a suite of 150 end-to-end tests without a single red light.

## 1. The canvas that never drew, and passed every test

The portal has an instrument cluster: CPU, memory, shared memory, disk, each a large number with a
trailing time series drawn on `<canvas>`. Canvas rather than an SVG chart library, deliberately — at
a one-second refresh with six series, declarative SVG degrades visibly.

The test for it did this:

```ts
const series = page.getByTestId("instrument-series").first();
await expect(series).toBeVisible();
expect(await series.evaluate((n) => n.tagName)).toBe("CANVAS");
const width = await series.evaluate((n) => (n as HTMLCanvasElement).width);
expect(width).toBeGreaterThan(0);
```

Element present. Correct tag. Non-zero width. It passed on every install, on all three IRIS versions
the project supports, on every run of the suite.

The line was never drawn. Not once, on any instance, from the day the feature shipped until the day I
happened to look at a screenshot.

Here is the whole bug. The sliding window keeps each series in a `Map` and mutates the array in place
as readings arrive:

```ts
push(id, value) {
  const points = series.get(id) ?? [];
  points.push(value);
  while (points.length > capacity) points.shift();
  series.set(id, points);
},
series(id) {
  return series.get(id) ?? [];   // ← the live array
}
```

The component that draws it is keyed on that array:

```ts
useEffect(() => {
  /* … */
  if (points.length < 2) return;   // nothing to stroke from one point
  /* … */
}, [points, max, reducedMotion]);
```

`series(id)` hands out the same array object every time. React compares dependencies by identity. The
identity never changes, so the effect ran exactly once — on mount, when the window held a single
reading — hit the early return, and never ran again. The canvas sat there, correct size, correct
colour, empty.

I found it by accident. I was capturing a screenshot for the README and the picture came back with
numbers and no lines. The fix is one line: return a copy.

```ts
series(id) {
  return [...(series.get(id) ?? [])];
}
```

The lesson is not "beware mutable state in React deps" — you knew that. It is about what the test
asserted. Every claim in it was true and none of them was the claim that mattered. The assertion I
should have written is the only one that cannot be satisfied by a canvas that does nothing:

```ts
await expect.poll(async () => series.evaluate((node) => {
  const canvas = node as HTMLCanvasElement;
  const image = canvas.getContext("2d")!.getImageData(0, 0, canvas.width, canvas.height).data;
  let painted = 0;
  for (let i = 3; i < image.length; i += 4) if (image[i] !== 0) painted++;
  return painted;                       // count non-transparent pixels
})).toBeGreaterThan(0);
```

Count the pixels. If you are testing something that draws, test that it drew.

There was a second one in the same family, found the same week. A test asserted that a jump from a
failed task run opened the log stream filtered on that run:

```ts
await expect(page.getByTestId("logs-correlation")).toContainText("Correlation received: task");
```

The element's real test id is `logs-correlated`. The screen's real text is "Filtered on task…". Both
wrong — and it passed, because the test begins with:

```ts
test.skip(failed === null, "this install has recorded no failed task run");
```

No install had ever recorded a failed run, so the assertion had never executed. A skip with an honest
reason is good practice; a skip that is *always* taken is an assertion you have not written yet. Both
of those tests now run, because something else in the project makes the demonstration task fail on
purpose before the check.

## 2. `/proc` is not ObjectScript's job

The SysAdmin API reports IRIS's own counters and IRIS shared memory. It does not report host CPU or
host memory, so those come from `/proc/stat` and `/proc/meminfo` — one of the few places the portal
reads something the official API does not expose.

The first version was ObjectScript, and it had a workaround in it that bothered me:

```objectscript
// %Stream.FileCharacter cannot be used: procfs files report size 0, so a stream reads nothing.
open path:("RS"):2
use path
for i=1:1:4096 { read line  set text = text _ line _ $char(10) }
```

A sequential device, opened by hand, read line by line, closed and `$io` restored on every path —
because a procfs file reports size 0 and IRIS's stream classes conclude there is nothing to read.
Then `$piece` and `$zstrip` walking the text with whitespace collapsed by a `"<=>W"` strip.

In Embedded Python the same provider is:

```python
with open("/proc/meminfo", "r") as handle:
    return handle.read()
```

and the parse is `str.partition(":")` and `str.split()`. The whole `ReadFile` helper went away,
because the only reason it existed was a limitation Python does not have.

What I deliberately did **not** move: the `%Status` contract the callers expect, the previous CPU
sample held in the session, and the arithmetic. The published percentages are rounded with
`$normalize`, and they are checked against `free` and `top` — moving the rounding into Python would
have changed values for no reason. Python reads and parses; ObjectScript keeps what is its own.

Two practical notes for anyone doing this:

**Guard the call, not just the code.** If the Python runtime is unusable, the *call* raises before
your Python ever runs. One guarded helper turns that into the same empty answer a missing file
produces, so an instance without Embedded Python degrades exactly like an instance whose `/proc`
cannot be read — through the status the class already returned, with a reason on the screen.

**And a compiler rule that will cost you an hour if you do not know it:**

```objectscript
ClassMethod G(name As %String) As %String
{
	try {
		quit name            // #1043: QUIT argument not allowed
	} catch {
		quit ""              // same error
	}
}
```

Inside a `TRY`, `QUIT` exits the block and cannot carry a return value. Assign to a variable and quit
after the `try`/`catch`. This is documented ObjectScript semantics rather than a bug, but the failure
mode is nasty: I had wrapped the Python calls in exactly that shape, and every reading came back
empty — which looks precisely like an instance without Embedded Python. I spent a while suspecting
the wrong layer.

## 3. Where a native provider stops being legitimate

The portal's rule is that the official API is the source, and a native provider exists only where the
API offers nothing. That rule is easy until it puts you somewhere uncomfortable.

On IRIS 2026.1 the SysAdmin API is v1, and the journal operations are not there. I had already
written native providers for other v1 gaps — disk usage per database, namespace reads — and verified
each against the official API on 2026.2, request for request. The journal looked like the same job.

It is not, and the difference is worth stating precisely. A journal record read has to be filtered by
the databases the *calling user* may read. Implementing that natively means the portal deciding which
records you are allowed to see. That is an authorization decision, and authorization is the one thing
this portal delegates entirely to IRIS — it stores no credential, and every capability it offers comes
from the privilege each API operation declares.

So the journal is the place where "the API doesn't offer it, write it natively" stops:

> FlightDeck does not read the journal natively: filtering records by the databases you can read is
> an authorization decision that belongs to IRIS.

On that version the journal source says why it is absent, and the other four log sources keep
streaming. It is a smaller feature and a defensible one. A native reader that silently applied its own
idea of who may see what would have been larger and wrong.

The general form: **a gap you can fill with a read is not the same as a gap you can only fill by
deciding something on the platform's behalf.** The second kind is not a gap, it is a boundary.

## 4. What the platform actually answered

A scattering of things measured on live instances that the documentation did not tell me, kept here
because each one changed a design.

**The asynchronous `LOCATION` header names v1 even on a v2 instance.** `POST /v2/database-dir/info`
answers 202 with an empty result and `LOCATION: /api/admin/v1/async-result?id=<id>`. I checked both:
`/v1/async-result` and `/v2/async-result` each answer for that id, so the `v1` in the path is
cosmetic rather than a dialect instruction. The right move is to read the **id** out of the header
and poll through whatever path your own dialect layer would use — not to follow the string. Take it
literally and you have quietly hard-coded a version into code that is supposed to be
version-agnostic.

**A stock IRIS Community instance writes no alerts log.** The manager directory has `messages.log`,
`journal.log` and `SystemMonitor.log`; IRIS writes an alerts log only where System Monitor's alert
handling is configured. I had built an alerts source before finding that out, and "absent" turned out
to be its *normal* state rather than an error path. So it became a designed state: the source says
what an alerts log is and where it comes from, instead of showing an empty list that reads as "no
alerts have happened".

**`%IsDefined("name")` returns true on a `%DynamicArray`.** Checking a field before unwrapping an
object is not enough; check `%ClassName(1) = "%Library.DynamicObject"` too, or an array will happily
pretend to be an object with that property.

**IRIS serves consecutive HTTP requests from different processes.** I had a self-protection rule —
"you may not terminate the process running your own session" — implemented with `$job`. It compares
the process serving *this* request, which is not the one that served the last one. The list marked one
process and the block refused another: the rule could refuse an arbitrary process and let the real one
through. It now compares the CSP session id, and the list says exactly what it is marking ("Serving
this request").

**`MaxConsoleLogSize` will delete your test.** I wanted to prove that a 100 MB log pages at constant
cost, so I grew `messages.log` to 100 MB. IRIS rotated it to `messages.old_<date>` on the next line it
wrote and my measurement read a fresh 322-byte file. The instance is allowed to manage its own log;
measure the reader on a file you made for the purpose.

**Rounding differences are real differences.** Two of the above findings only became visible because
the portal's numbers are checked against `top` and `free` on every install, to the digit. If you
publish a percentage, publish where it came from and compare it to something independent, or you will
not notice the day it drifts.

---

## The thread

Three of these four are the same mistake seen from different angles: I had a check, the check passed,
and the check was not testing the thing. The canvas test asserted presence instead of drawing. The
correlation test asserted a string that had never once been evaluated. The 100 MB measurement measured
a file the instance had replaced underneath it.

The one that was not a mistake — the journal — is the mirror image: a case where the easy thing was
available and taking it would have moved a decision to the wrong side of a boundary.

FlightDeck is MIT and on Open Exchange. If you want to see the pixel-counting assertion or the
`/proc` provider, they are in `frontend/e2e/instruments.spec.ts` and
`backend/cls/FlightDeck/Native/HostMetrics.cls`. The platform findings above, with the raw responses
that produced them, are in `verification/README.md` — that file is the project's memory of what the
platform actually does, as opposed to what I assumed on the day.

---

<!-- Draft. Before publishing:
     - add the Open Exchange and repository links
     - check the tags the Developer Community expects (ObjectScript, Embedded Python, Testing, IRIS)
     - the canvas section is the strongest opening; keep it first if the editor asks for cuts
     - do not add screenshots of the portal here: this is an engineering post, and the video and the
       README carry the product -->
