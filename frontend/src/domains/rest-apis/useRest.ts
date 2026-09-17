import { useQuery } from "@tanstack/react-query";
import { request } from "../../api/client";
import type { RestServicesResponse, SpecificationResponse } from "../../api/types";

export function useRestServices() {
  return useQuery({ queryKey: ["rest", "services"], queryFn: ({ signal }) => request<RestServicesResponse>("/rest/services", { signal }) });
}

export function useSpecification(keys: { webApplication?: string; name?: string } | null) {
  return useQuery({
    queryKey: ["rest", "specification", keys],
    enabled: keys !== null,
    queryFn: ({ signal }) => request<SpecificationResponse>("/rest/services/specification", { query: keys ?? {}, signal }),
  });
}
