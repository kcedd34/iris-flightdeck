import { useState } from "react";
import type { EntityDetailResponse } from "../../api/types";
import { ActionBar } from "../../pattern/ActionBar";
import { DomainSection } from "../../pattern/DomainSection";
import { SingletonSection } from "../../pattern/SingletonSection";
import { useDomainMutation } from "../../pattern/useDomainMutation";
import {
  AUDIT_CLEAR_COUNT,
  AUDIT_COPY,
  AUDIT_PURGE,
  CONNECTION_TEST,
  INITIAL_ACCESS_TOKEN,
  LDAP_SEARCH_PASSWORD,
  LDAP_TEST,
  MFT_AUTH_URL,
  OAUTH_CLIENT_SECRET,
  OAUTH_SERVER_PASSWORD,
  RESOURCE_SERVER_SECRET,
  SMTP_PASSWORD,
  SecurityActionForm,
  WALLET_SECRET,
  WALLET_SECRET_DELETE,
  type ActionFormProps,
} from "./ActionForms";
import { FORMS } from "./forms";

const DOMAIN = "security";

/** UC06: TLS configurations, with the platform's own connection test. */
export function TlsConfigurations() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="tls-configuration"
      label="TLS configurations"
      createOperationId="PUT /v2/security/ssl-configuration"
      meta={(item) => String(item.object.Type ?? "")}
      renderForm={(form, done) =>
        form.mode === "create" ? (
          FORMS.tls({ mode: "create", original: { Enabled: true, Type: "Client" }, onDone: done })
        ) : form.mode === "password" ? (
          <SecurityActionForm config={CONNECTION_TEST} keys={form.detail.keys} onDone={() => done()} />
        ) : (
          FORMS.tls({ mode: "edit", keys: form.detail.keys, original: form.detail.object, onDone: done })
        )
      }
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
              { operationId: "PUT /v2/security/ssl-configuration", label: "Edit", mutating: true, onActivate: () => openForm({ mode: "edit", detail }) },
              { operationId: "POST /v2/security/ssl-configuration/test", label: "Test connection", mutating: true, onActivate: () => openForm({ mode: "password", detail }) },
              {
                operationId: "DELETE /v2/security/ssl-configuration",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/ssl-configuration", keys: detail.keys, noun: "TLS configuration" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No TLS configuration matches", cause: "The filters exclude every configuration on this instance.", nextAction: "Clear the filters or the search text." }}
      emptyUnfiltered={{ title: "No TLS configuration", cause: "This instance defines no TLS configuration.", nextAction: "Create one with New." }}
    />
  );
}

/** UC06: X.509 credentials, with the validity the platform reports for each certificate. */
export function X509Credentials() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="x509-credential"
      label="X.509 credentials"
      createOperationId="POST /v2/security/x509-credential"
      meta={(item) => String(item.object.CAFile ?? "")}
      renderForm={(form, done) =>
        form.mode === "create"
          ? FORMS.x509({ mode: "create", original: { OwnerList: [], PeerNames: [] }, onDone: done })
          : FORMS.x509({ mode: "edit", keys: form.detail.keys, original: form.detail.object, onDone: done })
      }
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
              { operationId: "PUT /v2/security/x509-credential", label: "Edit", mutating: true, onActivate: () => openForm({ mode: "edit", detail }) },
              {
                operationId: "DELETE /v2/security/x509-credential",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/x509-credential", keys: detail.keys, noun: "X.509 credential" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No X.509 credential matches", cause: "The filters exclude every credential on this instance.", nextAction: "Clear the filters or the search text." }}
      emptyUnfiltered={{ title: "No X.509 credential", cause: "This instance holds no X.509 credential.", nextAction: "Create one with New." }}
    />
  );
}

