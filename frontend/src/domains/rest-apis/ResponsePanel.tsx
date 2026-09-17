import { useState } from "react";
import type { ExecuteResponse, TestRequest } from "../../api/types";

/**
 * Status, time, headers and formatted body, in full and without interpretation (UC04 step 7, A2),
 * and the equivalent curl command with a credential placeholder (spec FR-031).
 */
export function ResponsePanel({ request, response }: { request: TestRequest; response: ExecuteResponse }) {
  const [copied, setCopied] = useState(false);
  const body = format(response);
  return (
    <div className="rresponse" data-testid="rest-response">
      <div className="field">
        <span className="field-k">Status</span>
        <span className="field-v num" data-testid="rest-status">
          {response.status}
        </span>
      </div>
      <div className="field">
        <span className="field-k">Time</span>
        <span className="field-v num" data-testid="rest-time">
          {response.elapsedMs} ms
        </span>
      </div>
      <div className="field">
        <span className="field-k">Served by</span>
        <span className="field-v mono">
          {response.resolved.webApplication} · {response.resolved.dispatchClass}
        </span>
      </div>
      <div className="field">
        <span className="field-k">Roles</span>
        <span className="field-v">{response.rolesMode === "current-kept" ? "Your roles, as a real call to this application gets them" : "Your login roles only"}</span>
      </div>
      {response.grantsNotApplied.length > 0 && (
        <p className="lgroup-reason" data-testid="rest-roles-note">
          This application grants roles to real calls ({response.grantsNotApplied.join(", ")}). Test requests run with your login roles, so the result can differ from a real call.
        </p>
      )}
      <div className="sop-k">Headers</div>
      <div data-testid="rest-headers-out">
        {Object.entries(response.headers).map(([k, v]) => (
          <div className="field" key={k}>
            <span className="field-k mono">{k}</span>
            <span className="field-v mono">{v}</span>
          </div>
        ))}
      </div>
      <div className="sop-k">
        Body · <span className="num">{response.bodySize}</span> bytes{response.truncated ? ", showing the first 1 MB" : ""}
      </div>
      <pre className="rbody mono" data-testid="rest-body-out">
        {body}
      </pre>
      <div className="actions">
        <button
          type="button"
          className="btn"
          data-testid="rest-copy-curl"
          onClick={() => {
            void navigator.clipboard.writeText(curl(request)).then(() => setCopied(true));
          }}
        >
          Copy as curl
        </button>
        {copied && <span role="status">Copied. Replace &lt;user&gt;:&lt;password&gt; before running it.</span>}
      </div>
    </div>
  );
}

function format(response: ExecuteResponse): string {
  if (response.contentType?.includes("json")) {
    try {
      return JSON.stringify(JSON.parse(response.body), null, 2);
    } catch {
      return response.body;
    }
  }
  return response.body;
}

/** The equivalent request against this instance's own base URL. Never contains a credential. */
export function curl(request: TestRequest, origin = window.location.origin): string {
  const query = new URLSearchParams(request.query ?? {}).toString();
  const url = `${origin}${request.path}${query ? (request.path.includes("?") ? "&" : "?") + query : ""}`;
  const quote = (s: string) => `'${s.replace(/'/g, "'\\''")}'`;
  const parts = ["curl", "-X", request.method, "-u", quote("<user>:<password>")];
  for (const [k, v] of Object.entries(request.headers ?? {})) parts.push("-H", quote(`${k}: ${v}`));
  if (request.body) parts.push("--data", quote(request.body));
  parts.push(quote(url));
  return parts.join(" ");
}
