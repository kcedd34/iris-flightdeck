import { useEffect, useId, useState } from "react";
import { useSearchParams } from "react-router-dom";
import type { LinkGroup, LinkItem } from "../api/types";
import { useEntityLinks, type EntityRef } from "./useEntityType";

const VISIBLE = 8;

/**
 * Entity links (RN-FD-13): incoming and outgoing groups composed by the server from official reads.
 * Every item opens in the inspector in one click; refused or undetermined groups state why.
 */
export function LinksPanel({ entity, onOpen }: { entity: EntityRef; onOpen: (item: LinkItem) => void }) {
  // Parameters a provider declares (a namespace, for example) live here, one value per provider,
  // so a panel can answer without the rest of the inspector reloading.
  const [parameters, setParameters] = useState<Record<string, Record<string, string>>>({});
  // "?panel=<provider>" opens that group ready to answer: the palette uses it to reach a family by
  // name (feature 003 FR-006a). Its first known value is chosen, so the panel is not an empty form.
  const [address] = useSearchParams();
  const requested = address.get("panel");
  const links = useEntityLinks(entity);
  if (links.data && links.data.groups.length === 0) return null;
  return (
    <section className="sect" aria-label="Links" data-testid="links-panel">
      <div className="sect-h">Connected to</div>
      {links.isPending && <div className="field skeleton" aria-busy="true" />}
      {links.error && (
        <div className="dlist-error" role="alert">
          {links.error.message}
        </div>
      )}
      {links.data?.groups.map((group) => (
        <Group
          key={group.provider}
          group={group}
          requested={requested === group.provider}
          entity={entity}
          values={parameters[group.provider] ?? {}}
          onParameter={(name, value) => setParameters((current) => ({ ...current, [group.provider]: { ...current[group.provider], [name]: value } }))}
          onOpen={onOpen}
        />
      ))}
    </section>
  );
}

interface GroupProps {
  group: LinkGroup;
  /** The address asked for this group by name: choose its first known value and mark it. */
  requested: boolean;
  entity: EntityRef;
  values: Record<string, string>;
  onParameter: (name: string, value: string) => void;
  onOpen: (item: LinkItem) => void;
}

function Group({ group, requested, entity, values, onParameter, onOpen }: GroupProps) {
  const [expanded, setExpanded] = useState(false);
  const first = group.parameters?.[0];
  useEffect(() => {
    if (requested && first && !values[first.name] && first.values.length > 0) onParameter(first.name, first.values[0]!);
    // Only when the address asks for this group, and only while it has no value yet.
  }, [requested, first, values, onParameter]);
  const parameterised = (group.parameters ?? []).length > 0;
  const missing = (group.parameters ?? []).some((p) => p.required && !values[p.name]);
  // A parameterised group answers on its own, once it has a value, without reloading the inspector.
  const answered = useEntityLinks(parameterised && !missing ? entity : null, { provider: group.provider, params: values });
  const shownGroup = parameterised ? (answered.data?.groups.find((g) => g.provider === group.provider) ?? group) : group;
  const items = shownGroup.items;
  const shown = expanded ? items : items.slice(0, VISIBLE);
  return (
    <div className="lgroup" data-testid={`links-group-${group.provider}`} data-state={shownGroup.state} data-requested={requested ? "true" : undefined}>
      <div className="lgroup-h">
        {shownGroup.count !== null && shownGroup.state === "ok" && <span className="c num">{shownGroup.count}</span>}
        <span>{shownGroup.label}</span>
      </div>
      {(group.parameters ?? []).map((parameter) => (
        <Parameter key={parameter.name} provider={group.provider} parameter={parameter} value={values[parameter.name] ?? ""} onChange={(v) => onParameter(parameter.name, v)} />
      ))}
      {/* A reason is shown whenever the server sent one: a refusal, a parameter to choose, or a note
          about what this answer does not cover (an account whose roles may come from LDAP). */}
      {shownGroup.reason && <div className="lgroup-reason">{shownGroup.reason}</div>}
      {shownGroup.truncated && <div className="lgroup-reason">Part of this answer was not expanded; what was left out is named above.</div>}
      {/* Keyed by position: the same entity legitimately appears twice in one group with different
          details (the same vault reached through two grants), and a key built from the name alone
          made React drop one of them. The order is the server's and the rows hold no state. */}
      {shown.map((item, index) => (
        <button key={`${index}:${item.entityType}:${item.displayName}`} type="button" className="link" onClick={() => onOpen(item)}>
          <span className="mono">{item.displayName}</span>
          {item.detail && <span className="link-detail">{item.detail}</span>}
        </button>
      ))}
      {items.length > VISIBLE && (
        <button type="button" className="link link-more" onClick={() => setExpanded((v) => !v)}>
          {expanded ? "Show fewer" : `${items.length - VISIBLE} more`}
        </button>
      )}
    </div>
  );
}

/** One control for a parameter the provider declared: a choice when the session may list values. */
function Parameter({ provider, parameter, value, onChange }: { provider: string; parameter: { name: string; values: string[] }; value: string; onChange: (value: string) => void }) {
  const id = useId();
  return (
    <div className="field lgroup-param">
      <label className="field-k" htmlFor={id}>
        {parameter.name}
      </label>
      <span className="field-v">
        {parameter.values.length > 0 ? (
          <select id={id} value={value} onChange={(e) => onChange(e.target.value)} data-testid={`links-group-${provider}-parameter-${parameter.name}`}>
            <option value="">Choose…</option>
            {parameter.values.map((option) => (
              <option key={option} value={option}>
                {option}
              </option>
            ))}
          </select>
        ) : (
          <input id={id} type="text" value={value} onChange={(e) => onChange(e.target.value)} data-testid={`links-group-${provider}-parameter-${parameter.name}`} />
        )}
      </span>
    </div>
  );
}
