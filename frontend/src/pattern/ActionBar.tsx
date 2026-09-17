import { useId } from "react";
import type { MutationCapability } from "../api/types";
import { useSafeMode } from "../session/safeMode";

const SAFE_MODE_MESSAGE = "Safe mode is on. Turn it off to make changes in this tab.";

export interface ActionDef {
  operationId: string;
  label: string;
  mutating: boolean;
  /** Self-protection known at render time (contracts/ui-pattern.md §3); the server re-checks. */
  blockedMessage?: string | null;
  /** An object capability field the API declares false (Constitution IX). */
  refusedByObject?: string | null;
  onActivate: () => void;
}

/**
 * The action bar of the domain pattern. State precedence (contracts/ui-pattern.md §3): available,
 * allowed, object capability, self-protection, safe mode. Controls are never hidden.
 */
export function ActionBar({ actions, capabilities }: { actions: ActionDef[]; capabilities: MutationCapability[] }) {
  const safeMode = useSafeMode();
  return (
    <div className="actions" role="group" aria-label="Actions">
      {actions.map((action) => (
        <Action key={`${action.operationId}:${action.label}`} action={action} capability={capabilities.find((c) => c.operationId === action.operationId)} armed={safeMode === "armed"} />
      ))}
    </div>
  );
}

function Action({ action, capability, armed }: { action: ActionDef; capability: MutationCapability | undefined; armed: boolean }) {
  const reasonId = useId();
  let reason: string | null = null;
  if (capability && !capability.available) reason = capability.reason;
  else if (capability && !capability.allowed) reason = capability.reason;
  else if (action.refusedByObject) reason = action.refusedByObject;
  else if (action.blockedMessage) reason = action.blockedMessage;
  const disabled = reason !== null;
  const note = !disabled && action.mutating && armed ? SAFE_MODE_MESSAGE : null;
  const testId = `action-${action.operationId.replace(/[^A-Za-z0-9]+/g, "-")}-${action.label.toLowerCase().replace(/\s+/g, "-")}`;
  return (
    <span className="action">
      <button
        type="button"
        className="btn"
        aria-disabled={disabled ? "true" : undefined}
        aria-describedby={reason || note ? reasonId : undefined}
        onClick={() => {
          if (!disabled) action.onActivate();
        }}
        data-testid={testId}
      >
        {action.label}
      </button>
      {(reason || note) && (
        <span id={reasonId} className="action-reason">
          {reason ?? note}
        </span>
      )}
    </span>
  );
}
