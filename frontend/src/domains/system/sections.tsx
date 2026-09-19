import { ActionBar } from "../../pattern/ActionBar";
import { DomainSection } from "../../pattern/DomainSection";
import { SingletonSection } from "../../pattern/SingletonSection";
import { useDomainMutation } from "../../pattern/useDomainMutation";
import type { EntityDetailResponse } from "../../api/types";

const DOMAIN = "system";

/** One delete action, which every section here offers in the same shape. */
function deleteAction(operationId: string, noun: string, detail: EntityDetailResponse, run: ReturnType<typeof useDomainMutation>["run"]) {
  return {
    operationId,
    label: "Delete",
    mutating: true,
    onActivate: async () => {
      await run({ operationId, keys: detail.keys, noun });
    },
  };
}

function Errors({ error }: { error: string | null }) {
  if (!error) return null;
  return (
    <div className="dlist-error" role="alert" data-testid="action-error">
      {error}
    </div>
  );
}

/** UC08: the configured databases. Creation is performed; deletion is declined, with the reason. */
export function Databases() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="database"
      label="Databases"
      createOperationId="PUT /v2/database"
      meta={(item) => `${String(item.object.Directory ?? "")} · ${String(item.object.Status ?? "")}`}
      actions={(detail) => (
        <>
          <Errors error={error} />
          <ActionBar capabilities={detail.availableMutations} actions={[deleteAction("DELETE /v2/database", "database", detail, run)]} />
        </>
      )}
      empty={{ title: "No database matches", cause: "The filters exclude every database this instance configures.", nextAction: "Clear the filters or the search text." }}
      emptyUnfiltered={{ title: "No database", cause: "This instance configures no database.", nextAction: "Create one with New." }}
    />
  );
}

/**
 * UC08: the database directories, where the storage operations live.
 *
 * Compact, defragment and integrity check are long: they run as platform tasks and their
 * confirmation says how long they take, so a minutes-long operation never reads as a frozen
 * application (spec FR-037b).
 */
export function Directories() {
  const { run, error } = useDomainMutation();
  const act = (operationId: string, label: string, detail: EntityDetailResponse) => ({
    operationId,
    label,
    mutating: true,
    onActivate: async () => {
      await run({ operationId, keys: detail.keys, params: { dir: String(detail.keys.dir ?? "") }, noun: "database directory" });
    },
  });
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="database-dir"
      label="Directories"
      meta={(item) => `${String(item.object.Status ?? "")} · ${String(item.object.Size ?? "")} MB · max ${String(item.object.MaxSize ?? "—")}`}
      actions={(detail) => (
        <>
          <Errors error={error} />
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              act("POST /v2/database-dir/mount", "Mount", detail),
              act("POST /v2/database-dir/dismount", "Dismount", detail),
              act("POST /v2/database-dir/compact", "Compact", detail),
              act("POST /v2/database-dir/defragment", "Defragment", detail),
              act("POST /v2/database-dir/integrity-check", "Integrity check", detail),
              act("POST /v2/database-dir/truncate", "Truncate", detail),
              deleteAction("DELETE /v2/database-dir", "database directory", detail, run),
            ]}
          />
        </>
      )}
      empty={{ title: "No directory matches", cause: "The filters exclude every database directory on this instance.", nextAction: "Clear the filters or the search text." }}
      emptyUnfiltered={{ title: "No database directory", cause: "This instance reports no database directory.", nextAction: "A directory appears here once a database uses it." }}
    />
  );
}

/** UC08: namespaces and their mappings. Creation is performed; deletion is declined with its reason. */
export function Namespaces() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="namespace"
      label="Namespaces"
      createOperationId="PUT /v2/namespace"
      meta={(item) => `globals ${String(item.object.Globals ?? "—")} · routines ${String(item.object.Routines ?? "—")}`}
      actions={(detail) => (
        <>
          <Errors error={error} />
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              {
                operationId: "POST /v2/namespace/enable-interop",
                label: "Enable interoperability",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "POST /v2/namespace/enable-interop", keys: detail.keys, params: { name: String(detail.keys.name ?? "") }, noun: "namespace" });
                },
              },
              deleteAction("DELETE /v2/namespace", "namespace", detail, run),
            ]}
          />
        </>
      )}
      empty={{ title: "No namespace matches", cause: "The filters exclude every namespace on this instance.", nextAction: "Clear the filters or the search text." }}
      emptyUnfiltered={{ title: "No namespace", cause: "This instance defines no namespace.", nextAction: "Create one with New." }}
    />
  );
}

export function Devices() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="device"
      label="Devices"
      createOperationId="PUT /v2/device"
      meta={(item) => `${String(item.object.Type ?? "")} · ${String(item.object.PhysicalDevice ?? "")}`}
      actions={(detail) => (
        <>
          <Errors error={error} />
          <ActionBar capabilities={detail.availableMutations} actions={[deleteAction("DELETE /v2/device", "device", detail, run)]} />
        </>
      )}
      empty={{ title: "No device matches", cause: "The filters exclude every device this instance defines.", nextAction: "Clear the filters or the search text." }}
      emptyUnfiltered={{ title: "No device", cause: "This instance defines no device.", nextAction: "Create one with New." }}
    />
  );
}

