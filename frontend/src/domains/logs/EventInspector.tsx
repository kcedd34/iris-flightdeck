import { useQuery } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { request } from "../../api/client";
import type { LogEvent } from "../../api/types";
import { encodeInspect } from "../../pattern/useEntityType";

const TARGETS: { field: string; label: string; route: (value: string) => string }[] = [
  {
    field: "process",
    label: "Open this process",
    route: (value) => `/system/processes?inspect=${encodeURIComponent(encodeInspect({ domain: "system", entityType: "process", keys: { id: value } }))}`,
  },
  {
    field: "namespace",
    label: "Open this namespace",
    route: (value) => `/system/namespaces?inspect=${encodeURIComponent(encodeInspect({ domain: "system", entityType: "namespace", keys: { name: value } }))}`,
  },
  {
    field: "user",
    label: "Open this user",
    route: (value) => `/permissions/users?inspect=${encodeURIComponent(encodeInspect({ domain: "permissions", entityType: "user", keys: { name: value } }))}`,
  },
];

/**
 * One event: the normalised fields, the original record, and the jumps it can offer (RN-FD-26).
 *
 * Where the original cannot be recovered, this says so where the record would be and keeps the
 * normalised fields on screen — the gap is information, not an absence (spec FR-005).
 */
export function EventInspector({ event, onClose }: { event: LogEvent; onClose: () => void }) {
  const navigate = useNavigate();
  const needsFetch = event.rawAvailable && event.rawKey !== undefined;
  const raw = useQuery({
    queryKey: ["log-raw", event.id],
    queryFn: ({ signal }) =>
      request<{ available: boolean; raw: unknown; reason: string | null }>("/logs/event/raw", {
        query: { source: event.source, ...(event.rawKey ?? {}) },
        signal,
      }),
    enabled: needsFetch,
    retry: false,
  });
  const record = needsFetch ? raw.data?.raw : event.raw;
  const gone = needsFetch ? raw.data && !raw.data.available : !event.rawAvailable;
  const reason = needsFetch ? raw.data?.reason : event.rawReason;

  return (
    <div className="pinspector" data-testid="log-event">
      <button className="btn inspector-close" type="button" onClick={onClose} aria-label="Close inspector">
        Close
      </button>
      <h2 className="mono">{event.message}</h2>
      <div className="inspector-sub">{`${event.source} · ${event.severity}`}</div>
      <div className="sect">
        <div className="sect-h">Normalised</div>
        {[
          ["Timestamp", event.timestamp],
          ["Source", event.source],
          ["Severity", event.severity],
          ["Namespace", event.namespace],
          ["Process", event.process],
          ["User", event.user],
        ].map(([label, value]) => (
          <div className="field" key={label}>
            <span className="field-k">{label}</span>
            <span className="field-v mono">
              {value ?? <span className="logs-absent">not provided by this source</span>}
            </span>
          </div>
        ))}
        {!event.parsed && (
          <p className="logs-note" data-testid="log-unparsed">
            This line did not match the shape this source usually writes. It is shown exactly as it was
            written, and nothing was discarded.
          </p>
        )}
      </div>
      <div className="sect">
        <div className="sect-h">Original record</div>
        {gone ? (
          <p className="logs-note" data-testid="log-raw-gone">
            {reason ?? "The original record could not be recovered."} The normalised fields above are
            what FlightDeck read before it went.
          </p>
        ) : (
          <pre className="logs-raw mono" data-testid="log-raw">
            {record === undefined ? "Reading…" : JSON.stringify(record, null, 1)}
          </pre>
        )}
      </div>
      <div className="sect">
        <div className="sect-h">Related</div>
        {TARGETS.filter((target) => event.correlate[target.field]).map((target) => (
          <button
            key={target.field}
            type="button"
            className="btn"
            data-testid={`log-jump-${target.field}`}
            onClick={() => navigate(target.route(event.correlate[target.field]!))}
          >
            {`${target.label} (${event.correlate[target.field]})`}
          </button>
        ))}
        {Object.keys(event.correlate).length === 0 && (
          <p className="logs-note">This event names no process, namespace or user to open.</p>
        )}
      </div>
    </div>
  );
}
