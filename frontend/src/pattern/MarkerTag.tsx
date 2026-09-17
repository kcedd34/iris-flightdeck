import type { Marker } from "../api/types";

/**
 * A marker from the server: icon plus text, never color alone (docs/design.md §7, research R10).
 * Warning is a filled triangle, caution an outlined one, neutral has no glyph.
 */
export function MarkerTag({ marker }: { marker: Marker }) {
  return (
    <span className={`marker marker-${marker.tone}`} data-testid={`marker-${marker.id}`}>
      {marker.tone === "warning" && (
        <svg className="glyph" viewBox="0 0 10 10" fill="currentColor" aria-hidden="true">
          <path d="M5 0l5 9H0z" />
        </svg>
      )}
      {marker.tone === "caution" && (
        <svg className="glyph" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.2" aria-hidden="true">
          <path d="M5 1.2l4 7.2H1z" />
        </svg>
      )}
      <span>{marker.text}</span>
    </span>
  );
}
