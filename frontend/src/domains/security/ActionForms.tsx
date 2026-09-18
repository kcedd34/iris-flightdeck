import { ObjectForm, SecretEditor } from "../../pattern/ObjectForm";
import { useDomainMutation } from "../../pattern/useDomainMutation";

/**
 * Forms for action-kind operations: values that are sent once and never read back (a secret, a
 * connection test, an audit purge). They go through the same confirmation as any other change.
 */
export interface ActionFormProps {
  keys: Record<string, string>;
  onDone: () => void;
}

interface ActionConfig {
  operationId: string;
  title: string;
  noun: string;
  submitLabel?: string;
  fields: { name: string; type: string; description: string; secret?: boolean }[];
  /** Parameters taken from the entity's keys, by name. */
  fromKeys?: Record<string, string>;
  /** Composes the operation's parameters when they are not the form's fields one to one. */
  buildParams?: (values: Record<string, unknown>, keys: Record<string, string>) => Record<string, string>;
}

function ActionForm({ config, keys, onDone }: ActionFormProps & { config: ActionConfig }) {
  const { run, error, setError, busy } = useDomainMutation();
  return (
    <ObjectForm
      title={config.title}
      fields={config.fields}
      sections={[{ title: config.title, fields: config.fields.map((f) => f.name) }]}
      initial={{}}
      editors={Object.fromEntries(config.fields.filter((f) => f.secret).map((f) => [f.name, SecretEditor]))}
      submitLabel={config.submitLabel ?? "Review change"}
      error={error}
      busy={busy}
      onCancel={onDone}
      onSubmit={async (values) => {
        if (config.buildParams) {
          const built = config.buildParams(values, keys);
          const missing = Object.entries(built).find(([, v]) => v === "");
          if (missing) return setError(`${missing[0]} is required.`);
          const outcome = await run({ operationId: config.operationId, keys, params: built, noun: config.noun });
          if (outcome.status === "applied") onDone();
          return;
        }
        const params: Record<string, string> = {};
        for (const [param, key] of Object.entries(config.fromKeys ?? {})) params[param] = keys[key] ?? "";
        for (const field of config.fields) {
          const value = values[field.name];
          if (value === undefined || value === "") {
            if (field.name === "endDateTime" || field.name === "beginDateTime" || field.name === "deleteAfterCopy") {
              params[field.name] = field.name === "deleteAfterCopy" ? "false" : "";
              continue;
            }
            return setError(`${field.description.split(".")[0]} is required.`);
          }
          params[field.name] = String(value);
        }
        const outcome = await run({ operationId: config.operationId, keys, params, noun: config.noun });
        if (outcome.status === "applied") onDone();
      }}
    />
  );
}

export const CONNECTION_TEST: ActionConfig = {
  operationId: "POST /v2/security/ssl-configuration/test",
  title: "Test this TLS configuration",
  noun: "TLS connection test",
  submitLabel: "Review test",
  fields: [
    { name: "host", type: "string", description: "Host to connect to. Required." },
    { name: "port", type: "string", description: "Port to connect to. Required." },
  ],
  fromKeys: { name: "name" },
};

export const WALLET_SECRET: ActionConfig = {
  operationId: "PUT /v2/wallet/secret",
  title: "New secret",
  noun: "wallet secret",
  fields: [
    { name: "secretName", type: "string", description: "Secret name inside the collection. Required." },
    { name: "type", type: "string", description: "Secret class. Required.", enum: ["%Wallet.KeyValue", "%Wallet.SymmetricKey", "%Wallet.RSA"] } as never,
    { name: "secret", type: "string", description: "The value. FlightDeck never reads it back.", secret: true },
  ],
  // The official API names a secret "<collection>.<secret>" in one parameter.
  buildParams: (values, keys) => ({
    name: `${keys.name}.${String(values.secretName ?? "").trim()}`,
    collection: keys.name ?? "",
    type: String(values.type ?? "%Wallet.KeyValue"),
    secret: String(values.secret ?? ""),
  }),
};

export const WALLET_SECRET_DELETE: ActionConfig = {
  operationId: "DELETE /v2/wallet/secret",
  title: "Delete a secret",
  noun: "wallet secret",
  fields: [{ name: "secretName", type: "string", description: "Secret name inside the collection. Required." }],
  buildParams: (values, keys) => ({
    name: `${keys.name}.${String(values.secretName ?? "").trim()}`,
    collection: keys.name ?? "",
  }),
};

export const LDAP_SEARCH_PASSWORD: ActionConfig = {
  operationId: "POST /v2/security/ldap/configuration/search-password",
  title: "Set the search password",
  noun: "LDAP search password",
  fields: [{ name: "searchPassword", type: "string", description: "The search password. Never read back.", secret: true }],
  fromKeys: { name: "name" },
};

export const AUDIT_PURGE: ActionConfig = {
  operationId: "POST /v2/security/audit/record/purge",
  title: "Purge audit records",
  noun: "audit records",
  fields: [
    { name: "beginDateTime", type: "string", description: "Oldest record to purge, empty for all." },
    { name: "endDateTime", type: "string", description: "Newest record to purge, empty for all." },
  ],
};

