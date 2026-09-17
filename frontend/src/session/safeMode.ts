// Safe mode for this browser tab (Constitution IV, RN-FD-03, research R6).
// Held in module memory only: never in storage, cookies, URL or history state. A reload, a new tab
// or a duplicated tab re-runs this module and therefore always starts armed.
import { useSyncExternalStore } from "react";

export type SafeMode = "armed" | "disarmed";

let state: SafeMode = "armed";
const listeners = new Set<() => void>();

/** Random id for this tab, sent with every API request. Memory only. */
export const tabId: string =
  typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `tab-${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;

export function getSafeMode(): SafeMode {
  return state;
}

function set(next: SafeMode): void {
  if (state === next) return;
  state = next;
  listeners.forEach((l) => l());
}

export function arm(): void {
  set("armed");
}

export function disarm(): void {
  set("disarmed");
}

export function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useSafeMode(): SafeMode {
  return useSyncExternalStore(subscribe, getSafeMode, getSafeMode);
}
