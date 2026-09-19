import { useMemo, useState } from "react";
import type { EntityListItem, Keys, RestService } from "../../api/types";
import { DomainList, type FilterDef } from "../../pattern/DomainList";
import { Inspector } from "../../pattern/Inspector";
import { ListInspector } from "../../pattern/ListInspector";
import { useAddressFilters, useEntityItem, useInspectTarget } from "../../pattern/useEntityType";
import "../../pattern/pattern.css";
import { example, type OperationView } from "./openapi";
import { RequestBuilder, type Draft } from "./RequestBuilder";
import { SpecificationViewer } from "./SpecificationViewer";
import { useRestServices, useSpecification } from "./useRest";
import "./rest.css";

const DOMAIN = "web-apps";
const TYPE = "rest-service";
const FILTER_IDS = ["q", "ns", "spec"] as const;

/** UC04: discovered REST services, their specification, and confined test requests. */
export function Services() {
  const services = useRestServices();
  const [filters, setFilter] = useAddressFilters(FILTER_IDS);
  const { target, open, close } = useInspectTarget();
  const all = useMemo(() => services.data?.services ?? [], [services.data]);
  const items: EntityListItem[] = useMemo(
    () =>
      all.map((s) => ({
        object: s as unknown as Record<string, unknown>,
        markers: s.markers ?? [],
        keys: (s.webApplication ? { webApplication: s.webApplication } : { name: s.name }) as Keys,
        displayName: s.name,
        facts: {},
      })),
    [all],
  );
  const namespaces = [...new Set([...(services.data?.namespaces.filter((n) => n.state === "ok").map((n) => n.name) ?? []), ...all.map((s) => s.namespace)])].sort();
  const filterDefs: FilterDef[] = [
    { id: "ns", label: "Namespace", options: [{ value: "", label: "All namespaces" }, ...namespaces.map((n) => ({ value: n, label: n }))] },
    { id: "spec", label: "Specification", options: [{ value: "", label: "With or without specification" }, { value: "yes", label: "With specification" }, { value: "no", label: "Without specification" }] },
  ];
  const visible = items.filter((item) => {
    const s = item.object as unknown as RestService;
    if (filters.q && !item.displayName.toLowerCase().includes(filters.q.toLowerCase())) return false;
    if (filters.ns && s.namespace !== filters.ns) return false;
    if (filters.spec && s.hasSpecification !== (filters.spec === "yes")) return false;
    return true;
  });
  const refused = services.data?.namespaces.filter((n) => n.state !== "ok") ?? [];
  const selectedItem = target && target.entityType === TYPE ? items.find((i) => JSON.stringify(i.keys) === JSON.stringify(target.keys)) : undefined;
  const namespaceEmpty = filters.ns && visible.length === 0;
  return (
    <ListInspector
      onClose={close}
      inspectorLabel="REST service details"
      list={
        <>
          {refused.map((n) => (
            <div key={n.name} className="dlist-error" role="alert">
              {n.reason}
            </div>
          ))}
          <DomainList
            label="REST services"
            items={visible}
            total={items.length}
            capped={false}
            loading={services.isPending}
            error={services.error ? services.error.message : null}
            search={filters.q}
            onSearch={(v) => setFilter("q", v)}
            filters={filterDefs}
            filterValues={filters}
            onFilter={(id, v) => setFilter(id as (typeof FILTER_IDS)[number], v)}
            selected={selectedItem?.displayName ?? null}
            onSelect={(item) => open({ domain: DOMAIN, entityType: TYPE, keys: item.keys })}
            meta={(item) => String((item.object as unknown as RestService).namespace)}
            empty={
              namespaceEmpty
                ? {
                    title: `No REST service in ${filters.ns}`,
                    cause: `The platform reports no REST web application in namespace ${filters.ns} that you can see.`,
                    nextAction: "FlightDeck's own API, /api/flightdeck, lives in the namespace FlightDeck is installed in; choose that namespace to see a published specification.",
                  }
                : { title: "No REST service matches", cause: "The filters exclude every discovered service.", nextAction: "Clear the filters or the search text." }
            }
            emptyUnfiltered={{
              title: "No REST service",
              cause: "This instance serves no REST application you can see.",
              nextAction: "A REST application appears here once it is defined in Web applications and APIs, Web applications.",
            }}
          />
        </>
      }
      inspector={selectedItem ? <ServiceInspector key={selectedItem.displayName} service={selectedItem.object as unknown as RestService} /> : null}
    />
  );
}

function ServiceInspector({ service }: { service: RestService }) {
  const { back, close, canGoBack } = useInspectTarget();
  const specification = useSpecification(service.webApplication ? { webApplication: service.webApplication } : { name: service.name });
  const app = useEntityItem(service.webApplication ? { domain: "web-apps", entityType: "web-application", keys: { name: service.webApplication } } : null);
  const [draft, setDraft] = useState<Draft>({ method: "GET", path: service.webApplication ? `${service.webApplication}/` : "/", query: "", headers: "", body: "" });
  const [draftKey, setDraftKey] = useState(0);
  const grants = ((app.data?.object.MatchRoles as { TargetRoles: string[] }[] | undefined) ?? []).flatMap((m) => m.TargetRoles);
  const rolesNote = grants.length ? `This application grants roles to real calls (${grants.join(", ")}). Test requests run with your login roles, so the result can differ from a real call.` : null;
  const tryOperation = (op: OperationView, basePath: string) => {
    const path = `${basePath}${op.path}`;
    const query = op.parameters.filter((p) => p.in === "query").map((p) => `${p.name}=`).join("\n");
    const headers = op.parameters.filter((p) => p.in === "header").map((p) => `${p.name}: `).join("\n");
    setDraft({ method: op.method as Draft["method"], path, query, headers, body: op.requestBody ? JSON.stringify(exampleOf(op), null, 2) : "" });
    setDraftKey((k) => k + 1);
  };
  return (
    <Inspector
      title={service.webApplication || service.name}
      subtitle={service.kind === "specification-first" ? "Specification-first REST service" : "Hand-coded REST service"}
      markers={service.markers}
      sections={[
        {
          title: "Service",
          fields: [
            { label: "Namespace", value: service.namespace, mono: true },
            { label: "Dispatch class", value: service.dispatchClass, mono: true },
            { label: "Web application", value: service.webApplication || "None serves it directly", mono: Boolean(service.webApplication) },
            { label: "Specification", value: service.hasSpecification ? (service.specificationSource === "published" ? "Published by the dispatch class" : "Specification-first") : "None" },
            { label: "Enabled", value: service.enabled ? "Yes" : "No" },
          ],
        },
      ]}
      canGoBack={canGoBack}
      onBack={back}
      onClose={close}
    >
      {specification.error && (
        <div className="dlist-error" role="alert">
          {specification.error.message}
        </div>
      )}
      {specification.data && <SpecificationViewer specification={specification.data} onTry={tryOperation} />}
      {service.webApplication && <RequestBuilder key={draftKey} initial={draft} rolesNote={rolesNote} />}
    </Inspector>
  );
}

function exampleOf(op: OperationView): unknown {
  return op.requestBody ? example(op.requestBody.schema) : null;
}
