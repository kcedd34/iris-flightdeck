import { useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { request } from "../api/client";
import type { EntityDetailResponse } from "../api/types";
import type { SchemaField } from "../domains/generated/schemas";
import { useMutation } from "../mutation/useMutation";
import { ActionBar } from "../pattern/ActionBar";
import { DomainList } from "../pattern/DomainList";
import { EntityInspector } from "../pattern/EntityInspector";
import { ListInspector } from "../pattern/ListInspector";
import { changedFields, ObjectForm, SecretEditor } from "../pattern/ObjectForm";
import { useDomainMutation } from "../pattern/useDomainMutation";
import { useAddressFilters, useEntityList, useInspectTarget } from "../pattern/useEntityType";
import { WorkHeader } from "../shell/WorkHeader";
import "../pattern/pattern.css";

// Pattern catalog fixture (feature 002 User Story 4, research R13). Compiled only in fixtures mode.
// It composes the shipped pattern modules on the backend's synthetic catalog entities, which go
// through the real Entities and Mutations services. Nothing here renders a dialog or a diff.

const DOMAIN = "fixtures";
const TYPE = "catalog-item";
const FILTER_IDS = ["q"] as const;
const FIELDS: readonly SchemaField[] = [
  { name: "Description", type: "string", description: "Free text." },
  { name: "Enabled", type: "boolean", description: "Disabling asks for the name." },
  { name: "Secret", type: "string", description: "Secret material: never displayed." },
];

export default function PatternCatalog() {
  const list = useEntityList(DOMAIN, TYPE);
  const [filters, setFilter] = useAddressFilters(FILTER_IDS);
  const { target, open, close } = useInspectTarget();
  const [editing, setEditing] = useState<EntityDetailResponse | null>(null);
  const { run, error } = useDomainMutation();
  const { openTrail } = useMutation();
  const queryClient = useQueryClient();
  const items = useMemo(() => list.data?.items ?? [], [list.data]);
  const visible = items.filter((i) => !filters.q || i.displayName.includes(filters.q));
  const selected = target ? (items.find((i) => JSON.stringify(i.keys) === JSON.stringify(target.keys))?.displayName ?? null) : null;
  const serverSide = async (query: Record<string, string>) => {
    await request(`/domains/${DOMAIN}/${TYPE}`, { query });
    await queryClient.invalidateQueries();
  };
  return (
    <>
      <WorkHeader title="Pattern catalog" />
      <ListInspector
        onClose={() => {
          setEditing(null);
          close();
        }}
        inspectorLabel="Catalog item details"
        list={
          <DomainList
            label="Catalog items"
            items={visible}
            total={list.data?.total ?? 0}
            capped={false}
            loading={list.isPending}
            error={list.error ? list.error.message : null}
            search={filters.q}
            onSearch={(v) => setFilter("q", v)}
            filters={[]}
            filterValues={filters}
            onFilter={() => undefined}
            selected={selected}
            onSelect={(item) => open({ domain: DOMAIN, entityType: TYPE, keys: item.keys })}
            toolbar={
              <>
                <button className="btn" type="button" onClick={() => void serverSide({ reset: "all" })} data-testid="catalog-reset">
                  Reset catalog
                </button>
                <button className="btn" type="button" onClick={openTrail} data-testid="catalog-open-trail">
                  Session trail
                </button>
              </>
            }
            empty={{ title: "No catalog item", cause: "Every catalog item was deleted.", nextAction: "Reset the catalog." }}
          />
        }
        inspector={
          editing ? (
            <ObjectForm
              key={editing.displayName}
              title={`Edit ${editing.displayName}`}
              fields={FIELDS}
              sections={[{ title: "Catalog item", fields: ["Description", "Enabled", "Secret"] }]}
              initial={{ Description: editing.object.Description, Enabled: editing.object.Enabled }}
              editors={{ Secret: SecretEditor }}
              submitLabel="Review changes"
              error={error}
              busy={false}
              onCancel={() => setEditing(null)}
              onSubmit={async (values) => {
                const proposed = changedFields({ Description: editing.object.Description, Enabled: editing.object.Enabled }, values);
                if (values.Secret !== undefined) proposed.Secret = values.Secret;
                const outcome = await run({ operationId: "PUT /fixture/catalog-item", keys: editing.keys, proposed, noun: "catalog item" });
                if (outcome.status === "applied") setEditing(null);
              }}
            />
          ) : target ? (
            <EntityInspector
              key={JSON.stringify(target)}
              entity={target}
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
                      { operationId: "PUT /fixture/catalog-item", label: "Edit", mutating: true, onActivate: () => setEditing(detail) },
                      {
                        operationId: "POST /fixture/catalog-tag/grant",
                        label: "Add a tag",
                        mutating: true,
                        onActivate: async () => {
                          await run({ operationId: "POST /fixture/catalog-tag/grant", params: { name: detail.keys.name!, tag: "reviewed-again" }, noun: "catalog tag" });
                        },
                      },
                      {
                        operationId: "POST /fixture/catalog-tag/revoke",
                        label: "Remove a tag",
                        mutating: true,
                        onActivate: async () => {
                          await run({ operationId: "POST /fixture/catalog-tag/revoke", params: { name: detail.keys.name!, tag: "reviewed" }, noun: "catalog tag" });
                        },
                      },
                      {
                        operationId: "DELETE /fixture/catalog-item",
                        label: "Delete",
                        mutating: true,
                        onActivate: async () => {
                          const outcome = await run({ operationId: "DELETE /fixture/catalog-item", keys: detail.keys, noun: "catalog item" });
                          if (outcome.status === "applied") close();
                        },
                      },
                    ]}
                  />
                  <button className="btn" type="button" onClick={() => void serverSide({ drift: detail.keys.name! })} data-testid="catalog-drift">
                    Change it on the server
                  </button>
                </>
              )}
            />
          ) : null
        }
      />
    </>
  );
}
