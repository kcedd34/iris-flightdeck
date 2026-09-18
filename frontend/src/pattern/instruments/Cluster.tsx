import { useEffect, useMemo, useRef, useState } from "react";
import { Instrument, type InstrumentReading } from "./Instrument";
import { createWindow } from "./window";

export interface ClusterProps {
  readings: InstrumentReading[];
  /** The transport in use. Polling is the only one (spec FR-020a); the screen states it. */
  mode: "polling";
  intervalSeconds: number;
  onIntervalChange(seconds: number): void;
  windowSeconds: number;
  paused: boolean;
}

const INTERVALS = [1, 2, 5, 10];

/**
 * The instrument cluster (docs/design.md §5, spec FR-012 to FR-021).
 *
 * All instruments share one geometry, which is what makes the row read as a panel rather than as
 * cards. The window is kept here and nowhere else, the refresh mode and interval are visible, and
 * telemetry pauses when the tab is hidden and resumes with the window intact (spec FR-019).
 */
export function Cluster({ readings, mode, intervalSeconds, onIntervalChange, windowSeconds, paused }: ClusterProps) {
  const capacity = Math.max(2, Math.round(windowSeconds / Math.max(1, intervalSeconds)));
  const windowRef = useRef(createWindow(capacity));
  const [, setTick] = useState(0);
  const reducedMotion = useMemo(
    () => typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches,
    [],
  );

  useEffect(() => {
    for (const reading of readings) windowRef.current.push(reading.id, reading.available ? reading.value : null);
    setTick((value) => value + 1);
  }, [readings]);

  return (
    <section className="ins-cluster" aria-label="Instruments" data-testid="instrument-cluster">
      <div className="ins-row">
        {readings.map((reading) => (
          <Instrument key={reading.id} reading={reading} points={windowRef.current.series(reading.id)} reducedMotion={!!reducedMotion} />
        ))}
      </div>
      <div className="ins-mode" data-testid="telemetry-mode">
        <span>
          {paused ? "Paused while this tab is in the background" : `Refreshing by ${mode} every ${intervalSeconds}s`}
        </span>
        <label className="ins-interval">
          Interval
          <select
            value={intervalSeconds}
            onChange={(event) => onIntervalChange(Number(event.target.value))}
            data-testid="telemetry-interval"
            aria-label="Telemetry refresh interval in seconds"
          >
            {INTERVALS.map((seconds) => (
              <option key={seconds} value={seconds}>
                {seconds}s
              </option>
            ))}
          </select>
        </label>
        <span className="ins-window">Window {windowSeconds}s, kept in this tab only</span>
      </div>
    </section>
  );
}
