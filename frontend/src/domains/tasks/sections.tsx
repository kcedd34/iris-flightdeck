import { ActionBar } from "../../pattern/ActionBar";
import { DomainSection } from "../../pattern/DomainSection";
import { SingletonSection } from "../../pattern/SingletonSection";
import { useDomainMutation } from "../../pattern/useDomainMutation";

const DOMAIN = "tasks";

/**
 * UC07: the task manager itself. Suspending it stops every scheduled task on the instance, which is
 * why it is a reinforced confirmation whose text says so (spec FR-008).
 */
export function TaskManager() {
  const { run, error } = useDomainMutation();
  return (
    <SingletonSection
      entity={{ domain: DOMAIN, entityType: "task-manager", keys: {} }}
      label="Task manager"
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
                operationId: "POST /v2/task/manager/suspend",
                label: "Suspend",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "POST /v2/task/manager/suspend", keys: {}, params: {}, noun: "task manager" });
                },
              },
              {
                operationId: "POST /v2/task/manager/resume",
                label: "Resume",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "POST /v2/task/manager/resume", keys: {}, params: {}, noun: "task manager" });
                },
              },
              {
                operationId: "POST /v2/task/manager/run",
                label: "Start",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "POST /v2/task/manager/run", keys: {}, params: {}, noun: "task manager" });
                },
              },
            ]}
          />
        </>
      )}
    />
  );
}

/** UC07: the Work Queue Manager categories. */
export function WorkQueueCategories() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="wqm-category"
      label="Work queue categories"
      meta={(item) => `max ${String(item.object.MaxActiveWorkers ?? "—")} active · ${String(item.object.DefaultWorkers ?? "—")} default`}
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
                operationId: "DELETE /v2/wqm-category",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/wqm-category", keys: detail.keys, noun: "category" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No category matches", cause: "The filters exclude every work queue category on this instance.", nextAction: "Clear the filters or the search text." }}
    />
  );
}

/**
 * UC07: the asynchronous results the platform is holding. The same mechanism the disk instrument
 * uses, listed (spec FR-010, FR-011).
 */
export function AsyncResults() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="async-result"
      label="Async results"
      meta={(item) => `${String(item.object.State ?? "")} · queued ${String(item.object.TimeQueued ?? "")}`}
      stateFilter={{
        label: "State",
        options: [
          { value: "", label: "Every state" },
          { value: "flight", label: "In flight" },
          { value: "done", label: "Finished" },
        ],
        matches: (item, value) => (value === "flight" ? Boolean(item.facts.inFlight) : !item.facts.inFlight),
      }}
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
                operationId: "POST /v2/async-result/cancel",
                label: "Cancel",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "POST /v2/async-result/cancel", keys: detail.keys, params: { id: String(detail.keys.id ?? "") }, noun: "async result" });
                },
              },
              {
                operationId: "POST /v2/async-result/pause",
                label: "Pause",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "POST /v2/async-result/pause", keys: detail.keys, params: { id: String(detail.keys.id ?? "") }, noun: "async result" });
                },
              },
              {
                operationId: "POST /v2/async-result/resume",
                label: "Resume",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "POST /v2/async-result/resume", keys: detail.keys, params: { id: String(detail.keys.id ?? "") }, noun: "async result" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No async result matches", cause: "The instance is holding no asynchronous result that matches.", nextAction: "Clear the filters, or run an operation that reports asynchronously." }}
    />
  );
}
