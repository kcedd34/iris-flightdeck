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
      return series.get(id) ?? [];
    },
  };
}
