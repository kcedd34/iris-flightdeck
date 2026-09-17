import { Link } from "react-router-dom";
import { useSession } from "../session/SessionProvider";
import { DOMAINS } from "../shell/domains";
import { EmptyState } from "../shell/EmptyState";
import { Icon } from "../shell/Icon";
import "./home.css";

function productLabel(product: string): string {
  return product === "irisforhealth" ? "IRIS for Health" : product === "iris" ? "IRIS" : product;
}

/** The initial dashboard of UC01 (FR-036). */
export function Home() {
  const { session, capabilities } = useSession();
  if (!session) return null;
  const counts = DOMAINS.map((d) => {
    const ops = capabilities.filter((c) => c.domain === d.id);
    return { domain: d, allowed: ops.filter((c) => c.allowed).length, total: ops.length };
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

      <section className="home-attention" aria-label="Attention items">
        <div className="sect-h">Attention items</div>
        <EmptyState
          title="No attention items yet"
          cause="Attention items come from the domain screens, and none are part of this build."
          nextAction="They appear here as domain screens are added."
        />
      </section>
    </div>
  );
}
