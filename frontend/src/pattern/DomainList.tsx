import type { ReactNode } from "react";
import type { EntityListItem } from "../api/types";
import { EmptyState } from "../shell/EmptyState";
import { MarkerTag } from "./MarkerTag";

export interface FilterDef {
  id: string;
  label: string;
  options: { value: string; label: string }[];
}

interface Props {
  label: string;
  items: EntityListItem[];
  total: number;
  capped: boolean;
  loading: boolean;
  error: string | null;
  search: string;
  onSearch: (value: string) => void;
  filters: FilterDef[];
  filterValues: Record<string, string>;
  onFilter: (id: string, value: string) => void;
  selected: string | null;
  onSelect: (item: EntityListItem) => void;
  meta?: (item: EntityListItem) => ReactNode;
  toolbar?: ReactNode;
  empty: { title: string; cause: string; nextAction: string };
}

/**
 * The list half of the domain pattern (contracts/ui-pattern.md §1, §2): search, filters in the
 * address, one row per entity with the server's markers, count and cap. Domains never render rows.
 */
export function DomainList(props: Props) {
  const { items, loading, error } = props;
  // Lowercase for running text, keeping acronyms ("REST services").
  const noun = /^[A-Z]{2}/.test(props.label) ? props.label : props.label.charAt(0).toLowerCase() + props.label.slice(1);
  return (
    <div className="dlist" data-testid="domain-list">
      <div className="dlist-bar">
        <input
          className="dlist-search"
          type="search"
          value={props.search}
          placeholder={`Filter ${noun}`}
          aria-label={`Filter ${noun} by name`}
          onChange={(e) => props.onSearch(e.target.value)}
        />
        {props.filters.map((f) => (
          <label key={f.id} className="dlist-filter">
            <span className="visually-hidden">{f.label}</span>
            <select value={props.filterValues[f.id] ?? ""} onChange={(e) => props.onFilter(f.id, e.target.value)} data-testid={`filter-${f.id}`}>
              {f.options.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
          </label>
        ))}
        <span className="dlist-count num" role="status">
          {loading ? "" : `${items.length} of ${props.total}${props.capped ? ", capped" : ""}`}
        </span>
        {props.toolbar}
      </div>
      {error ? (
        <div className="dlist-error" role="alert">
          {error}
        </div>
      ) : loading ? (
        <div className="dlist-rows" aria-busy="true">
          {[0, 1, 2, 3, 4, 5].map((i) => (
            <div key={i} className="item skeleton-row" aria-hidden="true">
              <span className="skeleton" />
            </div>
          ))}
        </div>
      ) : items.length === 0 ? (
        <EmptyState {...props.empty} />
      ) : (
        <div className="dlist-rows" role="list" aria-label={props.label}>
          {items.map((item) => {
            const key = item.displayName;
            return (
              <div role="listitem" key={key}>
                <button
                  type="button"
                  className="item"
                  aria-current={props.selected === key ? "true" : undefined}
                  onClick={() => props.onSelect(item)}
                  data-testid="list-row"
                >
                  <span className="nm mono">{item.displayName}</span>
                  <span className="item-markers">
                    {item.markers.map((m) => (
                      <MarkerTag key={m.id} marker={m} />
                    ))}
                  </span>
                  <span className="meta mono">{props.meta?.(item)}</span>
                </button>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
