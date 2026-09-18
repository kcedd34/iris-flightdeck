import { SCHEMAS } from "../generated/schemas";
import { changedFields, ObjectForm, SecretEditor } from "../../pattern/ObjectForm";
import { useDomainMutation } from "../../pattern/useDomainMutation";

export interface SecurityFormProps {
  mode: "create" | "edit";
  keys?: Record<string, string>;
  original: Record<string, unknown>;
  onDone: (keys?: Record<string, string>) => void;
}

interface Config {
  schema: keyof typeof SCHEMAS;
  /** The key the official operation identifies the object with. */
  keyName: string;
  keyLabel: string;
  createOperationId?: string;
  editOperationId: string;
  noun: string;
  sections: { title: string; fields: string[] }[];
  secretFields?: string[];
}

/** One form per security entity, all configured from the official schema (feature 003 US3). */
function SecurityForm({ config, mode, keys, original, onDone }: SecurityFormProps & { config: Config }) {
  const { run, error, setError, busy } = useDomainMutation();
  const identity = { name: config.keyName, type: "string", description: `${config.keyLabel}. Required.` };
  const fields = [identity, ...SCHEMAS[config.schema].fields, ...(config.secretFields ?? []).map((name) => ({ name, type: "string", description: "Secret material: set or replaced, never read back." }))];
  const editors = Object.fromEntries((config.secretFields ?? []).map((name) => [name, SecretEditor]));
  const sections = mode === "create" ? [{ title: "Identity", fields: [config.keyName] }, ...config.sections] : config.sections;
  return (
    <ObjectForm
      title={mode === "create" ? `New ${config.noun}` : `Edit ${keys?.[config.keyName] ?? config.noun}`}
      fields={fields}
      sections={sections}
      initial={original}
      editors={editors}
      submitLabel="Review changes"
      error={error}
      busy={busy}
      onCancel={() => onDone()}
      onSubmit={async (values) => {
        const key = mode === "create" ? String(values[config.keyName] ?? "").trim() : keys![config.keyName]!;
        if (!key) return setError(`${config.keyLabel} is required.`);
        const { [config.keyName]: identityValue, ...rest } = values;
        void identityValue;
        const proposed = mode === "create" ? rest : changedFields(original, rest);
        const outcome = await run({
          operationId: mode === "create" ? (config.createOperationId ?? config.editOperationId) : config.editOperationId,
          keys: { [config.keyName]: key },
          proposed,
          noun: config.noun,
        });
        if (outcome.status === "applied") onDone({ [config.keyName]: key });
      }}
    />
  );
}

const TLS: Config = {
  schema: "SSLConfig",
  keyName: "name",
  keyLabel: "Configuration name",
  editOperationId: "PUT /v2/security/ssl-configuration",
  noun: "TLS configuration",
  secretFields: ["PrivateKeyPassword"],
  sections: [
    { title: "Configuration", fields: ["Description", "Enabled", "Type", "TLSMinVersion", "TLSMaxVersion", "CipherList", "Ciphersuites"] },
    { title: "Certificates", fields: ["CAFile", "CertificateFile", "PrivateKeyFile", "PrivateKeyType", "PrivateKeyPassword", "VerifyPeer", "VerifyDepth", "AuthorizeCN"] },
    { title: "OCSP", fields: ["OCSP", "OCSPURL", "OCSPIssuerCert", "OCSPResponseFile", "OCSPTimeout"] },
  ],
};

const X509: Config = {
  schema: "X509Credential",
  keyName: "alias",
  keyLabel: "Alias",
  createOperationId: "POST /v2/security/x509-credential",
  editOperationId: "PUT /v2/security/x509-credential",
  noun: "X.509 credential",
  secretFields: ["PrivateKeyPassword"],
  sections: [{ title: "Credential", fields: ["CAFile", "OwnerList", "PeerNames", "CertificateFile", "PrivateKeyFile", "PrivateKeyPassword"] }],
};

const WALLET: Config = {
  schema: "WalletCollection",
  keyName: "name",
  keyLabel: "Collection name",
  editOperationId: "PUT /v2/wallet/collection",
  noun: "wallet collection",
  sections: [{ title: "Collection", fields: ["UseResource", "EditResource"] }],
};

