import * as Popover from "@radix-ui/react-popover";
import { useState, type ReactNode } from "react";
import { arm, disarm, useSafeMode } from "./safeMode";
import "./safemode.css";

/**
 * Turning safe mode off takes one explicit confirmation; turning it on is immediate.
 * The state belongs to this tab only (Constitution IV).
 */
export function SafeModeControl({ children }: { children: ReactNode }) {
  const mode = useSafeMode();
  const [open, setOpen] = useState(false);

  if (mode === "disarmed") {
    return (
      <span onClick={() => arm()} onKeyDown={(e) => (e.key === "Enter" || e.key === " ") && arm()}>
        {children}
      </span>
    );
  }
  return (
    <Popover.Root open={open} onOpenChange={setOpen}>
      <Popover.Trigger asChild>{children}</Popover.Trigger>
      <Popover.Portal>
        <Popover.Content className="float safemode-pop" align="end" sideOffset={8}>
          <div className="safemode-pop-title">Turn off safe mode?</div>
          <p className="safemode-pop-body">Changes will be allowed in this tab only. Other tabs stay in safe mode.</p>
          <div className="safemode-pop-actions">
            <Popover.Close className="btn">Cancel</Popover.Close>
            <button
              className="btn btn-primary"
              type="button"
              onClick={() => {
                disarm();
                setOpen(false);
              }}
            >
              Turn off safe mode
            </button>
          </div>
        </Popover.Content>
      </Popover.Portal>
    </Popover.Root>
  );
}
