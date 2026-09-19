import { useMemo, useState } from "react";
import type { EntityDetailResponse, EntityListItem } from "../../api/types";
import { ActionBar } from "../../pattern/ActionBar";
import { useCapability } from "../../session/SessionProvider";
import { WebApplicationForm } from "./WebApplicationForm";
import { useDomainMutation } from "../../pattern/useDomainMutation";
import { DomainList, type FilterDef } from "../../pattern/DomainList";
import { EntityInspector } from "../../pattern/EntityInspector";
import { ListInspector } from "../../pattern/ListInspector";
import { useAddressFilters, useEntityList, useInspectTarget } from "../../pattern/useEntityType";
import "../../pattern/pattern.css";

const DOMAIN = "web-apps";
const TYPE = "web-application";
const FILTER_IDS = ["q", "ns", "enabled", "rest", "auth"] as const;
const SELF_PROTECTION = "This web application serves FlightDeck. Disabling it would lock you out.";

type FormState = { mode: "create" } | { mode: "edit"; detail: EntityDetailResponse } | null;

/** UC03 web applications section: graded exposure in the list, detail and links beside it. */
export function WebApplications() {
  const list = useEntityList(DOMAIN, TYPE);
  const [filters, setFilter] = useAddressFilters(FILTER_IDS);
  const { target, open, close } = useInspectTarget();
  const [form, setForm] = useState<FormState>(null);
  const { run, error } = useDomainMutation();
  const put = useCapability("PUT /v2/web-app");
  const items = useMemo(() => list.data?.items ?? [], [list.data]);
  const namespaces = useMemo(() => [...new Set(items.map((i) => String(i.object.Namespace ?? "")))].sort(), [items]);
  const filterDefs: FilterDef[] = [
    { id: "ns", label: "Namespace", options: [{ value: "", label: "All namespaces" }, ...namespaces.map((n) => ({ value: n, label: n }))] },
    { id: "enabled", label: "State", options: [{ value: "", label: "Enabled or disabled" }, { value: "yes", label: "Enabled" }, { value: "no", label: "Disabled" }] },
    { id: "rest", label: "Type", options: [{ value: "", label: "REST or not" }, { value: "yes", label: "REST" }, { value: "no", label: "Not REST" }] },
    { id: "auth", label: "Authentication", options: [{ value: "", label: "Any authentication" }, { value: "none", label: "No authentication" }] },
  ];
  const visible = items.filter((item) => matches(item, filters));
  const selected = target && target.domain === DOMAIN && target.entityType === TYPE ? target.keys.name ?? null : null;
  return (
    <ListInspector
      onClose={() => {
        setForm(null);
        close();
      }}
      inspectorLabel="Web application details"
      list={
        <DomainList
          label="Web applications"
          items={visible}
          total={list.data?.total ?? 0}
          capped={list.data?.capped ?? false}
          loading={list.isPending}
          error={list.error ? list.error.message : null}
          search={filters.q}
          onSearch={(v) => setFilter("q", v)}
          filters={filterDefs}
          filterValues={filters}
          onFilter={(id, v) => setFilter(id as (typeof FILTER_IDS)[number], v)}
          selected={selected}
          onSelect={(item) => open({ domain: DOMAIN, entityType: TYPE, keys: item.keys })}
          meta={(item) => String(item.object.Namespace ?? "")}
          toolbar={
            <button
              className="btn"
              type="button"
              aria-disabled={put && (!put.available || !put.allowed) ? "true" : undefined}
              title={put && (!put.available || !put.allowed) ? (put.reason ?? undefined) : undefined}
              onClick={() => put?.available && put.allowed && setForm({ mode: "create" })}
              data-testid="action-new-web-application"
            >
              New
            </button>
          }
          empty={{
            title: "No web application matches",
            cause: "The filters exclude every web application on this instance.",
            nextAction: "Clear the filters or the search text.",
          }}
          emptyUnfiltered={{
            title: "No web application",
            cause: "This instance defines no web application.",
            nextAction: "Create one with New.",
          }}
        />
      }
      inspector={
        form ? (
          <WebApplicationForm
            key={form.mode === "edit" ? form.detail.displayName : "create"}
            mode={form.mode}
            name={form.mode === "edit" ? form.detail.displayName : undefined}
            original={form.mode === "edit" ? form.detail.object : { NameSpace: "USER", Enabled: true, AutheEnabled: 32 }}
            onDone={(name) => {
              setForm(null);
              if (name) open({ domain: DOMAIN, entityType: TYPE, keys: { name } });
            }}
          />
        ) : target ? (
          <EntityInspector
            key={JSON.stringify(target)}
            entity={target}
            actions={(detail) =>
              target.entityType === TYPE ? (
                <>
                  {error && (
                    <div className="dlist-error" role="alert" data-testid="action-error">
                      {error}
                    </div>
                  )}
                  <ActionBar
                    capabilities={detail.availableMutations}
                    actions={[
                      { operationId: "PUT /v2/web-app", label: "Edit", mutating: true, onActivate: () => setForm({ mode: "edit", detail }) },
                      {
                        operationId: "PUT /v2/web-app",
                        label: detail.object.Enabled ? "Disable" : "Enable",
                        mutating: true,
                        blockedMessage: detail.isFlightDeck && detail.object.Enabled ? SELF_PROTECTION : null,
                        onActivate: () => void run({ operationId: "PUT /v2/web-app", keys: detail.keys, proposed: { Enabled: !detail.object.Enabled }, noun: "web application" }),
                      },
                      {
                        operationId: "DELETE /v2/web-app",
                        label: "Delete",
                        mutating: true,
                        blockedMessage: detail.isFlightDeck ? SELF_PROTECTION : null,
                        onActivate: async () => {
                          const outcome = await run({ operationId: "DELETE /v2/web-app", keys: detail.keys, noun: "web application" });
                          if (outcome.status === "applied") close();
                        },
                      },
                    ]}
                  />
                </>
              ) : null
            }
          />
        ) : null
      }
    />
  );
}

function matches(item: EntityListItem, f: Record<(typeof FILTER_IDS)[number], string>): boolean {
  const o = item.object;
  if (f.q && !item.displayName.toLowerCase().includes(f.q.toLowerCase())) return false;
  if (f.ns && o.Namespace !== f.ns) return false;
  if (f.enabled && Boolean(o.Enabled) !== (f.enabled === "yes")) return false;
  if (f.rest && Boolean(item.facts.restDispatcher) !== (f.rest === "yes")) return false;
  if (f.auth === "none" && !item.facts.unauthenticated) return false;
  return true;
}
