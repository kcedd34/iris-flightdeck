import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { request } from "../api/client";
import type { AttentionResponse } from "../api/types";
import { MarkerTag } from "../pattern/MarkerTag";
import { encodeInspect } from "../pattern/useEntityType";
import { useSession, useUnavailableOperations } from "../session/SessionProvider";
import { DOMAINS } from "../shell/domains";
import { EmptyState } from "../shell/EmptyState";
import { Icon } from "../shell/Icon";
import "./home.css";

function productLabel(product: string): string {
  return product === "irisforhealth" ? "IRIS for Health" : product === "iris" ? "IRIS" : product;
}

/** The initial dashboard of UC01 (FR-036). */
/**
 * What needs attention (RN-FD-15): today, credentials whose certificate is expiring or expired.
 * The list carries only what this session may read, and says so when a source was refused or a read
 * cap was reached — an empty list means nothing is wrong, never "could not tell".
 */
function AttentionItems() {
  const attention = useQuery({
    queryKey: ["attention"],
    queryFn: ({ signal }) => request<AttentionResponse>("/attention", { signal }),
  });
  const items = attention.data?.items ?? [];
  return (
    <section className="home-attention" aria-label="Attention items" data-testid="home-attention">
      <div className="sect-h">Attention items</div>
      {attention.isPending && <div className="field skeleton" aria-busy="true" />}
      {attention.error && (
        <div className="dlist-error" role="alert">
          {attention.error.message}
        </div>
      )}
      {attention.data?.degraded && attention.data.reason && <div className="lgroup-reason">{attention.data.reason}</div>}
      {attention.data && items.length === 0 && (
        <EmptyState
          title="Nothing needs attention"
          cause="No credential this session can read is expiring or expired."
          nextAction="Items appear here as certificates approach their validity date."
        />
      )}
      {items.map((item) => (
        <Link
          key={`${item.kind}:${item.label}`}
          className="home-attention-item"
          to={`/${item.target.domain}/${SECTION_OF[item.target.entityType] ?? ""}?inspect=${encodeURIComponent(encodeInspect({ domain: item.target.domain, entityType: item.target.entityType, keys: item.target.keys }))}`}
          data-testid={`attention-${item.band}`}
        >
          <MarkerTag marker={{ id: item.kind, text: item.label, tone: item.band === "expired" ? "warning" : "caution" }} />
        </Link>
      ))}
    </section>
  );
}

/** Where an attention item opens. Entity types are unique across domains. */
const SECTION_OF: Record<string, string> = { "x509-credential": "x509" };

export function Home() {
  const { session, capabilities } = useSession();
  const { unavailable } = useUnavailableOperations();
  if (!session) return null;
  const counts = DOMAINS.map((d) => {
    const ops = capabilities.filter((c) => c.domain === d.id);
    return { domain: d, allowed: ops.filter((c) => c.available && c.allowed).length, total: ops.length };
  });
  return (
    <div className="home">
      <section className="home-identity">
        <div className="field">
          <span className="field-k">Instance</span>
          <span className="field-v">
            {productLabel(session.instance.product)} {session.instance.version}
            {session.instance.edition === "Community" ? " Community" : ""}
          </span>
        </div>
        <div className="field">
          <span className="field-k">Namespace</span>
          <span className="field-v mono">{session.instance.namespace}</span>
        </div>
        <div className="field">
          <span className="field-k">Signed in</span>
          <span className="field-v mono">{session.username}</span>
        </div>
        <div className="field">
          <span className="field-k">Access</span>
          <span className="field-v num" data-testid="capability-summary">
            {session.capabilitySummary.allowed} of {session.capabilitySummary.total} operations available to you
            {unavailable > 0 ? ` · ${unavailable} not offered by this IRIS version` : ""}
          </span>
        </div>
      </section>

      <section className="home-domains" aria-label="Domains">
        {counts.map(({ domain, allowed, total }) => (
          <Link key={domain.id} className="home-domain" to={`/${domain.id}`}>
            <Icon paths={domain.icon} />
            <span className="home-domain-name">{domain.label}</span>
            <span className="home-domain-count num">
              {allowed} of {total}
            </span>
          </Link>
        ))}
      </section>

      <AttentionItems />
    </div>
  );
}
