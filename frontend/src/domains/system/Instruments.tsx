import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { request } from "../../api/client";
import type { TelemetryReading } from "../../api/types";
import { Cluster } from "../../pattern/instruments/Cluster";
import "../../pattern/instruments/instruments.css";

const WINDOW_SECONDS = 60;

/**
 * UC08: the instrument cluster and the seize table below it.
 *
 * Telemetry polls one endpoint for the whole cluster, so five instruments are not five requests per
 * second, and pauses while the tab is hidden, resuming with the accumulated window (spec FR-019).
 */
export function Instruments() {
  const [intervalSeconds, setIntervalSeconds] = useState(1);
  const [hidden, setHidden] = useState(typeof document !== "undefined" && document.visibilityState === "hidden");

  useEffect(() => {
    const onVisibility = () => setHidden(document.visibilityState === "hidden");
    document.addEventListener("visibilitychange", onVisibility);
    return () => document.removeEventListener("visibilitychange", onVisibility);
  }, []);

  const telemetry = useQuery({
    queryKey: ["telemetry"],
    queryFn: ({ signal }) => request<TelemetryReading>("/telemetry", { signal }),
    refetchInterval: hidden ? false : intervalSeconds * 1000,
    refetchIntervalInBackground: false,
    // The last reading stays on screen while the next one is in flight: no instrument ever blanks.
    placeholderData: keepPreviousData,
    retry: false,
  });

  const reading = telemetry.data;
  return (
    <div className="view" data-testid="instruments-view">
      {telemetry.error && (
        <div className="dlist-error" role="alert" data-testid="telemetry-error">
          {telemetry.error.message}
        </div>
      )}
      <Cluster
        readings={reading?.instruments ?? []}
        mode={reading?.mode ?? "polling"}
        intervalSeconds={intervalSeconds}
        onIntervalChange={setIntervalSeconds}
        windowSeconds={WINDOW_SECONDS}
        paused={hidden}
      />
      <section className="ins-resources" aria-label="Resource contention" data-testid="resource-table">
        <div className="sect-h">Resource seizes</div>
        <p className="ins-note">
          What the instance reports for each internal resource. The specification states no meaning for these counters, so
          FlightDeck shows them as they arrive and sets no threshold of its own.
        </p>
        <table className="dtable">
          <thead>
            <tr>
              <th scope="col">Resource</th>
              <th scope="col">Seize</th>
              <th scope="col">Nseize</th>
              <th scope="col">Aseize</th>
              <th scope="col">Bseize</th>
              <th scope="col">Busy set</th>
            </tr>
          </thead>
          <tbody>
            {(reading?.resources ?? [])
              .filter((row) => row.Seize > 0 || row.Nseize > 0 || row.Aseize > 0 || row.Bseize > 0)
              .map((row) => (
                <tr key={row.Name}>
                  <th scope="row">{row.Name}</th>
                  <td className="num">{row.Seize}</td>
                  <td className="num">{row.Nseize}</td>
                  <td className="num">{row.Aseize}</td>
                  <td className="num">{row.Bseize}</td>
                  <td className="num">{row.BusySet}</td>
                </tr>
              ))}
          </tbody>
        </table>
      </section>
    </div>
  );
}
