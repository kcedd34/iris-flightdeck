import type { LogEvent } from "../../api/types";

/** The ordered part of the scale. `unknown` is deliberately not here (feature 005 spec FR-003a). */
export const ORDERED: LogEvent["severity"][] = ["info", "warning", "error", "fatal"];

export function rank(severity: LogEvent["severity"]): number | null {
  const index = ORDERED.indexOf(severity);
  return index < 0 ? null : index + 1;
}

/** The token a severity paints with. `unknown` takes the muted tone: it is an absence of statement,
 *  not a level, and it must not look like an alarm or like "fine". */
export function tone(severity: LogEvent["severity"]): string {
  return severity === "fatal" || severity === "error" ? "warning" : severity === "warning" ? "caution" : severity === "info" ? "actual" : "absent";
}
