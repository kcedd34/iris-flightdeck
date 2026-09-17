import { useId } from "react";

/**
 * Limited-mode annunciator (FR-012a): the instance exposes only SysAdmin API v1 (IRIS 2026.1).
 * Operations without a v1 route are shown disabled with the version message. Persistent while the
 * session lasts, next to the instance identity it qualifies. Icon and text, never color alone.
 */
export function LimitedModeIndicator({ unavailable, total }: { unavailable: number; total: number }) {
  const descriptionId = useId();
  const description = `This instance exposes SysAdmin API v1. ${unavailable} of ${total} operations are not offered by this IRIS version and are shown disabled. IRIS 2026.2 or later enables all of them.`;
  return (
    <span className="limited" role="status" tabIndex={0} title={description} aria-describedby={descriptionId} data-testid="limited-mode-indicator">
      <span className="limited-mark" aria-hidden="true">
        !
      </span>
      <span>Limited · API v1</span>
      <span id={descriptionId} className="visually-hidden">
        {description}
      </span>
    </span>
  );
}
