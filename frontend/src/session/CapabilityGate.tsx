import { cloneElement, isValidElement, useId, type ReactElement } from "react";
import { useCapability } from "./SessionProvider";
import "./safemode.css";

/**
 * Renders its control disabled with the reason when the derived capability map says the user
 * cannot run the operation (FR-014), or the instance does not offer it (FR-012a limited mode).
 * The control is never hidden.
 */
export function CapabilityGate({ operationId, children }: { operationId: string; children: ReactElement<Record<string, unknown>> }) {
  const capability = useCapability(operationId);
  const reasonId = useId();
  if (!isValidElement(children)) return null;
  if (!capability || (capability.available && capability.allowed)) return children;
  return (
    <span className="capability-gate">
      {cloneElement(children, {
        "aria-disabled": true,
        "aria-describedby": reasonId,
        onClick: (e: Event) => e.preventDefault(),
        title: capability.reason ?? undefined,
      })}
      <span id={reasonId} className="capability-reason">
        {capability.reason}
      </span>
    </span>
  );
}
