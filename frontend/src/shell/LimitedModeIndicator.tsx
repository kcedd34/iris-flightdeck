import { useId } from "react";

/**
 * Limited-mode annunciator (FR-012a): shown while the capability map holds operations the instance
 * does not offer (`available: false`). It never asks which API version the instance speaks; each
 * disabled operation carries its own reason. Persistent while the session lasts, next to the
 * instance identity it qualifies. Icon and text, never color alone.
 */
export function LimitedModeIndicator({ unavailable, total }: { unavailable: number; total: number }) {
  const descriptionId = useId();
  const description = `${unavailable} of ${total} operations are not offered by this IRIS version and are shown disabled, each with its reason.`;
  return (
    <span className="limited-mode" role="status" tabIndex={0} title={description} aria-describedby={descriptionId} data-testid="limited-mode-indicator">
      <span className="limited-mode-mark" aria-hidden="true">
        !
      </span>
      <span>Limited</span>
      <span id={descriptionId} className="visually-hidden">
        {description}
      </span>
    </span>
  );
}
