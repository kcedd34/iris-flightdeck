import { useState } from "react";
import type { LinkGroup, LinkItem } from "../api/types";
import { useEntityLinks, type EntityRef } from "./useEntityType";

const VISIBLE = 8;

/**
 * Entity links (RN-FD-13): incoming and outgoing groups composed by the server from official reads.
 * Every item opens in the inspector in one click; refused or undetermined groups state why.
 */
export function LinksPanel({ entity, onOpen }: { entity: EntityRef; onOpen: (item: LinkItem) => void }) {
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
        <Group key={group.provider} group={group} onOpen={onOpen} />
      ))}
    </section>
  );
}

function Group({ group, onOpen }: { group: LinkGroup; onOpen: (item: LinkItem) => void }) {
  const [expanded, setExpanded] = useState(false);
  const shown = expanded ? group.items : group.items.slice(0, VISIBLE);
  return (
    <div className="lgroup" data-testid={`links-group-${group.provider}`} data-state={group.state}>
      <div className="lgroup-h">
        {group.count !== null && group.state === "ok" && <span className="c num">{group.count}</span>}
        <span>{group.label}</span>
      </div>
      {group.state !== "ok" && <div className="lgroup-reason">{group.reason}</div>}
      {shown.map((item) => (
        <button key={`${item.entityType}:${item.displayName}`} type="button" className="link" onClick={() => onOpen(item)}>
          <span className="mono">{item.displayName}</span>
          {item.detail && <span className="link-detail">{item.detail}</span>}
        </button>
      ))}
      {group.items.length > VISIBLE && (
        <button type="button" className="link link-more" onClick={() => setExpanded((v) => !v)}>
          {expanded ? "Show fewer" : `${group.items.length - VISIBLE} more`}
        </button>
      )}
    </div>
  );
}