/** UC06: wallet collections and the secrets inside them, whose values are never displayed. */
export function Wallet() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="wallet-collection"
      label="Wallet collections"
      createOperationId="PUT /v2/wallet/collection"
      meta={(item) => String(item.object.UseResource ?? "")}
      renderForm={(form, done) =>
        form.mode === "create" ? (
          FORMS.wallet({ mode: "create", original: {}, onDone: done })
        ) : form.mode === "password" ? (
          <SecurityActionForm config={WALLET_SECRET} keys={form.detail.keys} onDone={() => done(form.detail.keys)} />
        ) : (
          FORMS.wallet({ mode: "edit", keys: form.detail.keys, original: form.detail.object, onDone: done })
        )
      }
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
              { operationId: "PUT /v2/wallet/collection", label: "Edit", mutating: true, onActivate: () => openForm({ mode: "edit", detail }) },
              { operationId: "PUT /v2/wallet/secret", label: "New secret", mutating: true, onActivate: () => openForm({ mode: "password", detail }) },
              {
                operationId: "DELETE /v2/wallet/collection",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/wallet/collection", keys: detail.keys, noun: "wallet collection" });
                },
              },
            ]}
          />
          <WalletSecretDelete detail={detail} />
        </>
      )}
      empty={{ title: "No wallet collection matches", cause: "The filters exclude every collection on this instance.", nextAction: "Clear the filters or the search text." }}
      emptyUnfiltered={{ title: "No wallet collection", cause: "This instance defines no wallet collection.", nextAction: "Create one with New." }}
    />
  );
}

/** Deleting one secret of a collection, by name: the API addresses it as "collection.secret". */
function WalletSecretDelete({ detail }: { detail: EntityDetailResponse }) {
  const [open, setOpen] = useState(false);
  if (!open) {
    return (
      <div className="actions">
        <button className="btn" type="button" onClick={() => setOpen(true)} data-testid="wallet-delete-secret">
          Delete a secret
        </button>
      </div>
    );
  }
  return <SecurityActionForm config={WALLET_SECRET_DELETE} keys={detail.keys} onDone={() => setOpen(false)} />;
}

/** UC06: LDAP configurations. The listing is a known platform defect for some privileges. */
export function Ldap() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="ldap-configuration"
      label="LDAP configurations"
      createOperationId="PUT /v2/security/ldap/configuration"
      meta={(item) => String(item.object.Description ?? "")}
      renderForm={(form, done) =>
        form.mode === "create" ? (
          FORMS.ldap({ mode: "create", original: {}, onDone: done })
        ) : form.mode === "password" ? (
          <SecurityActionForm config={LDAP_SEARCH_PASSWORD} keys={form.detail.keys} onDone={() => done()} />
        ) : form.mode === "action" ? (
          <SecurityActionForm config={LDAP_TEST} keys={form.detail.keys} onDone={() => done()} />
        ) : (
          FORMS.ldap({ mode: "edit", keys: form.detail.keys, original: form.detail.object, onDone: done })
        )
      }
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
              { operationId: "PUT /v2/security/ldap/configuration", label: "Edit", mutating: true, onActivate: () => openForm({ mode: "edit", detail }) },
              { operationId: "POST /v2/security/ldap/configuration/search-password", label: "Set search password", mutating: true, onActivate: () => openForm({ mode: "password", detail }) },
              { operationId: "POST /v2/security/ldap/test", label: "Test a login", mutating: true, onActivate: () => openForm({ mode: "action", detail, action: "test" }) },
              {
                operationId: "DELETE /v2/security/ldap/configuration",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/ldap/configuration", keys: detail.keys, noun: "LDAP configuration" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No LDAP configuration matches", cause: "The filters exclude every configuration on this instance.", nextAction: "Clear the filters or the search text." }}
      emptyUnfiltered={{ title: "No LDAP configuration", cause: "This instance defines no LDAP configuration.", nextAction: "Create one with New." }}
    />
  );
}

/** UC06: MFT connections, including the stored token that can only be deleted. */
export function Mft() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="mft-connection"
      label="MFT connections"
      createOperationId="PUT /v2/security/mft/connection"
      meta={(item) => String(item.object.Service ?? "")}
      renderForm={(form, done) =>
        form.mode === "create" ? (
          FORMS.mft({ mode: "create", original: {}, onDone: done })
        ) : form.mode === "action" ? (
          <SecurityActionForm config={MFT_AUTH_URL} keys={form.detail.keys} onDone={() => done()} />
        ) : (
          FORMS.mft({ mode: "edit", keys: form.detail.keys, original: form.detail.object, onDone: done })
        )
      }
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
              { operationId: "PUT /v2/security/mft/connection", label: "Edit", mutating: true, onActivate: () => openForm({ mode: "edit", detail }) },
              { operationId: "GET /v2/security/mft/connection/auth-code-url", label: "Get an authorization URL", mutating: true, onActivate: () => openForm({ mode: "action", detail, action: "auth-url" }) },
              {
                operationId: "DELETE /v2/security/mft/connection/token",
                label: "Delete stored token",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/mft/connection/token", params: { connection: detail.keys.connection! }, noun: "stored token" });
                },
              },
              {
                operationId: "DELETE /v2/security/mft/connection",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/mft/connection", keys: detail.keys, noun: "MFT connection" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No MFT connection matches", cause: "The filters exclude every connection on this instance.", nextAction: "Clear the filters or the search text." }}
      emptyUnfiltered={{ title: "No MFT connection", cause: "This instance defines no MFT connection.", nextAction: "Create one with New." }}
    />
  );
}

