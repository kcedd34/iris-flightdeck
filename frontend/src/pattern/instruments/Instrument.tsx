import { Series } from "./Series";

export type Band = "normal" | "caution" | "warning";

export interface InstrumentReading {
  id: string;
  label: string;
  unit: string;
  value: number | null;
  band: Band;
  scope?: string | null;
  available: boolean;
  reason?: string | null;
  detail?: string | null;
  async?: { state: string; lastValueAt: string | null; stale: boolean; message: string | null };
}

function Glyph({ band }: { band: Band }) {
  if (band === "normal") return null;
  return (
    <svg className="glyph" viewBox="0 0 10 10" fill="currentColor" aria-hidden="true">
      <path d="M5 0l5 9H0z" />
    </svg>
  );
}

/**
 * One instrument: a large number, then the series (docs/design.md §5).
 *
 * The number is the primary reading; the series is the secondary one. A crossed threshold changes
 * the number's colour and adds the glyph — it never blinks and never animates (spec FR-017).
 *
 * An unavailable instrument keeps its place in the row with its reason, so the cluster keeps its
 * geometry and the others keep updating (spec FR-021).
 */
export function Instrument({ reading, points, reducedMotion }: { reading: InstrumentReading; points: number[]; reducedMotion: boolean }) {
  const { async: asyncState } = reading;
  const unavailable = !reading.available;
  const value = reading.value;
  return (
    <div className="ins" data-testid={`instrument-${reading.id}`} data-band={reading.band} data-available={reading.available}>
      <div className="ins-k">{reading.label}</div>
      <div className="ins-v num" data-testid={`instrument-value-${reading.id}`}>
        {unavailable || value === null ? (
          <span className="ins-absent">—</span>
        ) : (
          <>
            <Glyph band={reading.band} />
            {Math.round(value)}
            <span className="ins-u">{reading.unit}</span>
          </>
        )}
      </div>
      {unavailable ? (
        <div className="ins-reason" data-testid={`instrument-reason-${reading.id}`}>
          {reading.reason ?? "Not available on this instance."}
        </div>
      ) : (
        <>
          <Series points={points} label={`${reading.label} over the last ${points.length} readings`} reducedMotion={reducedMotion} />
          <div className="ins-d">
            {reading.detail ?? reading.scope ?? ""}
            {/* A value that arrives asynchronously says how old it is; the number itself stays put. */}
            {asyncState?.stale && (
              <span className="ins-stale" data-testid={`instrument-stale-${reading.id}`}>
                {asyncState.lastValueAt ? ` · read ${asyncState.lastValueAt}` : " · refreshing"}
              </span>
            )}
          </div>
          {asyncState?.message && (
            <div className="ins-msg" data-testid={`instrument-message-${reading.id}`}>
              {asyncState.message}
            </div>
          )}
        </>
      )}
    </div>
  );
}
