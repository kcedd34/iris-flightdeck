import { useState } from "react";
import { ApiError, request } from "../../api/client";
import type { ExecuteResponse, HttpMethod, TestRequest } from "../../api/types";
import { useMutation } from "../../mutation/useMutation";
import { ResponsePanel } from "./ResponsePanel";

const METHODS: HttpMethod[] = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"];
const MUTATING = new Set<HttpMethod>(["POST", "PUT", "PATCH", "DELETE"]);

export interface Draft {
  method: HttpMethod;
  path: string;
  query: string;
  headers: string;
  body: string;
}

/**
 * A test request against this instance only (RN-FD-08): the user edits method, path, query, headers
 * and body; scheme, host and port always come from the server. GET, HEAD and OPTIONS run directly;
 * POST, PUT, PATCH and DELETE go through the shared dry-run in request mode (spec FR-039).
 */
export function RequestBuilder({ initial, rolesNote }: { initial: Draft; rolesNote: string | null }) {
  const [draft, setDraft] = useState<Draft>(initial);
  const [result, setResult] = useState<{ request: TestRequest; response: ExecuteResponse } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [running, setRunning] = useState(false);
  const { start } = useMutation();
  const set = (patch: Partial<Draft>) => setDraft((d) => ({ ...d, ...patch }));

  const run = async () => {
    setError(null);
    const test = toRequest(draft);
    if ("error" in test) {
      setError(test.error);
      return;
    }
    setRunning(true);
    try {
      if (MUTATING.has(test.request.method)) {
        const outcome = await start({ operationId: "FLIGHTDECK REST execute", request: test.request, noun: "this instance" });
        if (outcome.status === "applied") setResult({ request: test.request, response: outcome.result as ExecuteResponse });
        else if (outcome.status === "rejected" || outcome.status === "blocked") setError(outcome.message);
      } else {
        const response = await request<ExecuteResponse>("/rest/execute", { method: "POST", body: test.request });
        setResult({ request: test.request, response });
      }
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "The server could not be reached.");
    } finally {
      setRunning(false);
    }
  };

  return (
    <section className="sect rbuilder" aria-label="Test request" data-testid="rest-request-builder">
      <div className="sect-h">Test request on this instance</div>
      {rolesNote && (
        <p className="lgroup-reason" data-testid="rest-roles-note">
          {rolesNote}
        </p>
      )}
      <div className="rrow">
        <label className="visually-hidden" htmlFor="rb-method">
          Method
        </label>
        <select id="rb-method" value={draft.method} onChange={(e) => set({ method: e.target.value as HttpMethod })} data-testid="rest-method">
          {METHODS.map((m) => (
            <option key={m}>{m}</option>
          ))}
        </select>
        <label className="visually-hidden" htmlFor="rb-path">
          Path on this instance
        </label>
        <input id="rb-path" className="mono" type="text" value={draft.path} onChange={(e) => set({ path: e.target.value })} data-testid="rest-path" />
      </div>
      <label className="rlabel" htmlFor="rb-query">
        Query (name=value per line)
      </label>
      <textarea id="rb-query" className="mono" rows={2} value={draft.query} onChange={(e) => set({ query: e.target.value })} />
      <label className="rlabel" htmlFor="rb-headers">
        Headers (Name: value per line)
      </label>
      <textarea id="rb-headers" className="mono" rows={2} value={draft.headers} onChange={(e) => set({ headers: e.target.value })} data-testid="rest-headers" />
      {MUTATING.has(draft.method) && (
        <>
          <label className="rlabel" htmlFor="rb-body">
            Body
          </label>
          <textarea id="rb-body" className="mono" rows={5} value={draft.body} onChange={(e) => set({ body: e.target.value })} data-testid="rest-body" />
        </>
      )}
      <div className="actions">
        <button type="button" className="btn btn-primary" onClick={() => void run()} disabled={running} data-testid="rest-execute">
          {MUTATING.has(draft.method) ? "Review request" : "Run"}
        </button>
      </div>
      {error && (
        <div className="dlist-error" role="alert" data-testid="rest-error">
          {error}
        </div>
      )}
      {result && <ResponsePanel request={result.request} response={result.response} />}
    </section>
  );
}

export function toRequest(draft: Draft): { request: TestRequest } | { error: string } {
  const query: Record<string, string> = {};
  for (const line of draft.query.split("\n").map((l) => l.trim()).filter(Boolean)) {
    const eq = line.indexOf("=");
    if (eq < 1) return { error: `Query line "${line}" is not name=value.` };
    query[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
  }
  const headers: Record<string, string> = {};
  for (const line of draft.headers.split("\n").map((l) => l.trim()).filter(Boolean)) {
    const colon = line.indexOf(":");
    if (colon < 1) return { error: `Header line "${line}" is not Name: value.` };
    headers[line.slice(0, colon).trim()] = line.slice(colon + 1).trim();
  }
  const req: TestRequest = { method: draft.method, path: draft.path.trim(), query, headers };
  if (MUTATING.has(draft.method) && draft.body.trim()) req.body = draft.body;
  return { request: req };
}
