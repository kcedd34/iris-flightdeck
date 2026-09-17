// Shapes from specs/001-foundation-shell/contracts/flightdeck-api.openapi.json.

export type DomainId = "shell" | "web-apps" | "permissions" | "security" | "tasks" | "system" | "logs";

export type RailDomainId = Exclude<DomainId, "shell">;

export interface Session {
  username: string;
  instance: {
    product: string;
    version: string;
    serverVersion: string;
    apiVersion: number;
    edition: string;
    namespace: string;
  };
  authPath: "in_process";
  privileges: Record<string, { use: boolean }>;
  capabilitySummary: { allowed: number; total: number };
}

export interface CapabilityEntry {
  operationId: string;
  method: "GET" | "PUT" | "POST" | "DELETE";
  path: string;
  domain: DomainId;
  mutating: boolean;
  summary: string;
  requires: string[];
  allowed: boolean;
  reason: string | null;
}

export interface Vital {
  id: "cpu" | "memory" | "shm" | "disk";
  label: string;
  source: "native" | "api";
  scope: string | null;
  state: "ok" | "caution" | "warning" | "unavailable";
  value: number | null;
  asOf: string | null;
  pending: boolean;
  reason: string | null;
  requires: string | null;
}

export interface EntityEntry {
  kind: "entity";
  domain: DomainId;
  entityType: string;
  name: string;
  context: string;
  sourceOperationId: string;
  target: { route: string; inspect: { entityType: string; name: string } };
}

export interface EntitySearchGroup {
  domain: DomainId;
  entityType: string;
  state: "ok" | "forbidden" | "timeout" | "error";
  reason: string | null;
  results: EntityEntry[];
  total: number | null;
}

export interface EntitySearchResponse {
  groups: EntitySearchGroup[];
  degraded: boolean;
  reason: string | null;
  totalResults: number;
}
