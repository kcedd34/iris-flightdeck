import { SCHEMAS } from "../generated/schemas";
import { AuthenticationEditor } from "../../pattern/editors";
import { GrantsEditor } from "../../pattern/GrantsEditor";
import { changedFields, ObjectForm, SecretEditor } from "../../pattern/ObjectForm";
import { useDomainMutation } from "../../pattern/useDomainMutation";

export interface FormProps {
  mode: "create" | "edit";
  keys?: Record<string, string>;
  original: Record<string, unknown>;
  onDone: (keys?: Record<string, string>) => void;
}

/** Create a user (name and password) or edit one; the password is secret in every layer. */
export function UserForm({ mode, keys, original, onDone }: FormProps) {
  const { run, error, setError, busy } = useDomainMutation();
  const fields = [
    { name: "Name", type: "string", description: "Account name. Required." },
    { name: "Password", type: "string", description: "Initial password. Never read back." },
    ...SCHEMAS.User.fields,
  ];
  return (
    <ObjectForm
      title={mode === "create" ? "New user" : `Edit ${keys?.name}`}
      fields={fields}
      sections={[
        { title: "Account", fields: mode === "create" ? ["Name", "Password", "FullName", "Enabled", "Comment"] : ["FullName", "Enabled", "Comment", "EmailAddress"] },
        { title: "Access", fields: ["Roles", "EscalationRoles", "NameSpace", "Routine", "AutheEnabled"] },
        { title: "Password and expiry", fields: ["ChangePassword", "PasswordNeverExpires", "ExpirationDate", "AccountNeverExpires"] },
      ]}
      initial={original}
      editors={{ Password: SecretEditor, AutheEnabled: AuthenticationEditor }}
      submitLabel="Review changes"
      error={error}
      busy={busy}
      onCancel={() => onDone()}
      onSubmit={async (values) => {
        if (mode === "create") {
          const name = String(values.Name ?? "").trim();
          if (!name) return setError("A name is required.");
          if (!values.Password) return setError("A password is required to create an account. It is never stored by FlightDeck.");
          const { Name, ...rest } = values;
          void Name;
          const outcome = await run({ operationId: "POST /v2/security/user", keys: { name }, proposed: rest, noun: "user" });
          if (outcome.status === "applied") onDone({ name });
          return;
        }
        const proposed = changedFields(original, values);
        const outcome = await run({ operationId: "PUT /v2/security/user", keys: keys!, proposed, noun: "user" });
        if (outcome.status === "applied") onDone(keys);
      }}
    />
  );
}

/** Create or edit a role: what it inherits and what it grants. */
export function RoleForm({ mode, keys, original, onDone }: FormProps) {
  const { run, error, setError, busy } = useDomainMutation();
  const fields = [{ name: "Name", type: "string", description: "Role name. Required." }, ...SCHEMAS.Role.fields];
  return (
    <ObjectForm
      title={mode === "create" ? "New role" : `Edit ${keys?.name}`}
      fields={fields}
      sections={[{ title: "Role", fields: [...(mode === "create" ? ["Name"] : []), "Description", "EscalationOnly", "GrantedRoles", "Resources"] }]}
      initial={original}
      editors={{ Resources: GrantsEditor }}
      submitLabel="Review changes"
      error={error}
      busy={busy}
      onCancel={() => onDone()}
      onSubmit={async (values) => {
        const name = mode === "create" ? String(values.Name ?? "").trim() : keys!.name!;
        if (!name) return setError("A name is required.");
        const { Name, ...rest } = values;
        void Name;
        const proposed = mode === "create" ? rest : changedFields(original, rest);
        const outcome = await run({ operationId: "PUT /v2/security/role", keys: { name }, proposed, noun: "role" });
        if (outcome.status === "applied") onDone({ name });
      }}
    />
  );
}

