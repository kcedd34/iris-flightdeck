import { useNavigate } from "react-router-dom";
import type { EntityDetailResponse, EntityListItem } from "../../api/types";
import { ActionBar } from "../../pattern/ActionBar";
import { DomainSection } from "../../pattern/DomainSection";
import { useDomainMutation } from "../../pattern/useDomainMutation";
import { HistoryBand, type Run } from "./HistoryBand";
import "./tasks.css";

function runsOf(object: Record<string, unknown>): Run[] {
  return (object.FDHistory as Run[] | undefined) ?? [];
}

/** The window the logs of a run are looked for in: the run itself, widened by a minute each side. */
function logsAddress(taskId: string, taskName: string, run: Run): string {
  const pad = (stamp: string, minutes: number) => {
    const parsed = Date.parse(stamp.replace(" ", "T"));
    if (Number.isNaN(parsed)) return stamp;
    return new Date(parsed + minutes * 60_000).toISOString().slice(0, 19).replace("T", " ");
  };
  const params = new URLSearchParams({
    taskId,
    taskName,
    from: pad(run.at, -1),
    to: pad(run.completed || run.at, 1),
  });
  // The logs domain's entry section: feature 005 builds the screen behind this address and reads
  // these parameters unchanged (feature 004 spec FR-041b).
  return `/logs/stream?${params.toString()}`;
}

/** The run history of one task, with the complete message of a failed run (spec FR-004). */
function Runs({ detail }: { detail: EntityDetailResponse }) {
  const navigate = useNavigate();
  const runs = runsOf(detail.object as Record<string, unknown>);
  const taskId = String(detail.keys.id ?? "");
  const taskName = detail.displayName;
  if (runs.length === 0) {
    return (
      <div className="lgroup" data-testid="task-runs">
        <div className="lgroup-h">Recent runs</div>
        <div className="lgroup-reason">The instance records no run for this task yet.</div>
      </div>
    );
  }
  return (
    <div className="lgroup" data-testid="task-runs">
      <div className="lgroup-h">Recent runs</div>
      <ul className="runs">
        {runs.map((run, index) => (
          <li key={`${run.at}-${index}`} className="run" data-result={run.result.toLowerCase()} data-testid={`task-run-${index}`}>
            <span className="run-at num">{run.at}</span>
            <span className="run-result">{run.running ? "Running" : run.result || "—"}</span>
            <span className="run-duration num">{run.durationSeconds === "" ? "" : `${run.durationSeconds}s`}</span>
            {run.message && (
              <span className="run-message" data-testid={`task-run-message-${index}`}>
                {run.message}
              </span>
            )}
            {run.result === "Error" && (
              <button
                type="button"
                className="btn-link"
                data-testid={`task-run-logs-${index}`}
                onClick={() => navigate(logsAddress(taskId, taskName, run))}
              >
                Open the logs of this period
              </button>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}

/** UC07: what is scheduled, what failed and why, and running one on demand. */
export function Tasks() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain="tasks"
      entityType="task"
      label="Tasks"
      stateFilter={{
        label: "State",
        options: [
          { value: "", label: "Every task" },
          { value: "scheduled", label: "Scheduled" },
          { value: "suspended", label: "Suspended" },
          { value: "failing", label: "Last run failed" },
        ],
        matches: (item: EntityListItem, value: string) => {
          if (value === "suspended") return Boolean(item.facts.suspended);
          if (value === "scheduled") return !item.facts.suspended;
          return item.facts.lastResult === "Error";
        },
      }}
      meta={(item) => (
        <>
          <span className="task-meta">
            {String(item.object.Namespace ?? "")} · next {String(item.object.NextScheduled || "not scheduled")}
          </span>
          <HistoryBand runs={runsOf(item.object as Record<string, unknown>)} />
        </>
      )}
      inspectorExtra={(detail) => <Runs detail={detail} />}
      actions={(detail) => (
        <>
          {error && (
            <div className="dlist-error" role="alert" data-testid="action-error">
              {error}
            </div>
          )}
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              {
                operationId: "POST /v2/task/run",
                label: "Run now",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "POST /v2/task/run", keys: detail.keys, params: { id: String(detail.keys.id ?? "") }, noun: "task" });
                },
              },
              {
                operationId: "POST /v2/task/suspend",
                label: "Suspend",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "POST /v2/task/suspend", keys: detail.keys, params: { id: String(detail.keys.id ?? "") }, noun: "task" });
                },
              },
              {
                operationId: "POST /v2/task/resume",
                label: "Resume",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "POST /v2/task/resume", keys: detail.keys, params: { id: String(detail.keys.id ?? "") }, noun: "task" });
                },
              },
              {
                operationId: "DELETE /v2/task",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/task", keys: detail.keys, noun: "task" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No task matches", cause: "The filters exclude every task this instance schedules.", nextAction: "Clear the filters or the search text." }}
    />
  );
}
