import { ActionBar } from "../../pattern/ActionBar";
import { DomainSection } from "../../pattern/DomainSection";
import { ObjectForm } from "../../pattern/ObjectForm";
import { SingletonSection } from "../../pattern/SingletonSection";
import { useDomainMutation } from "../../pattern/useDomainMutation";
import { useSearchParams } from "react-router-dom";

const DOMAIN = "logs";

function SwitchDirectoryForm({ onDone }: { onDone: () => void }) {
  const { run, error, setError, busy } = useDomainMutation();
  return (
    <ObjectForm
      title="Switch the journal directory"
      fields={[{ name: "directory", type: "string", description: "Where the instance writes its journal from now on. Required." }]}
      sections={[{ title: "Switch the journal directory", fields: ["directory"] }]}
      initial={{}}
      submitLabel="Review change"
      error={error}
      busy={busy}
      onCancel={onDone}
      onSubmit={async (values) => {
        const directory = String(values.directory ?? "");
        if (directory === "") return setError("The directory is required.");
        const outcome = await run({ operationId: "POST /v2/journal/switch-dir", keys: {}, params: { directory }, noun: "journal directory" });
        if (outcome.status === "applied") onDone();
      }}
    />
  );
}

/**
 * UC09: the journal as configuration, separate from the records it produces (spec FR-028).
 *
 * The records are a source of the stream; the files and settings are here, and every write goes
 * through the shared dry-run at the grade its risk deserves.
 */
export function Journal() {
  const { run, error } = useDomainMutation();
  const [params, setParams] = useSearchParams();
  const form = params.get("form");
  if (form === "switch-dir") {
    return (
      <SwitchDirectoryForm
        onDone={() => {
          const next = new URLSearchParams(params);
          next.delete("form");
          setParams(next, { replace: true });
        }}
      />
    );
  }
  return (
    <div className="logs-journal">
      <SingletonSection
        entity={{ domain: DOMAIN, entityType: "journal-settings", keys: {} }}
        label="Journal settings"
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
                  operationId: "POST /v2/journal/switch-file",
                  label: "Switch journal file",
                  mutating: true,
                  onActivate: async () => {
                    await run({ operationId: "POST /v2/journal/switch-file", keys: {}, params: {}, noun: "journal file" });
                  },
                },
                {
                  operationId: "POST /v2/journal/switch-dir",
                  label: "Switch journal directory",
                  mutating: true,
                  onActivate: () => {
                    const next = new URLSearchParams(params);
                    next.set("form", "switch-dir");
                    setParams(next, { replace: true });
                  },
                },
              ]}
            />
          </>
        )}
      />
      <DomainSection
        domain={DOMAIN}
        entityType="journal-file"
        label="Journal files"
        meta={(item) => `${String(item.object.Size ?? "")} bytes · ${String(item.object.CreationTime ?? "")}`}
        actions={(detail) => (
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              {
                operationId: "POST /v2/journal/file/integrity-check",
                label: "Integrity check",
                mutating: true,
                onActivate: async () => {
                  await run({
                    operationId: "POST /v2/journal/file/integrity-check",
                    keys: detail.keys,
                    params: { file: String(detail.keys.file ?? "") },
                    noun: "journal file",
                  });
                },
              },
            ]}
          />
        )}
        empty={{ title: "No journal file matches", cause: "The filters exclude every journal file this instance keeps.", nextAction: "Clear the filters or the search text." }}
      />
    </div>
  );
}
