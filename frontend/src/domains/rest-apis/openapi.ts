// OpenAPI 2.0 and 3.0 normalizer for the REST API explorer (feature 002 research R9). One shape for
// the viewer and the request builder: operations grouped by path and method, parameters, request
// body and responses, with $ref resolved and cycles cut.

export interface SchemaView {
  type: string;
  description?: string;
  enum?: unknown[];
  required?: string[];
  properties?: Record<string, SchemaView>;
  items?: SchemaView;
  /** Set when a $ref was not expanded because it is already being expanded (a cycle). */
  ref?: string;
}

export interface ParameterView {
  name: string;
  in: "path" | "query" | "header" | "cookie" | "formData";
  required: boolean;
  description: string;
  schema: SchemaView;
}

export interface OperationView {
  method: string;
  path: string;
  operationId: string;
  summary: string;
  description: string;
  parameters: ParameterView[];
  requestBody: { contentType: string; required: boolean; schema: SchemaView } | null;
  responses: { status: string; description: string; schema: SchemaView | null }[];
}

export interface SpecificationView {
  format: "openapi-2.0" | "openapi-3.0";
  title: string;
  version: string;
  basePath: string;
  paths: { path: string; operations: OperationView[] }[];
}

type Json = Record<string, unknown>;
const METHODS = ["get", "put", "post", "delete", "patch", "head", "options"];

export function normalize(document: Json): SpecificationView {
  const v3 = typeof document.openapi === "string";
  const info = (document.info ?? {}) as Json;
  const basePath = v3 ? serverPath(document) : String(document.basePath ?? "");
  const paths: SpecificationView["paths"] = [];
  const rawPaths = (document.paths ?? {}) as Record<string, Json>;
  for (const [path, item] of Object.entries(rawPaths)) {
    const shared = (item.parameters ?? []) as Json[];
    const operations: OperationView[] = [];
    for (const method of METHODS) {
      const op = item[method] as Json | undefined;
      if (!op || typeof op !== "object") continue;
      const params = [...shared, ...((op.parameters ?? []) as Json[])].map((p) => deref(document, p));
      const bodyParam = params.find((p) => p.in === "body");
      let requestBody: OperationView["requestBody"] = null;
      if (v3 && op.requestBody) {
        const body = deref(document, op.requestBody as Json);
        const content = (body.content ?? {}) as Record<string, Json>;
        const contentType = Object.keys(content)[0] ?? "application/json";
        requestBody = { contentType, required: Boolean(body.required), schema: schema(document, (content[contentType]?.schema ?? {}) as Json, new Set()) };
      } else if (bodyParam) {
        requestBody = { contentType: firstOf(op.consumes ?? document.consumes) ?? "application/json", required: Boolean(bodyParam.required), schema: schema(document, (bodyParam.schema ?? {}) as Json, new Set()) };
      }
      operations.push({
        method: method.toUpperCase(),
        path,
        operationId: String(op.operationId ?? ""),
        summary: String(op.summary ?? ""),
        description: String(op.description ?? ""),
        parameters: params
          .filter((p) => p.in !== "body")
          .map((p) => ({
            name: String(p.name ?? ""),
            in: (p.in as ParameterView["in"]) ?? "query",
            required: Boolean(p.required),
            description: String(p.description ?? ""),
            schema: schema(document, (v3 ? (p.schema ?? {}) : p) as Json, new Set()),
          })),
        requestBody,
        responses: Object.entries((op.responses ?? {}) as Record<string, Json>).map(([status, raw]) => {
          const response = deref(document, raw);
          const content = (response.content ?? {}) as Record<string, Json>;
          const rawSchema = v3 ? (Object.values(content)[0]?.schema as Json | undefined) : (response.schema as Json | undefined);
          return { status, description: String(response.description ?? ""), schema: rawSchema ? schema(document, rawSchema, new Set()) : null };
        }),
      });
    }
    if (operations.length) paths.push({ path, operations });
  }
  return {
    format: v3 ? "openapi-3.0" : "openapi-2.0",
    title: String(info.title ?? ""),
    version: String(info.version ?? ""),
    basePath,
    paths,
  };
}

function serverPath(document: Json): string {
  const servers = (document.servers ?? []) as Json[];
  const url = String(servers[0]?.url ?? "");
  try {
    return new URL(url, "http://instance").pathname.replace(/\/$/, "");
  } catch {
    return "";
  }
}

function firstOf(value: unknown): string | undefined {
  return Array.isArray(value) && typeof value[0] === "string" ? value[0] : undefined;
}

function lookup(document: Json, ref: string): Json | null {
  if (!ref.startsWith("#/")) return null;
  let node: unknown = document;
  for (const part of ref.slice(2).split("/")) {
    const key = part.replace(/~1/g, "/").replace(/~0/g, "~");
    if (!node || typeof node !== "object") return null;
    node = (node as Json)[key];
  }
  return node && typeof node === "object" ? (node as Json) : null;
}

function deref(document: Json, node: Json): Json {
  const seen = new Set<string>();
  let current = node;
  while (typeof current.$ref === "string" && !seen.has(current.$ref)) {
    seen.add(current.$ref);
    const next = lookup(document, current.$ref);
    if (!next) break;
    current = next;
  }
  return current;
}

function schema(document: Json, node: Json, expanding: Set<string>): SchemaView {
  if (typeof node.$ref === "string") {
    const ref = node.$ref;
    if (expanding.has(ref)) return { type: "object", ref };
    const target = lookup(document, ref);
    if (!target) return { type: "object", ref };
    const next = new Set(expanding).add(ref);
    return schema(document, target, next);
  }
  const view: SchemaView = { type: String(node.type ?? (node.properties ? "object" : "any")) };
  if (node.description) view.description = String(node.description);
  if (Array.isArray(node.enum)) view.enum = node.enum;
  if (Array.isArray(node.required)) view.required = node.required as string[];
  if (node.properties && typeof node.properties === "object") {
    view.properties = Object.fromEntries(Object.entries(node.properties as Record<string, Json>).map(([k, v]) => [k, schema(document, v, expanding)]));
  }
  if (node.items && typeof node.items === "object") view.items = schema(document, node.items as Json, expanding);
  return view;
}

/** A skeleton JSON body from a schema, for the request builder. */
export function example(view: SchemaView, depth = 0): unknown {
  if (view.enum?.length) return view.enum[0];
  if (depth > 4 || view.ref) return {};
  switch (view.type) {
    case "object":
      return Object.fromEntries(Object.entries(view.properties ?? {}).map(([k, v]) => [k, example(v, depth + 1)]));
    case "array":
      return view.items ? [example(view.items, depth + 1)] : [];
    case "integer":
    case "number":
      return 0;
    case "boolean":
      return false;
    case "string":
      return "";
    default:
      return null;
  }
}
