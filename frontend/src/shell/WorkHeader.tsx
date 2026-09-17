import type { ReactNode } from "react";
import { Link } from "react-router-dom";
import type { Domain } from "./domains";

interface Props {
  title: string;
  domain?: Domain;
  activeSection?: string;
  right?: ReactNode;
}

/**
 * Work header with the section tab strip (design §4.1, FR-033). The strip renders only when the
 * domain has more than one entity type; the active tab lives in the URL.
 */
export function WorkHeader({ title, domain, activeSection, right }: Props) {
  const showTabs = domain && domain.sections.length > 1;
  return (
    <div className="workhead">
      <div className="workhead-row">
        <h1>{title}</h1>
        <div className="workhead-right">{right}</div>
      </div>
      {showTabs && (
        <nav className="tabs" aria-label={`${domain.label} sections`} data-testid="section-tabs">
          {domain.sections.map((s) => (
            <Link
              key={s.id}
              className="tab"
              to={`/${domain.id}/${s.id}`}
              aria-current={activeSection === s.id ? "page" : undefined}
            >
              {s.label}
            </Link>
          ))}
        </nav>
      )}
    </div>
  );
}
