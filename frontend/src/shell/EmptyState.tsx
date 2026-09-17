import type { ReactNode } from "react";

interface Props {
  title: string;
  /** Probable cause. Required: an empty state never just says "nothing here" (design §7). */
  cause: string;
  /** Next action, as a sentence and optionally a button. Required. */
  nextAction: string;
  action?: ReactNode;
}

export function EmptyState({ title, cause, nextAction, action }: Props) {
  if (import.meta.env.DEV && (!cause.trim() || !nextAction.trim())) {
    throw new Error("EmptyState requires a cause and a next action");
  }
  return (
    <div className="empty" role="status">
      <div className="empty-t">{title}</div>
      <div className="empty-d">
        {cause} {nextAction}
      </div>
      {action}
    </div>
  );
}
