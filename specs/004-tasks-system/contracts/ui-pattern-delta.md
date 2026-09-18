# UI pattern delta — feature 004

Extends `specs/002-webapps-explorer-mutations/contracts/ui-pattern.md`, which stays authoritative for
everything it already defines, and `specs/003-permissions-security/contracts/ui-pattern-delta.md`.
Feature 004 adds **two** pattern modules and changes nothing else. Anything a domain needs that is
not here is a change to this contract, not a local component (spec FR-045).

---

## 1. `src/pattern/instruments` — the instrument cluster

### What it is

A row of instruments with identical geometry. Each instrument is a large primary number with a short
trailing time series beneath it. The cluster owns the refresh loop, the sliding window and the
focus behaviour; a domain supplies only the reading.

### Contract

```ts
type Band = "normal" | "caution" | "warning";

interface InstrumentReading {
  id: string;
  label: string;
  unit: string;
  value: number | null;
  band: Band;
  scope?: string;          // what the number measures, e.g. "host"
  available: boolean;
  reason?: string | null;  // why it is unavailable, from the capability map
  detail?: string | null;  // one short line under the series, e.g. "IRISAPP 72%"
  async?: AsyncState;      // §2, when the value arrives asynchronously
}

interface ClusterProps {
  readings: InstrumentReading[];
  intervalSeconds: number;
  mode: "polling";         // shown on screen; the only transport (spec FR-020a)
  windowSeconds: number;   // bounded; the window lives here and nowhere else
  onIntervalChange(seconds: number): void;
}
```

### Rules the module enforces

1. **Canvas, never a declarative SVG chart library.** At a one-second refresh with several series,
   SVG degrades visibly (docs/design.md §5). This is the one technical decision of that document
   that breaks the signature moment if ignored.
2. **Geometry is identical across instruments**: the number at 40px, weight 500, tabular numerals, in
   `text-primary`; the series a 1.5px stroke in `state-actual`, with no axis, grid, legend, fill or
   gradient. Repetition is what makes it read as a panel rather than as cards.
3. **The series slides**; points do not animate in.
4. **A crossed threshold changes the number's colour and adds the state icon. It never blinks or
   animates.**
5. **The window lives in the client session only.** Nothing is persisted; a reload starts a new
   window (RN-FD-21).
6. **Telemetry pauses when the document is hidden and resumes on focus**, keeping the accumulated
   window.
7. **An unavailable instrument keeps its place**, disabled, with its reason; the others keep
   updating.
8. **Reduced motion**: with `prefers-reduced-motion`, the series redraws in place without the sliding
   animation. The numbers still update.

---

## 2. `src/pattern/async` — the asynchronous value

### What it is

A value that arrives by firing a platform task and polling its result. Used by the disk instrument,
the asynchronous results section and the three long storage operations (compact, defragment,
integrity-check).

### Contract

```ts
type AsyncState = {
  state: "idle" | "Queued" | "Running" | "Finished" | "Failed" | "Canceled" | "Paused";
  handle?: string;
  lastValueAt?: string | null;
  stale: boolean;
  message?: string | null;   // the platform's own text
};

function useAsyncValue<T>(source: AsyncSource<T>): {
  value: T | undefined;      // the last known value; never cleared by a refresh
  state: AsyncState;
  refresh(): void;
};
```

### Rules the module enforces

1. **The last known value stays on screen** in every state but a `Finished` that carries a new one.
2. **No spinner where the number is.** Progress is shown beside or under the value, never in its
   place (RN-FD-32, spec FR-023).
3. **A value older than the refresh interval is marked stale**, with the time it was read.
4. **A failure shows the platform's message beside the value**, not instead of it.
5. **A formatted value from the platform is displayed verbatim** (for example `DiskFree`,
   `"792.78GB"`); the module never parses it into a number of its own.

---

## 3. Two additions to existing pattern pieces

### 3.1 The dry-run states an expected duration

`MutationDescriptor` gains an optional `expectedDuration` (a short human phrase, e.g. "minutes on a
large database"). When present, the dry-run states it beside the consequence, and the applying state
repeats it. This is how compact, defragment and integrity-check avoid reading as a frozen
application — the same failure the ten-second TLS test showed in feature 003 (spec FR-037b).

### 3.2 A control disabled by the object itself

`ActionBar` already disables a control the capability map does not offer. It now also accepts a
per-object reason, so a control the **API** disabled for **this object** (`CanBeTerminated` false,
`Removable` false) renders disabled with that reason and **never issues the request** (RN-FD-34,
spec FR-029). The reason text comes from the descriptor, and the predicate reads facts only.

---

## 4. What does not change

- One dry-run, one confirmation ladder, one trail. No per-domain dialog, diff renderer or trail
  write; `check:mutation-boundary` keeps enforcing it.
- Entity types, markers, links, grades and self-protection stay data in descriptors.
- Availability keeps coming from the capability map; no code outside the dialect layer tests the
  instance version, and `check:dialect` keeps enforcing it.
- Section tabs, list, inspector, links panel and object form are used as delivered.
