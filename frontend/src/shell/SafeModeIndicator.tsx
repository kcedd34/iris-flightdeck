import { SafeModeControl } from "../session/SafeModeControl";
import { useSafeMode } from "../session/safeMode";

/**
 * Persistent safe-mode annunciator (FR-030). Wording and geometry follow docs/prototype.html,
 * which prevails over design §4's text for this component: "Safe mode" / "Live — changes enabled",
 * plus a full-width 2px warning rule on the glareshield when disarmed. Icon (dot) and text, never
 * color alone.
 */
export function SafeModeIndicator() {
  const mode = useSafeMode();
  const live = mode === "disarmed";
  return (
    <>
      <SafeModeControl>
        <button
          className="mode"
          type="button"
          data-mode={mode}
          data-testid="safe-mode-indicator"
          aria-label={live ? "Live: changes enabled in this tab. Turn safe mode back on" : "Safe mode is on. Turn off safe mode"}
        >
          <span className="mode-dot" aria-hidden="true" />
          <span aria-live="polite">{live ? "Live — changes enabled" : "Safe mode"}</span>
        </button>
      </SafeModeControl>
      <div className="livebar" data-on={live} aria-hidden="true" />
    </>
  );
}