/** Feature 003 gap closed: a real sign-in at the directory server, so the password is write-only. */
export const LDAP_TEST: ActionConfig = {
  operationId: "POST /v2/security/ldap/test",
  title: "Test a login against this directory server",
  noun: "LDAP login test",
  submitLabel: "Review test",
  fields: [
    { name: "Username", type: "string", description: "The account to try, as the directory server knows it. Required." },
    { name: "Password", type: "string", description: "Its password. Sent once, never stored or shown. Required.", secret: true },
  ],
};

/** Feature 003 gap closed: asks the file transfer provider for an authorization URL. */
export const MFT_AUTH_URL: ActionConfig = {
  operationId: "GET /v2/security/mft/connection/auth-code-url",
  title: "Get an authorization URL",
  noun: "MFT authorization URL",
  submitLabel: "Review request",
  fields: [
    { name: "redirect", type: "string", description: "Where the provider sends the user back. Required." },
    { name: "scope", type: "string", description: "The access being asked for. Required." },
  ],
  fromKeys: { connection: "name" },
};

/** Feature 003 gap closed: a mapping of the resource server, created by service and key. */
export const RESOURCE_SERVER_MAPPING: ActionConfig = {
  operationId: "PUT /v2/security/oauth2/resource-server/mapping",
  title: "Add or edit a service mapping",
  noun: "resource server mapping",
  fields: [
    { name: "key", type: "string", description: "The mapping's key. Required." },
    { name: "Value", type: "string", description: "What the key maps to. Required." },
  ],
  fromKeys: { service: "name" },
};

/** Feature 003 gap closed: removes one mapping of the resource server. */
export const RESOURCE_SERVER_MAPPING_DELETE: ActionConfig = {
  operationId: "DELETE /v2/security/oauth2/resource-server/mapping",
  title: "Delete a service mapping",
  noun: "resource server mapping",
  fields: [{ name: "key", type: "string", description: "The mapping's key. Required." }],
  fromKeys: { service: "name" },
};

/** Feature 003 gap closed: revokes a user's tokens at the authorization server. */
export const OAUTH_REVOKE: ActionConfig = {
  operationId: "POST /v2/security/oauth2/revoke",
  title: "Revoke a user's tokens",
  noun: "OAuth 2.0 tokens",
  submitLabel: "Review revocation",
  fields: [{ name: "user", type: "string", description: "The user whose tokens stop working. Required." }],
};

/** Feature 003 gap closed: clears the recorded count of one audit event. */
export const AUDIT_CLEAR_COUNT: ActionConfig = {
  operationId: "POST /v2/security/audit/event/clear-count",
  title: "Clear the count of an audit event",
  noun: "audit event count",
  fields: [
    { name: "source", type: "string", description: "Event source, for example %System. Required." },
    { name: "type", type: "string", description: "Event type, for example %Security. Required." },
    { name: "name", type: "string", description: "Event name. Required." },
  ],
};

export const AUDIT_COPY: ActionConfig = {
  operationId: "POST /v2/security/audit/record/copy",
  title: "Copy audit records to another namespace",
  noun: "audit records",
  fields: [
    { name: "auditCopyNamespace", type: "string", description: "Destination namespace. Required." },
    { name: "deleteAfterCopy", type: "boolean", description: "Delete the records after copying them." },
    { name: "beginDateTime", type: "string", description: "Oldest record to copy, empty for all." },
    { name: "endDateTime", type: "string", description: "Newest record to copy, empty for all." },
  ],
};

export const SMTP_PASSWORD: ActionConfig = {
  operationId: "POST /v2/security/web-auth/smtp-password",
  title: "Set the SMTP password",
  noun: "SMTP password",
  fields: [{ name: "smtpPassword", type: "string", description: "The SMTP password. Never read back.", secret: true }],
};

export const OAUTH_SERVER_PASSWORD: ActionConfig = {
  operationId: "POST /v2/security/oauth2/server/password",
  title: "Set the authorization server password",
  noun: "authorization server password",
  fields: [{ name: "serverPassword", type: "string", description: "The server password. Never read back.", secret: true }],
};

export const OAUTH_CLIENT_SECRET: ActionConfig = {
  operationId: "POST /v2/security/oauth2/server/client/secret",
  title: "Replace the client secret",
  noun: "client secret",
  fields: [{ name: "clientSecret", type: "string", description: "The client secret. Never read back.", secret: true }],
  fromKeys: { clientId: "clientId" },
};

export const RESOURCE_SERVER_SECRET: ActionConfig = {
  operationId: "POST /v2/security/oauth2/resource-server/secret",
  title: "Replace the client secret",
  noun: "client secret",
  fields: [{ name: "clientSecret", type: "string", description: "The client secret. Never read back.", secret: true }],
  fromKeys: { name: "name" },
};

export const INITIAL_ACCESS_TOKEN: ActionConfig = {
  operationId: "POST /v2/security/oauth2/client/server-definition/initial-access-token",
  title: "Set the initial access token",
  noun: "initial access token",
  fields: [{ name: "initialAccessToken", type: "string", description: "The token. Never read back.", secret: true }],
  fromKeys: { serverId: "serverId" },
};

export function SecurityActionForm({ config, keys, onDone }: ActionFormProps & { config: ActionConfig }) {
  return <ActionForm config={config} keys={keys} onDone={onDone} />;
}
