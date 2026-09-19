import type { EntityListItem } from "../../api/types";
import { ActionBar } from "../../pattern/ActionBar";
import { DomainSection } from "../../pattern/DomainSection";
import { ObjectForm } from "../../pattern/ObjectForm";
import { useDomainMutation } from "../../pattern/useDomainMutation";

/**
 * UC08: the process list and what may be done to a process.
 *
 * Which controls are enabled is not a judgement this screen makes. The official schema answers it
 * per process — CanBeTerminated, CanBeSuspended, CanReceiveBroadcast, CanBeExamined — the server
 * evaluates it, and the action bar renders the answer with its reason (RN-FD-34, spec FR-028).
 */
function BroadcastForm({ keys, onDone }: { keys: Record<string, string>; onDone: () => void }) {
  const { run, error, setError, busy } = useDomainMutation();
  return (
    <ObjectForm
      title="Broadcast a message"
      fields={[{ name: "message", type: "string", description: "The message the process receives on its device." }]}
      sections={[{ title: "Broadcast a message", fields: ["message"] }]}
      initial={{}}
      submitLabel="Review change"
      error={error}
      busy={busy}
      onCancel={onDone}
      onSubmit={async (values) => {
        const message = String(values.message ?? "");
        if (message === "") return setError("The message is required.");
        const outcome = await run({ operationId: "POST /v2/process/broadcast", keys, params: { id: keys.id ?? "", message }, noun: "process" });
        if (outcome.status === "applied") onDone();
      }}
    />
  );
}

const SORTS = [
  { value: "cpu", label: "CPU time" },
  { value: "globals", label: "Global references" },
  { value: "pid", label: "Process id" },
];

export function Processes() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain="system"
      entityType="process"
      label="Processes"
      filters={[
        { id: "namespace", label: "Namespace", options: [] },
        { id: "sort", label: "Sort by", options: SORTS },
      ]}
      matches={(item: EntityListItem, values) => {
        if (values.namespace && String(item.object.Nspace ?? "") !== values.namespace) return false;
        return true;
      }}
      meta={(item) =>
        `${String(item.object.Nspace ?? "—")} · ${String(item.object.Routine ?? "—")} · ${String(item.object.State ?? "")} · CPU ${String(item.object.CPUTime ?? 0)}`
      }
      renderForm={(form, done) => (form.mode === "password" ? <BroadcastForm keys={form.detail.keys} onDone={() => done()} /> : null)}
      actions={(detail, openForm) => (
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
                operationId: "POST /v2/process/terminate",
                label: "Terminate",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "POST /v2/process/terminate", keys: detail.keys, params: { id: detail.keys.id ?? "" }, noun: "process" });
                },
              },
              {
                operationId: "POST /v2/process/suspend",
                label: "Suspend",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "POST /v2/process/suspend", keys: detail.keys, params: { id: detail.keys.id ?? "" }, noun: "process" });
                },
              },
              {
                operationId: "POST /v2/process/resume",
                label: "Resume",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "POST /v2/process/resume", keys: detail.keys, params: { id: detail.keys.id ?? "" }, noun: "process" });
                },
              },
              { operationId: "POST /v2/process/broadcast", label: "Broadcast", mutating: true, onActivate: () => openForm({ mode: "password", detail }) },
            ]}
          />
        </>
      )}
      empty={{ title: "No process matches", cause: "The filters exclude every process the instance reports.", nextAction: "Clear the filters or the search text." }}
      emptyUnfiltered={{ title: "No process", cause: "The instance reported no process at all.", nextAction: "Reload the section; a running instance always reports at least its own daemons." }}
    />
  );
}
