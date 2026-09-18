import { useMemo, useState, type ReactNode } from "react";
import type { EntityDetailResponse, EntityListItem } from "../api/types";
import { useCapability } from "../session/SessionProvider";
import { DomainList, type FilterDef } from "./DomainList";
import { EntityInspector } from "./EntityInspector";
import { ListInspector } from "./ListInspector";
import { useAddressFilters, useEntityList, useInspectTarget } from "./useEntityType";
import "./pattern.css";

/** What the inspector shows instead of the entity: a create, an edit, or another form.
 * A mode other than "create" always carries the entity it acts on. */
export type FormState =
  | { mode: "create"; detail?: undefined }
  | { mode: "edit" | "password"; detail: EntityDetailResponse }
  /** Any other declared action of the entity, named by the section that opens it (feature 004). */
  | { mode: "action"; detail: EntityDetailResponse; action: string }
  | null;

const FILTER_IDS = ["q", "state"] as const;

export interface DomainSectionProps {
  /** The descriptor domain: "permissions", "security", and every later one. */
  domain: string;
  entityType: string;
  label: string;
  /** Extra filters beyond search and state, and the predicate that applies them. */
  filters?: FilterDef[];
  matches?: (item: EntityListItem, values: Record<string, string>) => boolean;
  meta?: (item: EntityListItem) => ReactNode;
  /** The operation that creates one, when the official API offers creation at all. */
  createOperationId?: string;
  createLabel?: string;
  /** The form shown in place of the inspector, for whichever mode the actions opened. */
  renderForm?: (form: NonNullable<FormState>, done: (keys?: Record<string, string>) => void) => ReactNode;
  actions?: (detail: EntityDetailResponse, openForm: (form: NonNullable<FormState>) => void) => ReactNode;
  /** One extra panel in the inspector, beside the links (feature 004: a task's recent runs). */
  inspectorExtra?: (detail: EntityDetailResponse) => ReactNode;
  empty: { title: string; cause: string; nextAction: string };
  /** State filter options; omitted when the entity has no enabled/disabled notion. */
  stateFilter?: { label: string; options: { value: string; label: string }[]; matches: (item: EntityListItem, value: string) => boolean };
}

/**
 * One domain section on the shared pattern: list, filters in the address, inspector with the
 * entity's links and, when the domain provides them, its actions. Nothing here knows which domain
 * it is rendering (contracts/ui-pattern.md; feature 003 made it shared by two).
 */
export function DomainSection(props: DomainSectionProps) {
  const DOMAIN = props.domain;
  const list = useEntityList(DOMAIN, props.entityType);
  const [filters, setFilter] = useAddressFilters(FILTER_IDS);
  const { target, open, close } = useInspectTarget();
  const [form, setForm] = useState<FormState>(null);
  const create = useCapability(props.createOperationId ?? "");
  const items = useMemo(() => list.data?.items ?? [], [list.data]);
  const visible = items.filter((item) => {
    if (filters.q && !item.displayName.toLowerCase().includes(filters.q.toLowerCase())) return false;
    if (filters.state && props.stateFilter && !props.stateFilter.matches(item, filters.state)) return false;
    if (props.matches && !props.matches(item, filters)) return false;
    return true;
  });
  const selected = target && target.domain === DOMAIN && target.entityType === props.entityType ? (items.find((i) => JSON.stringify(i.keys) === JSON.stringify(target.keys))?.displayName ?? null) : null;
  const filterDefs: FilterDef[] = [...(props.stateFilter ? [{ id: "state", label: props.stateFilter.label, options: props.stateFilter.options }] : []), ...(props.filters ?? [])];
  return (
    <ListInspector
      onClose={() => {
        setForm(null);
        close();
      }}
      inspectorLabel={`${props.label} details`}
      list={
        <DomainList
          label={props.label}
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
          onSelect={(item) => open({ domain: DOMAIN, entityType: props.entityType, keys: item.keys })}
          meta={props.meta}
          toolbar={
            props.createOperationId ? (
              <button
                className="btn"
                type="button"
                aria-disabled={create && (!create.available || !create.allowed) ? "true" : undefined}
                title={create && (!create.available || !create.allowed) ? (create.reason ?? undefined) : undefined}
                onClick={() => create?.available && create.allowed && setForm({ mode: "create" })}
                data-testid={`action-new-${props.entityType}`}
              >
                {props.createLabel ?? "New"}
              </button>
            ) : undefined
          }
          empty={props.empty}
        />
      }
      inspector={
        form && props.renderForm ? (
          props.renderForm(form, (keys) => {
            setForm(null);
            if (keys) open({ domain: DOMAIN, entityType: props.entityType, keys });
          })
        ) : target ? (
          <EntityInspector
            key={JSON.stringify(target)}
            entity={target}
            extra={props.inspectorExtra}
            actions={props.actions ? (detail) => props.actions!(detail, setForm) : undefined}
          />
        ) : null
      }
    />
  );
}