const LDAP: Config = {
  schema: "LDAPConfig",
  keyName: "name",
  keyLabel: "Configuration name",
  editOperationId: "PUT /v2/security/ldap/configuration",
  noun: "LDAP configuration",
  sections: [
    { title: "Server", fields: ["Description", "LDAPHostNames", "LDAPBaseDN", "LDAPBaseDNForGroups", "LDAPCACertFile", "LDAPSearchUsername", "LDAPServerTimeout", "LDAPClientTimeout"] },
    { title: "Attributes", fields: ["LDAPAttributeFullName", "LDAPAttributeMail", "LDAPAttributeRoles", "LDAPAttributeEscalationRoles", "LDAPAttributeNameSpace", "LDAPAttributeRoutine", "LDAPUniqueDNIdentifier"] },
  ],
};

const MFT: Config = {
  schema: "MFTConnection",
  keyName: "connection",
  keyLabel: "Connection name",
  editOperationId: "PUT /v2/security/mft/connection",
  noun: "MFT connection",
  sections: [{ title: "Connection", fields: ["Service", "URL", "SSLConfiguration", "Username", "ApplicationName"] }],
};

const SUPERSERVER: Config = {
  schema: "Superserver",
  keyName: "port",
  keyLabel: "Port",
  editOperationId: "PUT /v2/security/superserver",
  noun: "superserver",
  sections: [
    { title: "Superserver", fields: ["Description", "Enabled", "SSLConfig", "SSLSupportLevel", "SystemDefault"] },
    { title: "Protocols", fields: ["EnableCacheDirect", "EnableClients", "EnableCSP", "EnableDataCheck", "EnableECP", "EnableMirror", "EnableNodeJS", "EnableShadows", "EnableSharding", "EnableSNMP", "EnableWebLink"] },
  ],
};

const OAUTH_SERVER_DEFINITION: Config = {
  schema: "OAuth2ServerDefinition",
  keyName: "serverId",
  keyLabel: "Issuer endpoint",
  editOperationId: "PUT /v2/security/oauth2/client/server-definition",
  noun: "OAuth 2.0 server definition",
  sections: [{ title: "Server", fields: SCHEMAS.OAuth2ServerDefinition.fields.map((f) => f.name) }],
};

const OAUTH_SERVER_CLIENT: Config = {
  schema: "OAuth2ServerClient",
  keyName: "clientId",
  keyLabel: "Client id",
  editOperationId: "PUT /v2/security/oauth2/server/client",
  noun: "OAuth 2.0 client",
  sections: [{ title: "Client", fields: ["Name", "Description", "ClientType", "RedirectURL", "LaunchURL", "DefaultScope"] }],
};

const OAUTH_RESOURCE_SERVER: Config = {
  schema: "OAuth2ResourceServer",
  keyName: "name",
  keyLabel: "Resource server name",
  editOperationId: "PUT /v2/security/oauth2/resource-server",
  noun: "OAuth 2.0 resource server",
  sections: [{ title: "Resource server", fields: ["Enabled", "Description", "IssuerEndpoint", "ScopeRequiredToConnect", "Audiences", "AccessTokenIsJWT", "AlwaysCallIntrospection", "ClientId", "IntrospectionAuthMethod", "UseOIDC", "Authenticator"] }],
};

export const FORMS = {
  tls: (p: SecurityFormProps) => <SecurityForm config={TLS} {...p} />,
  x509: (p: SecurityFormProps) => <SecurityForm config={X509} {...p} />,
  wallet: (p: SecurityFormProps) => <SecurityForm config={WALLET} {...p} />,
  ldap: (p: SecurityFormProps) => <SecurityForm config={LDAP} {...p} />,
  mft: (p: SecurityFormProps) => <SecurityForm config={MFT} {...p} />,
  superserver: (p: SecurityFormProps) => <SecurityForm config={SUPERSERVER} {...p} />,
  oauthServerDefinition: (p: SecurityFormProps) => <SecurityForm config={OAUTH_SERVER_DEFINITION} {...p} />,
  oauthServerClient: (p: SecurityFormProps) => <SecurityForm config={OAUTH_SERVER_CLIENT} {...p} />,
  oauthResourceServer: (p: SecurityFormProps) => <SecurityForm config={OAUTH_RESOURCE_SERVER} {...p} />,
};