/** UC06: superservers, the ports the instance listens on. */
export function Superservers() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="superserver"
      label="Superservers"
      createOperationId="PUT /v2/security/superserver"
      meta={(item) => String(item.object.BindAddress ?? "")}
      renderForm={(form, done) =>
        form.mode === "create"
          ? FORMS.superserver({ mode: "create", original: { Enabled: true }, onDone: done })
          : FORMS.superserver({ mode: "edit", keys: form.detail.keys, original: form.detail.object, onDone: done })
      }
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
              { operationId: "PUT /v2/security/superserver", label: "Edit", mutating: true, onActivate: () => openForm({ mode: "edit", detail }) },
              {
                operationId: "DELETE /v2/security/superserver",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/superserver", keys: detail.keys, noun: "superserver" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No superserver matches", cause: "The filters exclude every superserver on this instance.", nextAction: "Clear the filters or the search text." }}
      emptyUnfiltered={{ title: "No superserver", cause: "This instance defines no superserver.", nextAction: "Create one with New." }}
    />
  );
}

export type ActionFormComponent = (props: ActionFormProps) => JSX.Element;

/** UC06: auditing — its setting, and the two writes that touch the instance's own audit trail. */
export function Auditing() {
  const { run, error } = useDomainMutation();
  const [form, setForm] = useState<"purge" | "copy" | "clear-count" | null>(null);
  if (form) {
    const config = form === "purge" ? AUDIT_PURGE : form === "copy" ? AUDIT_COPY : AUDIT_CLEAR_COUNT;
    return <SecurityActionForm config={config} keys={{}} onDone={() => setForm(null)} />;
  }
  return (
    <SingletonSection
      entity={{ domain: DOMAIN, entityType: "audit-settings", keys: {} }}
      label="Auditing"
      actions={(detail) => (
        <>
          {error && (
            <div className="dlist-error" role="alert" data-testid="action-error">
              {error}
            </div>
          )}
          <p className="logs-note" data-testid="audit-split-note">
            This is whether auditing runs, and what it recorded. <a href="/flightdeck/logs/audit-events">Logs, Audit events</a>{" "}
            holds the definitions of what gets captured, beside the stream where they are read.
          </p>
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              {
                operationId: "PUT /v2/security/audit/enabled",
                label: detail.object.Enabled ? "Turn auditing off" : "Turn auditing on",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "PUT /v2/security/audit/enabled", keys: {}, proposed: { Enabled: !detail.object.Enabled }, noun: "auditing" });
                },
              },
              { operationId: "POST /v2/security/audit/record/copy", label: "Copy records", mutating: true, onActivate: () => setForm("copy") },
              { operationId: "POST /v2/security/audit/record/purge", label: "Purge records", mutating: true, onActivate: () => setForm("purge") },
              { operationId: "POST /v2/security/audit/event/clear-count", label: "Clear an event count", mutating: true, onActivate: () => setForm("clear-count") },
            ]}
          />
        </>
      )}
    />
  );
}

/** UC06: web authentication, and the SMTP password that is only ever set. */
export function WebAuthentication() {
  const { run, error } = useDomainMutation();
  const [form, setForm] = useState(false);
  if (form) return <SecurityActionForm config={SMTP_PASSWORD} keys={{}} onDone={() => setForm(false)} />;
  return (
    <SingletonSection
      entity={{ domain: DOMAIN, entityType: "web-authentication", keys: {} }}
      label="Web authentication"
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
                operationId: "PUT /v2/security/web-auth",
                label: "Edit",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "PUT /v2/security/web-auth", keys: {}, proposed: { LoginCookieTimeout: detail.object.LoginCookieTimeout }, noun: "web authentication" });
                },
              },
              { operationId: "POST /v2/security/web-auth/smtp-password", label: "Set SMTP password", mutating: true, onActivate: () => setForm(true) },
            ]}
          />
        </>
      )}
    />
  );
}

export { OAuth2 } from "./OAuth2";
export { Encryption } from "./Encryption";
export { INITIAL_ACCESS_TOKEN, OAUTH_CLIENT_SECRET, OAUTH_SERVER_PASSWORD, RESOURCE_SERVER_SECRET };
