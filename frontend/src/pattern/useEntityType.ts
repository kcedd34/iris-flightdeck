// Descriptor-driven reads and address state for domain screens (feature 002, contracts/ui-pattern.md).
// No domain-specific code lives here.
import { useQuery } from "@tanstack/react-query";
import { useCallback, useMemo } from "react";
import { useSearchParams } from "react-router-dom";
import { request } from "../api/client";
import type { EntityDetailResponse, EntityListResponse, Keys, LinksResponse } from "../api/types";

export interface EntityRef {
  domain: string;
  entityType: string;
  keys: Keys;
}

export function entityPath(ref: Pick<EntityRef, "domain" | "entityType">): string {
  return `/domains/${encodeURIComponent(ref.domain)}/${encodeURIComponent(ref.entityType)}`;
}

export function useEntityList(domain: string, entityType: string, query: Record<string, string> = {}) {
  return useQuery({
    queryKey: ["entities", domain, entityType, query],
    queryFn: ({ signal }) => request<EntityListResponse>(entityPath({ domain, entityType }), { query, signal }),
  });
}

export function useEntityItem(ref: EntityRef | null) {
  return useQuery({
    queryKey: ["entity", ref?.domain, ref?.entityType, ref?.keys],
    enabled: ref !== null,
    queryFn: ({ signal }) => request<EntityDetailResponse>(`${entityPath(ref!)}/item`, { query: ref!.keys, signal }),
  });
}

export function useEntityLinks(ref: EntityRef | null) {
  return useQuery({
    queryKey: ["links", ref?.domain, ref?.entityType, ref?.keys],
    enabled: ref !== null,
    queryFn: ({ signal }) => request<LinksResponse>(`${entityPath(ref!)}/links`, { query: ref!.keys, signal }),
  });
}

/** `inspect=<domain>/<entityType>:<name>` or `...:?k=v&k2=v2` for several keys. */
export function encodeInspect(ref: EntityRef): string {
  const entries = Object.entries(ref.keys);
  const keys = entries.length === 1 && entries[0]![0] === "name" ? entries[0]![1] : "?" + new URLSearchParams(ref.keys).toString();
  return `${ref.domain}/${ref.entityType}:${keys}`;
}

export function decodeInspect(value: string | null): EntityRef | null {
  if (!value) return null;
  const colon = value.indexOf(":");
  if (colon < 0) return null;
  const type = value.slice(0, colon);
  const slash = type.indexOf("/");
  if (slash < 0) return null; // feature 001 palette form "<label>:<name>": handled by placeholders
  const raw = value.slice(colon + 1);
  const keys: Keys = raw.startsWith("?") ? Object.fromEntries(new URLSearchParams(raw.slice(1))) : { name: raw };
  return { domain: type.slice(0, slash), entityType: type.slice(slash + 1), keys };
}

/** The inspected entity, with a back stack for linked entities (spec FR-006). */
export function useInspectTarget() {
  const [params, setParams] = useSearchParams();
  const target = useMemo(() => decodeInspect(params.get("inspect")), [params]);
  const backStack = params.getAll("back");
  const open = useCallback(
    (ref: EntityRef, options: { push?: boolean } = {}) => {
      setParams((current) => {
        const next = new URLSearchParams(current);
        const previous = next.get("inspect");
        if (options.push && previous) next.append("back", previous);
        if (!options.push) next.delete("back");
        next.set("inspect", encodeInspect(ref));
        return next;
      });
    },
    [setParams],
  );
  const back = useCallback(() => {
    setParams((current) => {
      const next = new URLSearchParams(current);
      const stack = next.getAll("back");
      const previous = stack.pop();
      next.delete("back");
      stack.forEach((entry) => next.append("back", entry));
      if (previous) next.set("inspect", previous);
      else next.delete("inspect");
      return next;
    });
  }, [setParams]);
  const close = useCallback(() => {
    setParams((current) => {
      const next = new URLSearchParams(current);
      next.delete("inspect");
      next.delete("back");
      return next;
    });
  }, [setParams]);
  return { target, open, back, close, canGoBack: backStack.length > 0 };
}

/** List filters kept in the address, so a filtered view can be shared. */
export function useAddressFilters<K extends string>(ids: readonly K[]) {
  const [params, setParams] = useSearchParams();
  const values = useMemo(() => Object.fromEntries(ids.map((id) => [id, params.get(id) ?? ""])) as Record<K, string>, [ids, params]);
  const set = useCallback(
    (id: K, value: string) => {
      setParams(
        (current) => {
          const next = new URLSearchParams(current);
          if (value) next.set(id, value);
          else next.delete(id);
          return next;
        },
        { replace: true },
      );
    },
    [setParams],
  );
  return [values, set] as const;
}
