import type { ReactNode } from "react";
import { useNavigate } from "react-router-dom";
import type { EntityDetailResponse, LinkItem } from "../api/types";
import { sectionsFor } from "../domains/presentation";
import { Inspector } from "./Inspector";
import { LinksPanel } from "./LinksPanel";
import { encodeInspect, useEntityItem, useInspectTarget, type EntityRef } from "./useEntityType";

/** Linked entity types that are not descriptor-backed open in the section that owns them. */
const OWNING_SECTION: Record<string, string> = {
  "web-apps/rest-service": "/web-apps/rest-apis",
};

const LABELS: Record<string, string> = {
  "web-apps/web-application": "Web application",
  "web-apps/pct-access": "Percent class access",
  "permissions/role": "Role",
  "permissions/user": "User",
};

/**
 * Any descriptor-backed entity in the inspector: official fields, server markers, links and the
 * domain's actions. Linked entities from other domains open here read-only (spec FR-006).
 */
export function EntityInspector({ entity, actions }: { entity: EntityRef; actions?: (detail: EntityDetailResponse) => ReactNode }) {
  const { open, back, close, canGoBack } = useInspectTarget();
  const item = useEntityItem(entity);
  const key = `${entity.domain}/${entity.entityType}`;
  const detail = item.data;
  const title = detail?.displayName ?? Object.values(entity.keys).join(" ");
  const navigate = useNavigate();
  const onOpen = (link: LinkItem) => {
    const ref = { domain: link.domain, entityType: link.entityType, keys: link.keys };
    const section = OWNING_SECTION[`${link.domain}/${link.entityType}`];
    if (section) navigate(`${section}?${new URLSearchParams({ inspect: encodeInspect(ref) }).toString()}`);
    else open(ref, { push: true });
  };
  return (
    <Inspector
      title={title}
      subtitle={LABELS[key] ?? entity.entityType}
      markers={detail?.markers}
      loading={item.isPending}
      error={item.error ? item.error.message : null}
      sections={detail ? sectionsFor(key, detail.object) : []}
      canGoBack={canGoBack}
      onBack={back}
      onClose={close}
      afterFirst={
        detail && (
          <>
            <LinksPanel entity={entity} onOpen={onOpen} />
            {actions?.(detail)}
          </>
        )
      }
    />
  );
}
