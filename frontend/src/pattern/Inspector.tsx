import type { ReactNode } from "react";
import type { Marker } from "../api/types";
import { MarkerTag } from "./MarkerTag";

export interface InspectorField {
  label: string;
  value: ReactNode;
  mono?: boolean;
  numeric?: boolean;
}

export interface InspectorSection {
  title: string;
  fields: InspectorField[];
}

interface Props {
  title: string;
  subtitle?: string;
  markers?: Marker[];
  loading?: boolean;
  error?: string | null;
  sections: InspectorSection[];
  canGoBack: boolean;
  onBack: () => void;
  onClose: () => void;
  /** Rendered right after the first section (links and actions stay within reach). */
  afterFirst?: ReactNode;
  children?: ReactNode;
}

/** The inspector half of the domain pattern: fixed 96px label column, detail never navigates away. */
export function Inspector(props: Props) {
  return (
    <div className="pinspector" data-testid="entity-inspector">
      <div className="pinspector-nav">
        {props.canGoBack && (
          <button className="btn" type="button" onClick={props.onBack}>
            Back
          </button>
        )}
        <button className="btn pinspector-close" type="button" onClick={props.onClose} aria-label="Close inspector">
          Close
        </button>
      </div>
      <h2 className="mono">{props.title}</h2>
      <div className="inspector-sub">
        {props.subtitle}
        {props.markers && props.markers.length > 0 && (
          <span className="pinspector-markers">
            {props.markers.map((m) => (
              <MarkerTag key={m.id} marker={m} />
            ))}
          </span>
        )}
      </div>
      {props.error ? (
        <div className="dlist-error" role="alert">
          {props.error}
        </div>
      ) : props.loading ? (
        <div aria-busy="true">
          {[0, 1, 2, 3].map((i) => (
            <div key={i} className="field" aria-hidden="true">
              <span className="field-k skeleton" />
              <span className="field-v skeleton" />
            </div>
          ))}
        </div>
      ) : (
        <>
          {props.sections.map((section, index) => (
            <div key={section.title}>
              <section className={index === 0 ? "psect-first" : "sect"} aria-label={section.title}>
                {index > 0 && <div className="sect-h">{section.title}</div>}
                {section.fields.map((field) => (
                  <div className="field" key={field.label}>
                    <span className="field-k">{field.label}</span>
                    <span className={`field-v${field.mono ? " mono" : ""}${field.numeric ? " num" : ""}`}>{field.value}</span>
                  </div>
                ))}
              </section>
              {index === 0 && props.afterFirst}
            </div>
          ))}
          {props.sections.length === 0 && props.afterFirst}
          {props.children}
        </>
      )}
    </div>
  );
}
