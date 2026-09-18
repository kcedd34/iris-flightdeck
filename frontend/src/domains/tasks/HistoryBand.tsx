import type { ReactNode } from "react";

export interface Run {
  at: string;
  completed: string;
  kind: string;
  result: "Success" | "Error" | "";
  message: string;
  durationSeconds: number | "";
  running: boolean;
}

/**
 * The compact recent-history band (RN-FD-17, spec FR-002).
 *
 * It exists so an intermittent failure is visible without opening anything: one mark per run, most
 * recent last, with the platform's own result behind each mark.
 */
export function HistoryBand({ runs }: { runs: Run[] }): ReactNode {
  if (runs.length === 0) return <span className="band-empty">no runs recorded</span>;
  const ordered = [...runs].reverse();
  return (
    <span className="band" data-testid="history-band" aria-label={`${runs.length} recent runs`}>
      {ordered.map((run, index) => (
        <span
          key={`${run.at}-${index}`}
          className="band-run"
          data-result={run.result === "Error" ? "error" : "success"}
          title={`${run.at}: ${run.result}${run.message ? ` — ${run.message}` : ""}`}
        />
      ))}
    </span>
  );
}
