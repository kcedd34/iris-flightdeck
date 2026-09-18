import type { ReactNode } from "react";
import type { EntityDetailResponse } from "../api/types";
import { sectionsFor } from "../domains/presentation";
import { Inspector } from "./Inspector";
import { LinksPanel } from "./LinksPanel";
import { useEntityItem, useInspectTarget, type EntityRef } from "./useEntityType";

/**
 * A section whose domain has one object, not a list: encryption settings, web authentication, the
 * OAuth 2.0 authorization server, auditing (contract ui-pattern-delta D3). Same inspector, same
 * action bar, no list half and no `inspect` parameter in the address.
 */
export function SingletonSection({ entity, label, actions }: { entity: EntityRef; label: string; actions?: (detail: EntityDetailResponse) => ReactNode }) {
  const item = useEntityItem(entity);
  const { open } = useInspectTarget();
  const detail = item.data;
  return (
    <div className="psingleton" data-testid="singleton-inspector">
      <Inspector
        title={detail?.displayName ?? label}
        subtitle={label}
        markers={detail?.markers}
        loading={item.isPending}
        error={item.error ? item.error.message : null}
        sections={detail ? sectionsFor(`${entity.domain}/${entity.entityType}`, detail.object) : []}
        canGoBack={false}
        onBack={() => undefined}
        onClose={() => undefined}
        afterFirst={detail && <LinksPanel entity={entity} onOpen={(link) => open({ domain: link.domain, entityType: link.entityType, keys: link.keys }, { push: true })} />}
      >
        {detail && actions?.(detail)}
      </Inspector>
    </div>
  );
}
