import type { LogSourceState } from "../../api/types";

/**
 * Every source, always — including the ones that could not be read, with their reason.
 *
 * This panel is the answer to the most dangerous thing a log viewer can say, which is nothing: a
 * source that is absent without explanation reads as "nothing happened there" (UC09 A1, A5).
 */
export function SourcePanel({ sources, onSelect }: { sources: LogSourceState[]; onSelect: (id: string) => void }) {
  if (sources.length === 0) return null;
  const unavailable = sources.filter((source) => !source.available);
  const allOut = unavailable.length === sources.length;
  return (
    <section className="logs-sources" aria-label="Sources" data-testid="logs-sources">
      {allOut && (
        <p className="logs-allout" data-testid="logs-all-unavailable">
          No source could be read. Each one below says why; the list is empty because nothing could be
          fetched, not because nothing happened.
        </p>
      )}
      <ul role="list">
        {sources.map((source) => (
          <li key={source.id} data-testid={`logs-source-${source.id}`} data-available={source.available}>
            <button type="button" className="btn-link" onClick={() => onSelect(source.id)}>
              {source.label}
            </button>
            {source.available ? (
              <span className="logs-source-state">
                {` · ${source.read} read`}
                {source.suppressed > 0 ? ` · ${source.suppressed} more not shown` : ""}
                {source.namespaces && source.namespaces.length > 0 ? ` · namespaces: ${source.namespaces.join(", ")}` : ""}
              </span>
            ) : (
              <span className="logs-source-reason" data-testid={`logs-reason-${source.id}`}>
                {` · ${source.reason ?? "not available"}`}
              </span>
            )}
            {source.unread && source.unread.length > 0 && (
              <span className="logs-source-unread" data-testid={`logs-unread-${source.id}`}>
                {` · not read: ${source.unread.join("; ")}`}
              </span>
            )}
          </li>
        ))}
      </ul>
    </section>
  );
}
