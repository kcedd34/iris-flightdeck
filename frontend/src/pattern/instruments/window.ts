/**
 * The sliding window of an instrument cluster (spec FR-018, RN-FD-21).
 *
 * It lives in the client session and nowhere else: the portal persists no metric history, so a
 * reload starts a new window. It is bounded, so telemetry running for hours cannot grow without
 * bound — retention is an observability tool's job, not a portal's.
 */
export interface Window {
  push(id: string, value: number | null): void;
  series(id: string): number[];
}

export function createWindow(capacity: number): Window {
  const series = new Map<string, number[]>();
  return {
    push(id, value) {
      if (value === null || Number.isNaN(value)) return;
      const points = series.get(id) ?? [];
      points.push(value);
      // Oldest first out: the window is the last `capacity` readings, whatever came before.
      while (points.length > capacity) points.shift();
      series.set(id, points);
    },
    series(id) {
      // A copy, deliberately. The window mutates its arrays in place as readings arrive, and handing
      // out the live one made every consumer see the same array identity for ever: the canvas's
      // redraw effect is keyed on that identity, so it ran once, on mount, when the window still
      // held a single point — and the series never drew a line at all. A copy also stops a caller
      // corrupting the window. Sixty numbers; the cost is not worth the class of bug it removes.
      return [...(series.get(id) ?? [])];
    },
  };
}
