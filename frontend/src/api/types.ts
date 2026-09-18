// Shapes from specs/001-foundation-shell/contracts/flightdeck-api.openapi.json.

export type DomainId = "shell" | "web-apps" | "permissions" | "security" | "tasks" | "system" | "logs";

export type RailDomainId = Exclude<DomainId, "shell">;

export interface Session {
  username: string;
  instance: {
    product: string;
    version: string;
    serverVersion: string;
    edition: string;
    namespace: string;
  };
  authPath: "in_process";
  privileges: Record<string, { use: boolean }>;
  capabilitySummary: { allowed: number; unavailable: number; total: number };
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
  /** False when the operation is not offered: by this instance (v1 dialect) or by FlightDeck itself. */
  available: boolean;
  /** True when FlightDeck declines to offer it on any version (capability policy, feature 003). */
  declined?: boolean;
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
  target: {
    route: string;
    /** domain, descriptorType and keys are present for entity types built on the domain pattern (feature 002). */
    inspect: { entityType: string; name: string; domain?: string; descriptorType?: string; keys?: Keys };
  };
}

export interface EntitySearchGroup {
  domain: DomainId;
  entityType: string;
  state: "ok" | "forbidden" | "unavailable" | "timeout" | "error";
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

// Feature 002 (specs/002-webapps-explorer-mutations/contracts/flightdeck-api-002.openapi.json).

export type Grade = "simple" | "reinforced" | "maximum";

export interface Marker {
  id: string;
  text: string;
  tone: "caution" | "warning" | "neutral";
}

export interface MutationCapability {
  operationId: string;
  allowed: boolean;
  available: boolean;
  declined?: boolean;
  reason: string | null;
}

export type Keys = Record<string, string>;

export interface EntityListItem {
  object: Record<string, unknown>;
  markers: Marker[];
  keys: Keys;
  displayName: string;
  facts: Record<string, unknown>;
}

export interface EntityListResponse {
  entityType: string;
  operationId: string;
  items: EntityListItem[];
  total: number;
  capped: boolean;
}

export interface EntityDetailResponse {
  entityType: string;
  object: Record<string, unknown>;
  keys: Keys;
  displayName: string;
  isSystem: boolean;
  isFlightDeck: boolean;
  markers: Marker[];
  facts: Record<string, unknown>;
  availableMutations: MutationCapability[];
}

export interface LinkItem {
  entityType: string;
  domain: DomainId;
  displayName: string;
  keys: Keys;
  detail: string | null;
}

export interface LinkGroupParameter {
  name: string;
  required: boolean;
  /** Known choices when the session may list them; empty when it may not, and reason says why. */
  values: string[];
  value: string | null;
}

export interface LinkGroup {
  provider: string;
  direction: "in" | "out";
  label: string;
  state: "ok" | "forbidden" | "unavailable" | "undetermined" | "needs-parameter";
  reason: string | null;
  count: number | null;
  items: LinkItem[];
  /** Declared by parameterised providers (feature 003 contract ui-pattern-delta D2). */
  parameters?: LinkGroupParameter[];
  /** True when a cap or a refused read stopped a traversal; the group says what was not expanded. */
  truncated?: boolean;
}

export interface LinksResponse {
  groups: LinkGroup[];
}

export type HttpMethod = "GET" | "HEAD" | "OPTIONS" | "POST" | "PUT" | "PATCH" | "DELETE";

export interface TestRequest {
  method: HttpMethod;
  path: string;
  query?: Record<string, string>;
  headers?: Record<string, string>;
  body?: string | null;
}

export interface PreviewRequest {
  operationId: string;
  keys?: Keys;
  proposed?: Record<string, unknown>;
  request?: TestRequest;
  /** kind=action: the official operation's declared parameters and option modifiers. */
  params?: Record<string, string>;
  options?: Record<string, string>;
}

export interface DiffRow {
  field: string;
  label: string;
  current?: unknown;
  commanded?: unknown;
  changed: boolean;
  secret: boolean;
}

export interface Impact {
  state: "ok" | "undetermined" | "none";
  summary?: string;
  users?: string[];
  objects?: LinkItem[];
  reason?: string | null;
}

export interface PreviewResponse {
  kind: "create" | "edit" | "delete" | "request" | "action";
  target: string;
  rows: DiffRow[];
  noChange: boolean;
  grade: Grade;
  confirmText: string | null;
  consequence: string | null;
  impact?: Impact;
  blocked: { message: string } | null;
  fingerprint: string;
  requestMode: { request: TestRequest; reason: string } | null;
  /** Present only when blocked: the server's Blocked record (FR-014). */
  trail?: TrailRecord;
  /** A server note about this preview, for example a check that could not assert (feature 003). */
  notice?: string | null;
  /** What to tell the user while the instance works on it, for operations known to be slow. */
  applyNotice?: string | null;
}

export interface ApplyRequest extends PreviewRequest {
  fingerprint: string;
  confirmation?: string;
  acknowledged?: boolean;
}

export interface TrailRecord {
  id: string;
  /** Feature 003: which mode the last-administrator check ran in, when one ran (FR-010c). */
  checkMode?: "complete" | "partial";
  checkResult?: "held" | "would-remove-last" | "not-determined";
  checkUnread?: string[];
  time: string;
  operationId: string;
  kind: string;
  target: string;
  rows: DiffRow[];
  request?: TestRequest;
  result: "Applied" | "Failed" | "Blocked";
  status: number;
  message: string | null;
  concurrency: string;
}

export interface ApplyResponse {
  result: unknown;
  trail: TrailRecord;
}

export interface RestService {
  /** The web application, or the specification name when no web application serves it. */
  name: string;
  webApplication: string;
  namespace: string;
  dispatchClass: string;
  enabled: boolean;
  kind: "specification-first" | "hand-coded";
  hasSpecification: boolean;
  specificationSource: "specification-first" | "published" | null;
  routesReportedByPlatform: boolean;
  specificationName?: string;
  markers: Marker[];
}

export interface RestServicesResponse {
  services: RestService[];
  namespaces: { name: string; state: "ok" | "forbidden" | "error"; reason: string | null }[];
}

export interface SpecificationResponse {
  format: "openapi-2.0" | "openapi-3.0" | "routes";
  document: Record<string, unknown> | null;
  routes: { method: string; path: string; call: string }[] | null;
}

export type ExecuteRequest = TestRequest;

export interface ExecuteResponse {
  status: number;
  elapsedMs: number;
  headers: Record<string, string>;
  body: string;
  bodySize: number;
  truncated: boolean;
  contentType: string | null;
  resolved: { webApplication: string; namespace: string; dispatchClass: string };
  rolesMode: "current-kept" | "login-only";
  grantsNotApplied: string[];
}

export interface AttentionItem {
  kind: "expiring-credential" | "expired-credential";
  label: string;
  band: "expiring" | "expired";
  daysRemaining: number;
  target: { domain: string; entityType: string; keys: Keys };
}

export interface AttentionResponse {
  items: AttentionItem[];
  /** True when a source was refused or a read cap was reached; reason says which. */
  degraded: boolean;
  reason: string | null;
}

export interface CompositeCapability {
  id: string;
  requires: string[][];
  allowed: boolean;
  available: boolean;
  reason: string | null;
}
