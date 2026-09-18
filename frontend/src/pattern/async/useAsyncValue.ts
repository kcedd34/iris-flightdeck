import { useEffect, useRef, useState } from "react";
import { request } from "../../api/client";

/** The platform's own states, plus "idle" for a value never fired (feature 004 data-model §4.2). */
export type AsyncState = "idle" | "Queued" | "Running" | "Finished" | "Failed" | "Canceled" | "Paused";

export interface AsyncStatus {
  state: AsyncState;
  handle?: string | null;
  /** When the value on screen was read. Null until a value has ever arrived. */
  lastValueAt: string | null;
  /** True when the value is older than the interval it refreshes on. It stays on screen either way. */
  stale: boolean;
  /** The platform's own text, shown beside the value and never in its place. */
  message: string | null;
}

export const IN_FLIGHT: AsyncState[] = ["Queued", "Running", "Paused"];

export function inFlight(state: AsyncState): boolean {
  return IN_FLIGHT.includes(state);
}

/**
 * Keeps the last value that actually arrived.
 *
 * This is the whole point of the module: a refresh in flight never clears a number and never
 * replaces it with a loading indicator (RN-FD-32, spec FR-023). What changes while a refresh runs is
 * the staleness note beside the value, not the value.
 */
export function useRetainedValue<T>(incoming: T | null | undefined, freshAt: string | null, staleAfterMs: number): {
  value: T | undefined;
  lastValueAt: string | null;
  stale: boolean;
} {
  const held = useRef<{ value: T; at: string | null } | undefined>(undefined);
  if (incoming !== null && incoming !== undefined) held.current = { value: incoming, at: freshAt };
  const at = held.current?.at ?? null;
  const stale = at !== null && Date.now() - Date.parse(at) > staleAfterMs;
  return { value: held.current?.value, lastValueAt: at, stale };
}

interface AsyncAnswer<T> {
  state: AsyncState;
  handle: string | null;
  message: string | null;
  value: T | "";
  inFlight: boolean;
  timeFinished?: string;
}

/**
 * Follows one asynchronous platform operation FlightDeck fired, by its handle.
 *
 * Used by the long storage operations (compact, defragment, integrity check) and by the async
 * results section; the disk instrument gets its state inside the telemetry reading instead, because
 * the cluster answers in one request.
 */
export function useAsyncOperation<T>(handle: string | null, intervalMs = 2000): {
  value: T | undefined;
  status: AsyncStatus;
} {
  const [answer, setAnswer] = useState<AsyncAnswer<T> | null>(null);
  useEffect(() => {
    if (!handle) return;
    let live = true;
    let timer: number | undefined;
    const read = async () => {
      try {
        const next = await request<AsyncAnswer<T>>(`/async/${encodeURIComponent(handle)}`);
        if (!live) return;
        setAnswer(next);
        if (next.inFlight) timer = window.setTimeout(read, intervalMs);
      } catch (error) {
        if (!live) return;
        // A read that fails leaves the last state and value where they are, with the reason beside
        // them: the screen says what it knows, and says what it could not read.
        setAnswer((previous) => ({
          state: previous?.state ?? "Failed",
          handle,
          message: error instanceof Error ? error.message : String(error),
          value: previous?.value ?? "",
          inFlight: false,
        }));
      }
    };
    void read();
    return () => {
      live = false;
      if (timer) window.clearTimeout(timer);
    };
  }, [handle, intervalMs]);

  const retained = useRetainedValue<T>(
    answer && answer.value !== "" ? (answer.value as T) : null,
    answer?.timeFinished ?? null,
    intervalMs * 3,
  );
  return {
    value: retained.value,
    status: {
      state: answer?.state ?? "idle",
      handle,
      lastValueAt: retained.lastValueAt,
      stale: retained.stale,
      message: answer?.message || null,
    },
  };
}
