import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { request } from "../../api/client";
import type { LogEvent, LogPage } from "../../api/types";
import { ListInspector } from "../../pattern/ListInspector";
import { EmptyState } from "../../shell/EmptyState";
import { EventInspector } from "./EventInspector";
import { SourcePanel } from "./SourcePanel";
import { ORDERED, tone } from "./severity";
import "./logs.css";

const SOURCES = [
  { id: "audit", label: "Audit" },
  { id: "journal", label: "Journal" },
  { id: "messages", label: "Messages" },
  { id: "alerts", label: "Alerts" },
  { id: "interop", label: "Interoperability" },
];

const FOLLOW_INTERVAL_MS = 5000;

/**
 * UC09: the unified stream. Five formats, one schema, newest first.
 *
 * What the screen must never do is imply something the sources did not say: an event whose source
 * stated no level shows `unknown` rather than info, an absent source is named with its reason rather
 * than left out, and the page states that it shows a share of each source rather than the newest N
 * events overall.
 */
export function Stream() {
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const [selected, setSelected] = useState<LogEvent | null>(null);
  const [following, setFollowing] = useState(false);
  const [hidden, setHidden] = useState(typeof document !== "undefined" && document.visibilityState === "hidden");

  useEffect(() => {
    const onVisibility = () => setHidden(document.visibilityState === "hidden");
    document.addEventListener("visibilitychange", onVisibility);
    return () => document.removeEventListener("visibilitychange", onVisibility);
  }, []);

  const filters = useMemo(
    () => ({
      sources: params.get("sources") ?? "",
      minSeverity: params.get("minSeverity") ?? "",
      includeUnknown: params.get("includeUnknown") ?? "true",
      q: params.get("q") ?? "",
      from: params.get("from") ?? "",
      to: params.get("to") ?? "",
      taskId: params.get("taskId") ?? "",
      taskName: params.get("taskName") ?? "",
    }),
    [params],
  );

  const setFilter = useCallback(
    (key: string, value: string) => {
      const next = new URLSearchParams(params);
      if (value === "") next.delete(key);
      else next.set(key, value);
      setParams(next, { replace: true });
    },
    [params, setParams],
  );

  const query = useMemo(() => {
    const out: Record<string, string> = { limit: "200" };
    for (const [key, value] of Object.entries(filters)) if (value !== "" && key !== "taskName") out[key] = value;
    return out;
  }, [filters]);

  const page = useQuery({
    queryKey: ["logs", query],
    queryFn: ({ signal }) => request<LogPage>("/logs/events", { query, signal }),
    refetchInterval: following && !hidden ? FOLLOW_INTERVAL_MS : false,
    refetchIntervalInBackground: false,
    placeholderData: keepPreviousData,
    retry: false,
  });

  // The export is the same data the screen showed, fetched with the same filters and downloaded the
  // way the trail export already does it (spec FR-022).
  const exportFiltered = useCallback(async () => {
    const answer = await request<unknown>("/logs/export", { query });
    const url = URL.createObjectURL(new Blob([JSON.stringify(answer, null, 1)], { type: "application/json" }));
    const anchor = window.document.createElement("a");
    anchor.href = url;
    anchor.download = `flightdeck-logs-${new Date().toISOString().slice(0, 19).replace(/[:T]/g, "")}.json`;
    anchor.click();
    URL.revokeObjectURL(url);
  }, [query]);

  const events = page.data?.events ?? [];
  const correlated = filters.taskId !== "";

  return (
    <ListInspector
      inspectorLabel="Log event details"
      onClose={() => setSelected(null)}
      list={
        <div className="dlist" data-testid="log-stream">
          <div className="dlist-h">
            <div className="dlist-filters">
              <label>
                Sources
                <select
                  value={filters.sources}
                  onChange={(event) => setFilter("sources", event.target.value)}
                  data-testid="filter-sources"
                  aria-label="Sources"
                >
                  <option value="">Every source</option>
                  {SOURCES.map((source) => (
                    <option key={source.id} value={source.id}>
                      {source.label} only
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Minimum severity
                <select
                  value={filters.minSeverity}
                  onChange={(event) => setFilter("minSeverity", event.target.value)}
                  data-testid="filter-severity"
                  aria-label="Minimum severity"
                >
                  <option value="">Every severity</option>
                  {ORDERED.map((severity) => (
                    <option key={severity} value={severity}>
                      {severity} and above
                    </option>
                  ))}
                </select>
              </label>
              {/* unknown is outside the ordering, so it cannot be above or below a threshold: it gets
                  its own switch, and the screen says what the switch does (spec FR-003c). */}
              <label className="logs-unknown" data-testid="filter-unknown">
                <input
                  type="checkbox"
                  checked={filters.includeUnknown !== "false"}
                  onChange={(event) => setFilter("includeUnknown", event.target.checked ? "" : "false")}
                />
                Include events whose source stated no severity (unknown). They are not ranked, so a
                minimum severity neither includes nor excludes them.
              </label>
              <label>
                Text
                <input
                  type="text"
                  value={filters.q}
                  onChange={(event) => setFilter("q", event.target.value)}
                  data-testid="filter-q"
                  aria-label="Filter by text"
                />
              </label>
              <button
                type="button"
                className="btn"
                onClick={() => setFollowing((value) => !value)}
                data-testid="follow-toggle"
                aria-pressed={following}
              >
                {following ? "Stop following" : "Follow live"}
              </button>
              <button className="btn" type="button" onClick={() => void exportFiltered()} data-testid="logs-export">
                Export
              </button>
            </div>
            {correlated && (
              <div className="logs-correlated" data-testid="logs-correlated">
                {`Filtered on task ${filters.taskName || filters.taskId}${filters.from ? `, between ${filters.from} and ${filters.to}` : ""}.`}{" "}
                <button type="button" className="btn-link" onClick={() => navigate("/logs/stream")}>
                  Clear
                </button>
              </div>
            )}
            <div className="logs-state" data-testid="logs-state">
              {following ? (
                <span>{hidden ? "Paused while this tab is in the background" : `Following by polling every ${FOLLOW_INTERVAL_MS / 1000}s`}</span>
              ) : (
                <span>Not following</span>
              )}
              {page.data?.share !== undefined && (
                <span data-testid="logs-share">
                  {` · showing the most recent ${page.data.share} of each selected source, ordered by time`}
                </span>
              )}
              {page.data?.timeZone && <span>{` · times in the instance's zone (${page.data.timeZone})`}</span>}
              {page.data?.truncated && (
                <span data-testid="logs-suppressed">{` · ${page.data.truncated.suppressed} more not shown (${page.data.truncated.reason})`}</span>
              )}
              {page.data?.fileChanged && <span data-testid="logs-file-changed">{` · ${page.data.fileChanged}`}</span>}
            </div>
          </div>
          {page.error && (
            <div className="dlist-error" role="alert" data-testid="logs-error">
              {page.error.message}
            </div>
          )}
          <SourcePanel sources={page.data?.sources ?? []} onSelect={(id) => setFilter("sources", id)} />
          {page.data && events.length === 0 && (
            <EmptyState
              title="No event matches"
              cause="No source reported an event that passes these filters."
              nextAction="Widen the period, or lower the minimum severity."
            />
          )}
          <ul className="logs" role="list" aria-live={following ? "polite" : "off"} data-testid="log-list">
            {events.map((event) => (
              <li key={event.id}>
                <button
                  type="button"
                  className="logs-row"
                  data-testid="log-row"
                  data-source={event.source}
                  data-severity={event.severity}
                  onClick={() => setSelected(event)}
                  aria-current={selected?.id === event.id ? "true" : undefined}
                >
                  <span className="logs-at num">{event.timestamp}</span>
                  <span className="logs-src">{event.source}</span>
                  <span className="logs-sev" data-tone={tone(event.severity)}>
                    {event.severity}
                  </span>
                  <span className="logs-msg">{event.message}</span>
                  {!event.parsed && <span className="logs-note">line kept as written; it did not match this source's shape</span>}
                </button>
              </li>
            ))}
          </ul>
        </div>
      }
      inspector={selected ? <EventInspector event={selected} onClose={() => setSelected(null)} /> : null}
    />
  );
}
