import { useState, type ReactNode } from "react";
import type { SchemaField } from "../domains/generated/schemas";
import { humanize } from "../domains/presentation";
import { disarm, useSafeMode } from "../session/safeMode";

export interface FieldEditorProps {
  field: SchemaField;
  value: unknown;
  readOnly: boolean;
  onChange: (value: unknown) => void;
}

interface Props {
  title: string;
  fields: readonly SchemaField[];
  sections: { title: string; fields: string[] }[];
  initial: Record<string, unknown>;
  /** Fields shown but never editable (identity keys on edit). */
  readOnlyFields?: string[];
  editors?: Record<string, (props: FieldEditorProps) => ReactNode>;
  submitLabel: string;
  error: string | null;
  busy: boolean;
  onSubmit: (values: Record<string, unknown>) => void;
  onCancel: () => void;
}

/**
 * Schema-driven form of the domain pattern: one control per official field, typed from the
 * generated schema. While safe mode is armed the fields are read-only and disarming is offered
 * (UC03 A1). Submitting never writes: it opens the shared dry-run through the domain's callback.
 */
export function ObjectForm(props: Props) {
  const safeMode = useSafeMode();
  const armed = safeMode === "armed";
  const [values, setValues] = useState<Record<string, unknown>>(props.initial);
  const byName = new Map(props.fields.map((f) => [f.name, f]));
  return (
    <form
      className="oform"
      data-testid="object-form"
      onSubmit={(e) => {
        e.preventDefault();
        if (!armed) props.onSubmit(values);
      }}
    >
      <h2>{props.title}</h2>
      {armed && (
        <div className="oform-armed" role="status">
          <span>Safe mode is on. Turn it off to make changes in this tab.</span>
          <button className="btn" type="button" onClick={disarm}>
            Turn off safe mode
          </button>
        </div>
      )}
      {props.error && (
        <div className="dlist-error" role="alert" data-testid="form-error">
          {props.error}
        </div>
      )}
      {props.sections.map((section) => (
        <fieldset key={section.title} className="oform-section">
          <legend className="sect-h">{section.title}</legend>
          {section.fields.map((name) => {
            const field = byName.get(name);
            if (!field) return null;
            const readOnly = armed || (props.readOnlyFields ?? []).includes(name);
            const onChange = (value: unknown) => setValues((v) => ({ ...v, [name]: value }));
            const custom = props.editors?.[name];
            return (
              <div className="field oform-field" key={name}>
                <label className="field-k" htmlFor={`f-${name}`}>
                  {humanize(name)}
                </label>
                <span className="field-v">{custom ? custom({ field, value: values[name], readOnly, onChange }) : <DefaultEditor field={field} value={values[name]} readOnly={readOnly} onChange={onChange} />}</span>
              </div>
            );
          })}
        </fieldset>
      ))}
      <div className="actions">
        <button className="btn" type="button" onClick={props.onCancel}>
          Cancel
        </button>
        <button className="btn btn-primary" type="submit" disabled={armed || props.busy} data-testid="form-submit">
          {props.submitLabel}
        </button>
      </div>
    </form>
  );
}

function DefaultEditor({ field, value, readOnly, onChange }: FieldEditorProps) {
  const id = `f-${field.name}`;
  if (field.type === "boolean") {
    return <input id={id} type="checkbox" checked={Boolean(value)} disabled={readOnly} onChange={(e) => onChange(e.target.checked)} />;
  }
  if (field.enum) {
    return (
      <select id={id} value={String(value ?? "")} disabled={readOnly} onChange={(e) => onChange(e.target.value)}>
        <option value="">—</option>
        {field.enum.map((option) => (
          <option key={option} value={option}>
            {option}
          </option>
        ))}
      </select>
    );
  }
  if (field.type === "integer" || field.type === "number") {
    return <input id={id} type="text" inputMode="numeric" value={value === undefined || value === null ? "" : String(value)} readOnly={readOnly} onChange={(e) => onChange(e.target.value === "" ? "" : /^-?\d+(\.\d+)?$/.test(e.target.value) ? Number(e.target.value) : e.target.value)} />;
  }
  if (field.type === "array<string>") {
    return <input id={id} type="text" value={Array.isArray(value) ? value.join(", ") : ""} readOnly={readOnly} onChange={(e) => onChange(e.target.value.split(",").map((v) => v.trim()).filter(Boolean))} />;
  }
  if (field.type === "string") {
    return <input id={id} type="text" value={String(value ?? "")} readOnly={readOnly} onChange={(e) => onChange(e.target.value)} />;
  }
  return <JsonEditor id={id} value={value} readOnly={readOnly} onChange={onChange} />;
}

function JsonEditor({ id, value, readOnly, onChange }: { id: string; value: unknown; readOnly: boolean; onChange: (value: unknown) => void }) {
  const [text, setText] = useState(JSON.stringify(value ?? null));
  return (
    <textarea
      id={id}
      className="mono"
      value={text}
      readOnly={readOnly}
      onChange={(e) => {
        setText(e.target.value);
        try {
          onChange(JSON.parse(e.target.value));
        } catch {
          onChange(e.target.value);
        }
      }}
    />
  );
}

/** Fields whose value differs from the original (JSON comparison). */
export function changedFields(original: Record<string, unknown>, values: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(values)) {
    if (JSON.stringify(value) !== JSON.stringify(original[key])) out[key] = value;
  }
  return out;
}

/**
 * Editor for a descriptor-declared secret field (Constitution VI). The current value is never sent
 * to the browser, so the control starts empty; leaving it empty proposes no change, and the dry run
 * reports only changed or unchanged.
 */
export function SecretEditor({ field, value, readOnly, onChange }: FieldEditorProps) {
  return (
    <input
      id={`f-${field.name}`}
      type="password"
      autoComplete="new-password"
      value={typeof value === "string" ? value : ""}
      readOnly={readOnly}
      placeholder="Unchanged"
      onChange={(e) => onChange(e.target.value === "" ? undefined : e.target.value)}
    />
  );
}
