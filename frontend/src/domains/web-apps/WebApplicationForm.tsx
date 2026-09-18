import { SCHEMAS } from "../generated/schemas";
import { changedFields, ObjectForm } from "../../pattern/ObjectForm";
import { PRESENTATIONS } from "../presentation";
import { AuthenticationEditor, MatchRolesEditor } from "../../pattern/editors";
import { useDomainMutation } from "../../pattern/useDomainMutation";

const NAME_FIELD = { name: "Name", type: "string", description: "Path of the web application, for example /csp/myapp." } as const;

/** Create or edit a web application. Every field the official PUT accepts, typed from the schema. */
export function WebApplicationForm({ mode, name, original, onDone }: { mode: "create" | "edit"; name?: string; original: Record<string, unknown>; onDone: (name?: string) => void }) {
  const { run, error, setError, busy } = useDomainMutation();
  const sections = PRESENTATIONS["web-apps/web-application"]!.sections;
  const fields = mode === "create" ? [NAME_FIELD, ...SCHEMAS.Application.fields] : SCHEMAS.Application.fields;
  return (
    <ObjectForm
      title={mode === "create" ? "New web application" : `Edit ${name}`}
      fields={fields}
      sections={mode === "create" ? [{ title: "Identity", fields: ["Name"] }, ...sections] : sections}
      initial={original}
      editors={{ AutheEnabled: AuthenticationEditor, MatchRoles: MatchRolesEditor }}
      submitLabel="Review changes"
      error={error}
      busy={busy}
      onCancel={() => onDone()}
      onSubmit={async (values) => {
        const target = mode === "create" ? String(values.Name ?? "").trim() : name!;
        if (!target) {
          setError("Name is required.");
          return;
        }
        const proposed = changedFields(original, values);
        delete proposed.Name;
        const outcome = await run({ operationId: "PUT /v2/web-app", keys: { name: target }, proposed, noun: "web application" });
        if (outcome.status === "applied") onDone(target);
      }}
    />
  );
}
