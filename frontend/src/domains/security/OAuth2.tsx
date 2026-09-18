import { useState } from "react";
import { ActionBar } from "../../pattern/ActionBar";
import { DomainSection } from "../../pattern/DomainSection";
import { SingletonSection } from "../../pattern/SingletonSection";
import { useDomainMutation } from "../../pattern/useDomainMutation";
import { INITIAL_ACCESS_TOKEN, OAUTH_CLIENT_SECRET, OAUTH_SERVER_PASSWORD, RESOURCE_SERVER_SECRET, SecurityActionForm } from "./ActionForms";
import { FORMS } from "./forms";

const FAMILIES = [
  { id: "server-definitions", label: "Server definitions" },
  { id: "server-clients", label: "Clients of this server" },
  { id: "resource-servers", label: "Resource servers" },
  { id: "authorization-server", label: "Authorization server" },
] as const;

type Family = (typeof FAMILIES)[number]["id"];

/**
 * UC06 OAuth 2.0 in its three roles. The official API keeps them apart, so the section chooses a
 * family and then renders the same list and inspector as every other section.
 */
export function OAuth2() {
  const [family, setFamily] = useState<Family>("server-definitions");
  return (
    <div className="oauth-section">
      <div className="dlist-bar" role="group" aria-label="OAuth 2.0 family">
        {FAMILIES.map((f) => (
          <button
            key={f.id}
            type="button"
            className={`btn${family === f.id ? " btn-primary" : ""}`}
            aria-pressed={family === f.id}
            onClick={() => setFamily(f.id)}
            data-testid={`oauth-family-${f.id}`}
          >
            {f.label}
          </button>
        ))}
      </div>
      {family === "server-definitions" && <ServerDefinitions />}
      {family === "server-clients" && <ServerClients />}
      {family === "resource-servers" && <ResourceServers />}
      {family === "authorization-server" && <AuthorizationServer />}
    </div>
  );
}

function ServerDefinitions() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain="security"
      entityType="oauth2-server-definition"
      label="Server definitions"
      createOperationId="PUT /v2/security/oauth2/client/server-definition"
      renderForm={(form, done) =>
        form.mode === "create" ? (
          FORMS.oauthServerDefinition({ mode: "create", original: {}, onDone: done })
        ) : form.mode === "password" ? (
          <SecurityActionForm config={INITIAL_ACCESS_TOKEN} keys={form.detail.keys} onDone={() => done()} />
        ) : (
          FORMS.oauthServerDefinition({ mode: "edit", keys: form.detail.keys, original: form.detail.object, onDone: done })
        )
      }
      actions={(detail, openForm) => (
        <>
          {error && <div className="dlist-error" role="alert">{error}</div>}
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              { operationId: "PUT /v2/security/oauth2/client/server-definition", label: "Edit", mutating: true, onActivate: () => openForm({ mode: "edit", detail }) },
              { operationId: "POST /v2/security/oauth2/client/server-definition/initial-access-token", label: "Set initial access token", mutating: true, onActivate: () => openForm({ mode: "password", detail }) },
              {
                operationId: "DELETE /v2/security/oauth2/client/server-definition",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/oauth2/client/server-definition", keys: detail.keys, noun: "server definition" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No OAuth 2.0 server definition", cause: "This instance defines no authorization server to act as a client of.", nextAction: "Create one, or choose another family above." }}
    />
  );
}

function ServerClients() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain="security"
      entityType="oauth2-server-client"
      label="Clients"
      createOperationId="PUT /v2/security/oauth2/server/client"
      renderForm={(form, done) =>
        form.mode === "create" ? (
          FORMS.oauthServerClient({ mode: "create", original: {}, onDone: done })
        ) : form.mode === "password" ? (
          <SecurityActionForm config={OAUTH_CLIENT_SECRET} keys={form.detail.keys} onDone={() => done()} />
        ) : (
          FORMS.oauthServerClient({ mode: "edit", keys: form.detail.keys, original: form.detail.object, onDone: done })
        )
      }
      actions={(detail, openForm) => (
        <>
          {error && <div className="dlist-error" role="alert">{error}</div>}
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              { operationId: "PUT /v2/security/oauth2/server/client", label: "Edit", mutating: true, onActivate: () => openForm({ mode: "edit", detail }) },
              { operationId: "POST /v2/security/oauth2/server/client/secret", label: "Replace client secret", mutating: true, onActivate: () => openForm({ mode: "password", detail }) },
              {
                operationId: "DELETE /v2/security/oauth2/server/client",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/oauth2/server/client", keys: detail.keys, noun: "client" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No client of this authorization server", cause: "This instance's authorization server has no registered client.", nextAction: "Create one, or choose another family above." }}
    />
  );
}

function ResourceServers() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain="security"
      entityType="oauth2-resource-server"
      label="Resource servers"
      createOperationId="PUT /v2/security/oauth2/resource-server"
      renderForm={(form, done) =>
        form.mode === "create" ? (
          FORMS.oauthResourceServer({ mode: "create", original: { Enabled: true }, onDone: done })
        ) : form.mode === "password" ? (
          <SecurityActionForm config={RESOURCE_SERVER_SECRET} keys={form.detail.keys} onDone={() => done()} />
        ) : (
          FORMS.oauthResourceServer({ mode: "edit", keys: form.detail.keys, original: form.detail.object, onDone: done })
        )
      }
      actions={(detail, openForm) => (
        <>
          {error && <div className="dlist-error" role="alert">{error}</div>}
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              { operationId: "PUT /v2/security/oauth2/resource-server", label: "Edit", mutating: true, onActivate: () => openForm({ mode: "edit", detail }) },
              { operationId: "POST /v2/security/oauth2/resource-server/secret", label: "Replace client secret", mutating: true, onActivate: () => openForm({ mode: "password", detail }) },
              {
                operationId: "DELETE /v2/security/oauth2/resource-server",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/oauth2/resource-server", keys: detail.keys, noun: "resource server" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No OAuth 2.0 resource server", cause: "This instance protects no API as an OAuth 2.0 resource server.", nextAction: "Create one, or choose another family above." }}
    />
  );
}

function AuthorizationServer() {
  const { run, error } = useDomainMutation();
  const [form, setForm] = useState(false);
  if (form) return <SecurityActionForm config={OAUTH_SERVER_PASSWORD} keys={{}} onDone={() => setForm(false)} />;
  return (
    <SingletonSection
      entity={{ domain: "security", entityType: "oauth2-server", keys: {} }}
      label="Authorization server"
      actions={(detail) => (
        <>
          {error && <div className="dlist-error" role="alert">{error}</div>}
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              { operationId: "POST /v2/security/oauth2/server/password", label: "Set server password", mutating: true, onActivate: () => setForm(true) },
              {
                operationId: "DELETE /v2/security/oauth2/server",
                label: "Delete the authorization server",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/oauth2/server", keys: {}, noun: "authorization server" });
                },
              },
            ]}
          />
        </>
      )}
    />
  );
}
