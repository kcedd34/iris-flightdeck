import { useMemo, useState } from "react";
import type { SpecificationResponse } from "../../api/types";
import { normalize, type OperationView, type SchemaView } from "./openapi";

/** The specification grouped by path and method, with parameters and schemas (UC04 step 4). */
export function SpecificationViewer({ specification, onTry }: { specification: SpecificationResponse; onTry: (operation: OperationView, basePath: string) => void }) {
  const spec = useMemo(() => (specification.document ? normalize(specification.document) : null), [specification]);
  if (specification.format === "routes") {
    return (
      <section className="sect" aria-label="Routes the platform reports" data-testid="rest-routes">
        <div className="sect-h">Routes the platform reports (no specification)</div>
        <p className="lgroup-reason">The platform generates this list from the dispatch class. It has no parameters or schemas, so it is not a specification.</p>
        {(specification.routes ?? []).map((r) => (
          <div className="field" key={`${r.method} ${r.path}`}>
            <span className="field-k mono">{r.method}</span>
            <span className="field-v mono">{r.path}</span>
          </div>
        ))}
      </section>
    );
  }
  if (!spec) return null;
  return (
    <section className="sect" aria-label="Specification" data-testid="rest-specification">
      <div className="sect-h">
        {spec.title || "Specification"} {spec.version && <span className="mono">{spec.version}</span>} · {spec.format === "openapi-3.0" ? "OpenAPI 3.0" : "OpenAPI 2.0"}
      </div>
      {spec.paths.map((group) => (
        <div key={group.path} className="spath">
          <div className="spath-h mono">{group.path}</div>
          {group.operations.map((op) => (
            <Operation key={op.method} operation={op} onTry={() => onTry(op, spec.basePath)} />
          ))}
        </div>
      ))}
    </section>
  );
}

function Operation({ operation, onTry }: { operation: OperationView; onTry: () => void }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="sop" data-testid="rest-operation">
      <button type="button" className="link sop-h" aria-expanded={open} onClick={() => setOpen((v) => !v)}>
        <span className="mono sop-method">{operation.method}</span>
        <span>{operation.summary || operation.operationId || operation.path}</span>
      </button>
      {open && (
        <div className="sop-b">
          {operation.description && <p className="lgroup-reason">{operation.description}</p>}
          {operation.parameters.length > 0 && (
            <div>
              <div className="sop-k">Parameters</div>
              {operation.parameters.map((p) => (
                <div className="field" key={`${p.in}:${p.name}`}>
                  <span className="field-k mono">{p.name}</span>
                  <span className="field-v">
                    {p.in}
                    {p.required ? ", required" : ""} · <span className="mono">{p.schema.type}</span>
                    {p.description && <> · {p.description}</>}
                  </span>
                </div>
              ))}
            </div>
          )}
          {operation.requestBody && (
            <div>
              <div className="sop-k">Request body · {operation.requestBody.contentType}</div>
              <SchemaTree schema={operation.requestBody.schema} />
            </div>
          )}
          <div className="sop-k">Responses</div>
          {operation.responses.map((r) => (
            <div key={r.status}>
              <div className="field">
                <span className="field-k mono">{r.status}</span>
                <span className="field-v">{r.description}</span>
              </div>
              {r.schema && <SchemaTree schema={r.schema} />}
            </div>
          ))}
          <div className="actions">
            <button type="button" className="btn" onClick={onTry}>
              Try it
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function SchemaTree({ schema, name }: { schema: SchemaView; name?: string }) {
  const children = schema.properties ? Object.entries(schema.properties) : [];
  return (
    <div className="stree">
      <span className="mono">
        {name && <>{name}: </>}
        {schema.type}
        {schema.type === "array" && schema.items ? ` of ${schema.items.type}` : ""}
        {schema.ref ? ` (${schema.ref.split("/").pop()}, recursive)` : ""}
        {schema.enum ? ` ${schema.enum.map(String).join(" | ")}` : ""}
      </span>
      {children.length > 0 && (
        <div className="stree-c">
          {children.map(([key, child]) => (
            <SchemaTree key={key} name={`${key}${schema.required?.includes(key) ? "*" : ""}`} schema={child} />
          ))}
        </div>
      )}
      {schema.type === "array" && schema.items?.properties && (
        <div className="stree-c">
          <SchemaTree schema={schema.items} name="item" />
        </div>
      )}
    </div>
  );
}
