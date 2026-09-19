import { useMemo, useState } from "react";
import type { EntityDetailResponse } from "../../api/types";
import { ActionBar } from "../../pattern/ActionBar";
import { useCapability } from "../../session/SessionProvider";
import { PctAccessForm } from "./PctAccessForm";
import { useDomainMutation } from "../../pattern/useDomainMutation";
import { DomainList, type FilterDef } from "../../pattern/DomainList";
import { EntityInspector } from "../../pattern/EntityInspector";
import { ListInspector } from "../../pattern/ListInspector";
import { useAddressFilters, useEntityList, useInspectTarget } from "../../pattern/useEntityType";
import "../../pattern/pattern.css";

const DOMAIN = "web-apps";
const TYPE = "pct-access";
const FILTER_IDS = ["q", "app", "allowType"] as const;

type FormState = { mode: "create" } | { mode: "edit"; detail: EntityDetailResponse } | null;

/** UC03 percent class access configurations, globally and per application. */
export function PercentClassAccess() {
  const list = useEntityList(DOMAIN, TYPE);
  const [filters, setFilter] = useAddressFilters(FILTER_IDS);
  const { target, open, close } = useInspectTarget();
  const [form, setForm] = useState<FormState>(null);
  const { run, error } = useDomainMutation();
  const put = useCapability("PUT /v2/web-app/pct-access");
  const items = useMemo(() => list.data?.items ?? [], [list.data]);
  const applications = useMemo(() => [...new Set(items.map((i) => String(i.object.Name ?? "")))].sort(), [items]);
  const filterDefs: FilterDef[] = [
    { id: "app", label: "Application", options: [{ value: "", label: "All applications" }, ...applications.map((a) => ({ value: a, label: a }))] },
    { id: "allowType", label: "Allow type", options: [{ value: "", label: "Classes and packages" }, { value: "AllowClass", label: "Classes" }, { value: "AllowPackage", label: "Packages" }] },
  ];
  const visible = items.filter(
    (item) =>
      (!filters.q || item.displayName.toLowerCase().includes(filters.q.toLowerCase())) &&
      (!filters.app || item.object.Name === filters.app) &&
      (!filters.allowType || item.object.AllowType === filters.allowType),
  );
  const selected = target && target.domain === DOMAIN && target.entityType === TYPE ? list.data?.items.find((i) => JSON.stringify(i.keys) === JSON.stringify(target.keys))?.displayName ?? null : null;
  return (
    <ListInspector
      onClose={() => {
        setForm(null);
        close();
      }}
      inspectorLabel="Percent class access details"
      list={
        <DomainList
          label="Percent class access"
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
          meta={(item) => (item.object.AllowAccess ? "Allowed" : "Denied")}
          toolbar={
            <button
              className="btn"
              type="button"
              aria-disabled={put && (!put.available || !put.allowed) ? "true" : undefined}
              title={put && (!put.available || !put.allowed) ? (put.reason ?? undefined) : undefined}
              onClick={() => put?.available && put.allowed && setForm({ mode: "create" })}
              data-testid="action-new-pct-access"
            >
              New
            </button>
          }
          empty={{
            title: "No percent class access configuration matches",
            cause: "The filters exclude every configuration on this instance.",
            nextAction: "Clear the filters or the search text.",
          }}
          emptyUnfiltered={{
            title: "No percent class access configuration",
            cause: "This instance grants no web application access to a percent class.",
            nextAction: "Create one with New.",
          }}
        />
      }
      inspector={
        form ? (
          <PctAccessForm
            key={form.mode === "edit" ? form.detail.displayName : "create"}
            mode={form.mode}
            keys={form.mode === "edit" ? form.detail.keys : undefined}
            original={form.mode === "edit" ? { Name: form.detail.keys.name, AllowType: form.detail.keys.allowType, Class: form.detail.keys.class, AllowAccess: form.detail.object.AllowAccess } : { AllowType: "AllowClass", AllowAccess: true }}
            onDone={(keys) => {
              setForm(null);
              if (keys) open({ domain: DOMAIN, entityType: TYPE, keys });
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
                      { operationId: "PUT /v2/web-app/pct-access", label: "Edit", mutating: true, onActivate: () => setForm({ mode: "edit", detail }) },
                      {
                        operationId: "DELETE /v2/web-app/pct-access",
                        label: "Delete",
                        mutating: true,
                        onActivate: async () => {
                          const outcome = await run({ operationId: "DELETE /v2/web-app/pct-access", keys: detail.keys, noun: "percent class access" });
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
