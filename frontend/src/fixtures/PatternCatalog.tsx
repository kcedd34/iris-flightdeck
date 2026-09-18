import { useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { request } from "../api/client";
import type { EntityDetailResponse, LogEvent } from "../api/types";
import type { SchemaField } from "../domains/generated/schemas";
import { EventInspector } from "../domains/logs/EventInspector";
import { useMutation } from "../mutation/useMutation";
import { ActionBar } from "../pattern/ActionBar";
import { DomainList } from "../pattern/DomainList";
import { EntityInspector } from "../pattern/EntityInspector";
import { ListInspector } from "../pattern/ListInspector";
import { changedFields, ObjectForm, SecretEditor } from "../pattern/ObjectForm";
import { useDomainMutation } from "../pattern/useDomainMutation";
import { useAddressFilters, useEntityList, useInspectTarget } from "../pattern/useEntityType";
import { Cluster } from "../pattern/instruments/Cluster";
import type { InstrumentReading } from "../pattern/instruments/Instrument";
import { WorkHeader } from "../shell/WorkHeader";
import "../pattern/pattern.css";
import "../pattern/instruments/instruments.css";
import "../domains/logs/logs.css";

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

/**
 * The two pattern additions of feature 004, exercised on states a live instance cannot be made to
 * produce on demand: an instrument that crosses a threshold, one the instance does not offer, and an
 * asynchronous value moving through running, stale and failed.
 *
 * The catalog exists for exactly this (feature 002 research R13): behaviour the shipped domains
 * cannot force is proven here, not on a one-off screen.
 */
function InstrumentCases() {
  const [step, setStep] = useState(0);
  const cases: InstrumentReading[][] = [
    [
      { id: "normal", label: "Normal", unit: "%", value: 34, band: "normal", available: true, detail: "below every threshold" },
      { id: "caution", label: "Caution", unit: "%", value: 82, band: "caution", available: true, detail: "crossed the caution threshold" },
      { id: "warning", label: "Warning", unit: "%", value: 96, band: "warning", available: true, detail: "crossed the warning threshold" },
      { id: "absent", label: "Unavailable", unit: "%", value: null, band: "normal", available: false, reason: "Not available on this IRIS version or edition. Requires IRIS 2026.2." },
      {
        id: "async",
        label: "Async",
        unit: "%",
        value: 72,
        band: "normal",
        available: true,
        detail: "IRISAPP 72%",
        async: { state: "Running", lastValueAt: "2026-09-18 02:00:00", stale: true, message: null },
      },
    ],
    [
      { id: "normal", label: "Normal", unit: "%", value: 36, band: "normal", available: true, detail: "below every threshold" },
      { id: "caution", label: "Caution", unit: "%", value: 84, band: "caution", available: true, detail: "crossed the caution threshold" },
      { id: "warning", label: "Warning", unit: "%", value: 94, band: "warning", available: true, detail: "crossed the warning threshold" },
      { id: "absent", label: "Unavailable", unit: "%", value: null, band: "normal", available: false, reason: "Not available on this IRIS version or edition. Requires IRIS 2026.2." },
      {
        id: "async",
        label: "Async",
        unit: "%",
        // The value the platform last gave, kept while the refresh failed: the number stays, and the
        // platform's message sits beside it (RN-FD-32, spec FR-023, FR-025).
        value: 72,
        band: "normal",
        available: true,
        detail: "IRISAPP 72%",
        async: { state: "Failed", lastValueAt: "2026-09-18 02:00:00", stale: true, message: "The instance cancelled the task that reads database metrics." },
      },
    ],
  ];
  return (
    <section data-testid="catalog-instruments">
      <Cluster readings={cases[step % cases.length]!} mode="polling" intervalSeconds={1} onIntervalChange={() => undefined} windowSeconds={60} paused={false} />
      <button className="btn" type="button" onClick={() => setStep((value) => value + 1)} data-testid="catalog-instrument-step">
        Next asynchronous state
      </button>
    </section>
  );
}

/**
 * The two honest-gap states of feature 005, on events a live instance cannot be made to produce on
 * demand: an event whose original record is gone, and a line that did not parse.
 *
 * Both are the same rule from two directions — normalisation never destroys information, and where
 * the original cannot be recovered the gap is stated rather than filled (spec FR-005, FR-006).
 */
function LogCases() {
  const [shown, setShown] = useState<"gone" | "unparsed" | null>(null);
  const base = {
    source: "messages" as const,
    severity: "unknown" as const,
    raw: null,
    correlate: {},
  };
  const events: Record<"gone" | "unparsed", LogEvent> = {
    gone: {
      ...base,
      id: "catalog-raw-gone",
      timestamp: "2026-09-18T02:00:00Z",
      message: "Journal record 12345 referenced by this event",
      rawAvailable: false,
      rawReason: "The instance no longer holds this journal record: the file may have been purged.",
      parsed: true,
      process: "4812",
    },
    unparsed: {
      ...base,
      id: "catalog-unparsed",
      timestamp: "2026-09-18T02:00:01Z",
      message: "*** a line this source does not usually write ***",
      raw: "*** a line this source does not usually write ***",
      rawAvailable: true,
      rawReason: null,
      parsed: false,
    },
  };
  return (
    <section data-testid="catalog-log-cases">
      <button className="btn" type="button" onClick={() => setShown("gone")} data-testid="catalog-log-gone">
        Event whose original record is gone
      </button>
      <button className="btn" type="button" onClick={() => setShown("unparsed")} data-testid="catalog-log-unparsed">
        Line that did not parse
      </button>
      {shown && <EventInspector event={events[shown]} onClose={() => setShown(null)} />}
    </section>
  );
}

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
      <InstrumentCases />
      <LogCases />
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