/** Create or edit a resource. The official API rejects an empty public permission. */
export function ResourceForm({ mode, keys, original, onDone }: FormProps) {
  const { run, error, setError, busy } = useDomainMutation();
  const fields = [{ name: "Name", type: "string", description: "Resource name. Required." }, ...SCHEMAS.Resource.fields];
  return (
    <ObjectForm
      title={mode === "create" ? "New resource" : `Edit ${keys?.name}`}
      fields={fields}
      sections={[{ title: "Resource", fields: [...(mode === "create" ? ["Name"] : []), "Description", "PublicPermission"] }]}
      initial={original}
      submitLabel="Review changes"
      error={error}
      busy={busy}
      onCancel={() => onDone()}
      onSubmit={async (values) => {
        const name = mode === "create" ? String(values.Name ?? "").trim() : keys!.name!;
        if (!name) return setError("A name is required.");
        if (!String(values.PublicPermission ?? "").trim()) {
          return setError("The official API rejects an empty public permission. Give a permission (for example U), or leave the resource as it is.");
        }
        const { Name, ...rest } = values;
        void Name;
        const proposed = mode === "create" ? rest : changedFields(original, rest);
        const outcome = await run({ operationId: "PUT /v2/security/resource", keys: { name }, proposed, noun: "resource" });
        if (outcome.status === "applied") onDone({ name });
      }}
    />
  );
}

/** Edit a service. The platform defines them; none can be created. */
export function ServiceForm({ keys, original, onDone }: FormProps) {
  const { run, error, busy } = useDomainMutation();
  return (
    <ObjectForm
      title={`Edit ${keys?.name}`}
      fields={SCHEMAS.Service.fields}
      sections={[{ title: "Service", fields: ["Description", "Enabled", "AutheEnabled", "ClientSystems"] }]}
      initial={original}
      editors={{ AutheEnabled: AuthenticationEditor }}
      submitLabel="Review changes"
      error={error}
      busy={busy}
      onCancel={() => onDone()}
      onSubmit={async (values) => {
        const outcome = await run({ operationId: "PUT /v2/security/service", keys: keys!, proposed: changedFields(original, values), noun: "service" });
        if (outcome.status === "applied") onDone(keys);
      }}
    />
  );
}

/** Create or edit a privileged routine application. */
export function PrivilegedRoutineForm({ mode, keys, original, onDone }: FormProps) {
  const { run, error, setError, busy } = useDomainMutation();
  const fields = [{ name: "Name", type: "string", description: "Application name. Required." }, ...SCHEMAS.PrivilegedRoutineApplication.fields];
  return (
    <ObjectForm
      title={mode === "create" ? "New privileged routine application" : `Edit ${keys?.name}`}
      fields={fields}
      sections={[{ title: "Application", fields: [...(mode === "create" ? ["Name"] : []), "Description", "Enabled", "Resource", "Routines", "MatchRoles"] }]}
      initial={original}
      submitLabel="Review changes"
      error={error}
      busy={busy}
      onCancel={() => onDone()}
      onSubmit={async (values) => {
        const name = mode === "create" ? String(values.Name ?? "").trim() : keys!.name!;
        if (!name) return setError("A name is required.");
        const { Name, ...rest } = values;
        void Name;
        const proposed = mode === "create" ? rest : changedFields(original, rest);
        const outcome = await run({ operationId: "PUT /v2/security/privileged-routine", keys: { name }, proposed, noun: "privileged routine application" });
        if (outcome.status === "applied") onDone({ name });
      }}
    />
  );
}

/** Set a user's password: an action, with the new value secret in every layer. */
export function PasswordForm({ keys, onDone }: FormProps) {
  const { run, error, setError, busy } = useDomainMutation();
  return (
    <ObjectForm
      title={`Set the password of ${keys?.name}`}
      fields={[{ name: "NewPassword", type: "string", description: "The new password. FlightDeck never reads it back." }]}
      sections={[{ title: "Password", fields: ["NewPassword"] }]}
      initial={{}}
      editors={{ NewPassword: SecretEditor }}
      submitLabel="Review change"
      error={error}
      busy={busy}
      onCancel={() => onDone()}
      onSubmit={async (values) => {
        const password = String(values.NewPassword ?? "");
        if (!password) return setError("A new password is required.");
        const outcome = await run({
          operationId: "POST /v2/security/user/password",
          params: { name: keys!.name!, newPassword: password },
          noun: "user password",
        });
        if (outcome.status === "applied") onDone(keys);
      }}
    />
  );
}
