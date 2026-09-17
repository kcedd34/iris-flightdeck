import { useQuery } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { request } from "../api/client";
import type { EntitySearchResponse, RailDomainId } from "../api/types";

/** Debounced server entity search (FR-021). Never throws to the UI: failures become `unavailable`. */
export function useEntitySearch(query: string, domain: RailDomainId | null, enabled: boolean) {
  const [debounced, setDebounced] = useState(query);
  useEffect(() => {
    const t = window.setTimeout(() => setDebounced(query.trim()), 250);
    return () => window.clearTimeout(t);
  }, [query]);

  const result = useQuery({
    queryKey: ["palette-entities", debounced, domain],
    queryFn: ({ signal }) =>
      request<EntitySearchResponse>("/palette/entities", { query: { q: debounced, domain: domain ?? undefined, limit: 5 }, signal }),
    enabled: enabled && debounced.length >= 1,
    staleTime: 10_000,
    retry: false,
  });
  return {
    data: result.data,
    pending: enabled && (query.trim() !== debounced || result.isFetching),
    unavailable: result.isError,
  };
}