export function License() {
  const { run, error } = useDomainMutation();
  return (
    <SingletonSection
      entity={{ domain: DOMAIN, entityType: "license-key", keys: {} }}
      label="License key"
      actions={(detail) => (
        <>
          <Errors error={error} />
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              {
                operationId: "POST /v2/license/key/validate",
                label: "Validate a key file",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "POST /v2/license/key/validate", keys: {}, params: { path: "/usr/irissys/mgr/iris.key" }, noun: "license key" });
                },
              },
            ]}
          />
        </>
      )}
    />
  );
}

/** UC08: the locks the instance holds. Removable is the lock's own capability field (RN-FD-34). */
export function Locks() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="lock"
      label="Locks"
      meta={(item) => `${String(item.object.Reference ?? "")} · pid ${String(item.object.Pid ?? "")} · ${String(item.object.ModeCount ?? "")}`}
      actions={(detail) => (
        <>
          <Errors error={error} />
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              {
                operationId: "DELETE /v2/lock",
                label: "Remove",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/lock", keys: detail.keys, params: { id: String(detail.keys.id ?? "") }, noun: "lock" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No lock matches", cause: "The instance holds no lock that matches.", nextAction: "Clear the filters or the search text." }}
    />
  );
}

export function WebSessions() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="web-session"
      label="Web sessions"
      meta={(item) => `${String(item.object.UserName ?? "")} · ${String(item.object.Application ?? "")}`}
      actions={(detail) => (
        <>
          <Errors error={error} />
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              {
                operationId: "DELETE /v2/web-session",
                label: "End session",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/web-session", keys: detail.keys, params: { id: String(detail.keys.id ?? "") }, noun: "web session" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No web session", cause: "This instance is holding no web session right now.", nextAction: "Sessions appear here while users are signed in to its applications." }}
    />
  );
}

export function Ecp() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="ecp-data-server"
      label="ECP data servers"
      createOperationId="PUT /v2/ecp/data-server"
      meta={(item) => `${String(item.object.Address ?? "")} · ${String(item.object.Status ?? "")}`}
      actions={(detail) => (
        <>
          <Errors error={error} />
          <ActionBar capabilities={detail.availableMutations} actions={[deleteAction("DELETE /v2/ecp/data-server", "ECP data server", detail, run)]} />
        </>
      )}
      empty={{ title: "No ECP data server", cause: "This instance configures no ECP data server.", nextAction: "Add one, or clear the filters." }}
    />
  );
}

export function LanguageServers() {
  const { run, error } = useDomainMutation();
  const act = (operationId: string, label: string, detail: EntityDetailResponse) => ({
    operationId,
    label,
    mutating: true,
    onActivate: async () => {
      await run({ operationId, keys: detail.keys, params: { name: String(detail.keys.name ?? "") }, noun: "language server" });
    },
  });
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="ext-lang-server"
      label="External language servers"
      createOperationId="PUT /v2/ext-lang-server"
      meta={(item) => `${String(item.object.Type ?? "")} · port ${String(item.object.Port ?? "")}`}
      actions={(detail) => (
        <>
          <Errors error={error} />
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              act("POST /v2/ext-lang-server/start", "Start", detail),
              act("POST /v2/ext-lang-server/stop", "Stop", detail),
              deleteAction("DELETE /v2/ext-lang-server", "language server", detail, run),
            ]}
          />
        </>
      )}
      empty={{ title: "No language server matches", cause: "The filters exclude every external language server on this instance.", nextAction: "Clear the filters or the search text." }}
      emptyUnfiltered={{ title: "No external language server", cause: "This instance defines no external language server.", nextAction: "Create one with New." }}
    />
  );
}

export function DocDb() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="doc-db"
      label="DocDB applications"
      createOperationId="PUT /v2/doc-db"
      meta={(item) => String(item.object.Namespace ?? "")}
      actions={(detail) => (
        <>
          <Errors error={error} />
          <ActionBar capabilities={detail.availableMutations} actions={[deleteAction("DELETE /v2/doc-db", "DocDB application", detail, run)]} />
        </>
      )}
      empty={{ title: "No DocDB application", cause: "This instance defines no DocDB application.", nextAction: "Add one, or clear the filters." }}
    />
  );
}

export function FileAccess() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain={DOMAIN}
      entityType="fs-access-purpose"
      label="File access purposes"
      createOperationId="PUT /v2/fs-access-purpose"
      meta={(item) => String(item.object.Description ?? "")}
      actions={(detail) => (
        <>
          <Errors error={error} />
          <ActionBar capabilities={detail.availableMutations} actions={[deleteAction("DELETE /v2/fs-access-purpose", "file access purpose", detail, run)]} />
        </>
      )}
      empty={{ title: "No file access purpose", cause: "This instance defines no file-system access purpose.", nextAction: "Add one, or clear the filters." }}
    />
  );
}
