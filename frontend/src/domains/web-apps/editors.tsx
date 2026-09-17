import type { FieldEditorProps } from "../../pattern/ObjectForm";
import { AUTHENTICATION_BITS } from "../presentation";

/** AutheEnabled as labeled checkboxes over the official bit mask (schema description). */
export function AuthenticationEditor({ value, readOnly, onChange }: FieldEditorProps) {
  const mask = Number(value) || 0;
  return (
    <span className="oform-checks" id="f-AutheEnabled" role="group" aria-label="Authentication methods">
      {AUTHENTICATION_BITS.map(([bit, label]) => (
        <label key={bit}>
          <input type="checkbox" checked={(mask & bit) === bit} disabled={readOnly} onChange={(e) => onChange(e.target.checked ? mask | bit : mask & ~bit)} />
          {label}
        </label>
      ))}
    </span>
  );
}

type MatchRole = { MatchRole: string; TargetRoles: string[] };

/** MatchRoles as rows: role to match (empty means always) and the target roles granted. */
export function MatchRolesEditor({ value, readOnly, onChange }: FieldEditorProps) {
  const rows: MatchRole[] = Array.isArray(value) ? (value as MatchRole[]) : [];
  const update = (next: MatchRole[]) => onChange(next);
  return (
    <span className="oform-rows" id="f-MatchRoles">
      {rows.map((row, i) => (
        <span className="oform-row" key={i}>
          <input
            type="text"
            aria-label="Match role (empty: always)"
            placeholder="always"
            value={row.MatchRole}
            readOnly={readOnly}
            onChange={(e) => update(rows.map((r, j) => (j === i ? { ...r, MatchRole: e.target.value } : r)))}
          />
          <input
            type="text"
            aria-label="Target roles"
            value={row.TargetRoles.join(", ")}
            readOnly={readOnly}
            onChange={(e) => update(rows.map((r, j) => (j === i ? { ...r, TargetRoles: e.target.value.split(",").map((v) => v.trim()).filter(Boolean) } : r)))}
          />
          {!readOnly && (
            <button className="btn" type="button" onClick={() => update(rows.filter((_, j) => j !== i))}>
              Remove
            </button>
          )}
        </span>
      ))}
      {!readOnly && (
        <button className="btn" type="button" onClick={() => update([...rows, { MatchRole: "", TargetRoles: [] }])}>
          Add match role
        </button>
      )}
    </span>
  );
}
