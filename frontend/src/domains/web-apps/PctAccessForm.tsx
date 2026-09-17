import { changedFields, ObjectForm } from "../../pattern/ObjectForm";
import { useDomainMutation } from "../../pattern/useDomainMutation";

const FIELDS = [
  { name: "Name", type: "string", description: "Web application, or all-applications." },
  { name: "AllowType", type: "string", description: "Class or package.", enum: ["AllowClass", "AllowPackage"] },
  { name: "Class", type: "string", description: "Class or package name; must start with %." },
  { name: "AllowAccess", type: "boolean", description: "Allow access to the class or package." },
] as const;

/**
 * Create or edit a percent class access configuration. The identity (application, allow type, class)
 * is fixed on edit: a different identity is a different configuration, created with New.
 */
export function PctAccessForm({ mode, keys, original, onDone }: { mode: "create" | "edit"; keys?: Record<string, string>; original: Record<string, unknown>; onDone: (keys?: Record<string, string>) => void }) {
  const { run, error, setError, busy } = useDomainMutation();
  return (
    <ObjectForm
      title={mode === "create" ? "New percent class access" : `Edit ${keys?.class}`}
      fields={FIELDS}
      sections={[{ title: "Configuration", fields: ["Name", "AllowType", "Class", "AllowAccess"] }]}
      initial={original}
      readOnlyFields={mode === "edit" ? ["Name", "AllowType", "Class"] : []}
      submitLabel="Review changes"
      error={error}
      busy={busy}
      onCancel={() => onDone()}
      onSubmit={async (values) => {
        const target = mode === "create" ? { name: String(values.Name ?? ""), allowType: String(values.AllowType ?? ""), class: String(values.Class ?? "") } : keys!;
        if (!target.name || !target.allowType || !target.class) {
          setError("Application, allow type and class are required.");
          return;
        }
        const proposed = mode === "create" ? { AllowAccess: Boolean(values.AllowAccess) } : changedFields({ AllowAccess: original.AllowAccess }, { AllowAccess: values.AllowAccess });
        const outcome = await run({ operationId: "PUT /v2/web-app/pct-access", keys: target, proposed, noun: "percent class access" });
        if (outcome.status === "applied") onDone(target);
      }}
    />
  );
}
