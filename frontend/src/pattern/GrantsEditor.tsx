import type { FieldEditorProps } from "./ObjectForm";

type Grant = { Name: string; Permissions: string };

/**
 * A role's resource grants as rows: the resource and the permissions the official API reports
 * (for example `RW`). Shared by the pattern because every domain that grants a resource uses the
 * same official shape.
 */
export function GrantsEditor({ field, value, readOnly, onChange }: FieldEditorProps) {
  const rows: Grant[] = Array.isArray(value) ? (value as Grant[]) : [];
  const update = (next: Grant[]) => onChange(next);
  return (
    <span className="oform-rows" id={`f-${field.name}`}>
      {rows.map((row, i) => (
        <span className="oform-row" key={i}>
          <input
            type="text"
            aria-label="Resource"
            value={row.Name}
            readOnly={readOnly}
            onChange={(e) => update(rows.map((r, j) => (j === i ? { ...r, Name: e.target.value } : r)))}
          />
          <input
            type="text"
            aria-label="Permissions"
            placeholder="RWU"
            value={row.Permissions}
            readOnly={readOnly}
            onChange={(e) => update(rows.map((r, j) => (j === i ? { ...r, Permissions: e.target.value.toUpperCase() } : r)))}
          />
          {!readOnly && (
            <button type="button" className="btn" onClick={() => update(rows.filter((_, j) => j !== i))}>
              Remove
            </button>
          )}
        </span>
      ))}
      {!readOnly && (
        <button type="button" className="btn" onClick={() => update([...rows, { Name: "", Permissions: "" }])}>
          Add resource
        </button>
      )}
    </span>
  );
}
