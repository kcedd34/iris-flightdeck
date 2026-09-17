// Session trail store (RN-FD-27, feature 002 spec FR-014, FR-015). Internal to src/mutation: other
// modules use the public surface re-exported by useMutation.ts and TrailPanel.tsx
// (check:mutation-boundary).
//
// Kept in this tab's sessionStorage (never localStorage): it survives a reload of the tab and dies
// with the tab. Cleared explicitly at sign-out and when session expiry is detected. Records come
// only from the server's preview/apply responses, already masked (Constitution VI): this store never
// decides what is secret.
import { useSyncExternalStore } from "react";
import type { TrailRecord } from "../api/types";

export const TRAIL_KEY = "flightdeck.trail.v1";
export const TRAIL_NOTICE = "This trail is local to this browser tab and does not replace IRIS auditing.";
export const TRAIL_CAP = 500;

export interface TrailDocument {
  version: 1;
  notice: string;
  entries: TrailRecord[];
  dropped: number;
}

export interface TrailSnapshot {
  document: TrailDocument;
  /** False when session storage is unavailable: the trail lives in memory and a reload loses it. */
  persistent: boolean;
}

const empty = (): TrailDocument => ({ version: 1, notice: TRAIL_NOTICE, entries: [], dropped: 0 });

let memory: TrailDocument | null = null;
let persistent = true;
let snapshot: TrailSnapshot | null = null;
const listeners = new Set<() => void>();

function storage(): Storage | null {
  try {
    return typeof window !== "undefined" ? window.sessionStorage : null;
  } catch {
    return null;
  }
}

function load(): TrailDocument {
  if (memory) return memory;
  const store = storage();
  if (store) {
    try {
      const raw = store.getItem(TRAIL_KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as TrailDocument;
        if (parsed && parsed.version === 1 && Array.isArray(parsed.entries)) {
          memory = { ...parsed, notice: TRAIL_NOTICE };
          return memory;
        }
      }
    } catch {
      persistent = false;
    }
  } else {
    persistent = false;
  }
  memory = empty();
  return memory;
}

function save(next: TrailDocument): void {
  memory = next;
  const store = storage();
  if (!store) {
    persistent = false;
  } else {
    try {
      if (next.entries.length === 0 && next.dropped === 0) store.removeItem(TRAIL_KEY);
      else store.setItem(TRAIL_KEY, JSON.stringify(next));
      persistent = true;
    } catch {
      persistent = false;
    }
  }
  snapshot = null;
  listeners.forEach((l) => l());
}

/** Appends a server-produced record. Oldest entries are dropped past the cap, and counted. */
export function appendTrail(record: TrailRecord): void {
  const current = load();
  const entries = [...current.entries, record];
  const overflow = Math.max(0, entries.length - TRAIL_CAP);
  save({ ...current, entries: entries.slice(overflow), dropped: current.dropped + overflow });
}

export function clearTrail(): void {
  save(empty());
}

export function getTrail(): TrailSnapshot {
  if (!snapshot) {
    const document = load();
    snapshot = { document, persistent };
  }
  return snapshot;
}

export function subscribeTrail(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useTrail(): TrailSnapshot {
  return useSyncExternalStore(subscribeTrail, getTrail, getTrail);
}

/** The export document (spec FR-015): the trail as stored, pretty-printed, with its file name. */
export function exportTrail(now = new Date()): { fileName: string; text: string } {
  return {
    fileName: `flightdeck-trail-${now.toISOString().replace(/[:.]/g, "-")}.json`,
    text: JSON.stringify(getTrail().document, null, 2),
  };
}

/** Test hook: forget the in-memory copy so the next read goes to storage again. */
export function resetTrailMemoryForTests(): void {
  memory = null;
  snapshot = null;
  persistent = true;
}
