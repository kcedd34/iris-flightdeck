// The shared mutation layer in the client (Constitution V, feature 002 contracts/ui-pattern.md §4).
// Domains call start(); this module owns the dry-run, the confirmation and the trail. The server
// owns every decision (grade, masking, self-protection, concurrency); the client only presents it.
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { ApiError, request } from "../api/client";
import type { ApplyResponse, Keys, PreviewResponse, TestRequest, TrailRecord } from "../api/types";
import { useSession } from "../session/SessionProvider";
import { disarm, useSafeMode } from "../session/safeMode";
import { DryRun } from "./DryRun";
import { appendTrail, clearTrail } from "./trail";
import { TrailPanel } from "./TrailPanel";

export { clearTrail };

export const MUTATION_MESSAGES = {
  changed: "This object changed on the server while you were editing. Review the updated differences before applying.",
  noChange: "Nothing to apply. The proposed state matches the current one.",
  safeMode: "Safe mode is on. Turn it off to make changes in this tab.",
} as const;

export interface MutationStart {
  operationId: string;
  keys?: Keys;
  proposed?: Record<string, unknown>;
  request?: TestRequest;
  /** What the dry-run title calls the target, for example "web application". */
  noun: string;
}

export type MutationOutcome =
  | { status: "applied"; result: unknown; trail: TrailRecord }
  | { status: "rejected"; message: string; validation: boolean }
  | { status: "blocked"; message: string }
  | { status: "cancelled" };

export type Phase = "previewing" | "ready" | "applying" | "applied" | "failed" | "expired";

export interface DryRunState {
  start: MutationStart;
  phase: Phase;
  preview: PreviewResponse | null;
  /** A message shown above the diff: §9 17, 18, 4, 3, or a refusal. */
  message: string | null;
  confirmation: string;
  acknowledged: boolean;
  result: unknown;
}

interface MutationContextValue {
  start: (request: MutationStart) => Promise<MutationOutcome>;
  openTrail: () => void;
}

const MutationContext = createContext<MutationContextValue | null>(null);

export function MutationProvider({ children }: { children: ReactNode }) {
  const { computationEpoch } = useSession();
  const safeMode = useSafeMode();
  const [state, setState] = useState<DryRunState | null>(null);
  const [trailOpen, setTrailOpen] = useState(false);
  const resolver = useRef<((outcome: MutationOutcome) => void) | null>(null);
  const pendingOutcome = useRef<MutationOutcome | null>(null);
  const epoch = useRef(computationEpoch);
  // One Blocked record per requested mutation, however many times its preview is recomputed.
  const recordedBlocks = useRef(new WeakSet<MutationStart>());

  const runPreview = useCallback(async (start: MutationStart, message: string | null = null) => {
    setState((s) => ({ start, phase: "previewing", preview: s?.preview ?? null, message, confirmation: "", acknowledged: false, result: null }));
    try {
      const preview = await request<PreviewResponse>("/mutations/preview", {
        method: "POST",
        body: { operationId: start.operationId, keys: start.keys, proposed: start.proposed, request: start.request },
      });
      if (preview.blocked && preview.trail && !recordedBlocks.current.has(start)) {
        recordedBlocks.current.add(start);
        appendTrail(preview.trail);
        pendingOutcome.current = { status: "blocked", message: preview.blocked.message };
      }
      setState({ start, phase: "ready", preview, message: message ?? (preview.noChange ? MUTATION_MESSAGES.noChange : preview.blocked?.message ?? null), confirmation: "", acknowledged: false, result: null });
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        setState((s) => (s ? { ...s, phase: "expired" } : s));
        return;
      }
      const text = error instanceof ApiError ? error.message : "The server could not be reached.";
      setState({ start, phase: "failed", preview: null, message: text, confirmation: "", acknowledged: false, result: null });
    }
  }, []);

  const start = useCallback(
    (next: MutationStart) =>
      new Promise<MutationOutcome>((resolve) => {
        resolver.current?.({ status: "cancelled" });
        resolver.current = resolve;
        pendingOutcome.current = null;
        void runPreview(next);
      }),
    [runPreview],
  );

  // Session expiry and re-authentication share the concurrency path (RN-FD-31): after a new
  // computation epoch, an open dry-run is previewed again before anything can be applied.
  useEffect(() => {
    if (epoch.current === computationEpoch) return;
    epoch.current = computationEpoch;
    if (state && state.phase !== "applied") void runPreview(state.start);
  }, [computationEpoch, state, runPreview]);

  const close = useCallback(() => {
    const outcome = pendingOutcome.current ?? { status: "cancelled" as const };
    resolver.current?.(outcome);
    resolver.current = null;
    pendingOutcome.current = null;
    setState(null);
  }, []);

  const apply = useCallback(async () => {
    if (!state?.preview) return;
    const { start: s, preview } = state;
    setState({ ...state, phase: "applying" });
    try {
      const response = await request<ApplyResponse>("/mutations/apply", {
        method: "POST",
        body: {
          operationId: s.operationId,
          keys: s.keys,
          proposed: s.proposed,
          request: s.request,
          fingerprint: preview.fingerprint,
          confirmation: state.confirmation,
          acknowledged: state.acknowledged,
        },
      });
      appendTrail(response.trail);
      pendingOutcome.current = { status: "applied", result: response.result, trail: response.trail };
      resolver.current?.(pendingOutcome.current);
      resolver.current = null;
      setState({ ...state, phase: "applied", message: null, result: response.result });
    } catch (error) {
      if (!(error instanceof ApiError)) {
        setState({ ...state, phase: "ready", message: "The server could not be reached." });
        return;
      }
      const body = (error.body ?? {}) as { preview?: PreviewResponse; trail?: TrailRecord; validation?: boolean };
      if (error.status === 401) {
        setState({ ...state, phase: "expired" });
        return;
      }
      if (error.code === "STATE_CHANGED" && body.preview) {
        setState({ ...state, phase: "ready", preview: body.preview, message: MUTATION_MESSAGES.changed, confirmation: "", acknowledged: false });
        return;
      }
      if (error.code === "SELF_PROTECTION") {
        if (body.trail) appendTrail(body.trail);
        pendingOutcome.current = { status: "blocked", message: error.message };
        setState({ ...state, phase: "failed", message: error.message });
        return;
      }
      if (error.code === "UPSTREAM_REJECTED") {
        if (body.trail) appendTrail(body.trail);
        const outcome: MutationOutcome = { status: "rejected", message: error.message, validation: Boolean(body.validation) };
        pendingOutcome.current = outcome;
        close();
        return;
      }
      setState({ ...state, phase: "ready", preview: body.preview ?? preview, message: error.message });
    }
  }, [state, close]);

  const value = useMemo(() => ({ start, openTrail: () => setTrailOpen(true) }), [start]);

  return (
    <MutationContext.Provider value={value}>
      {children}
      {state && (
        <DryRun
          state={state}
          armed={safeMode === "armed"}
          onConfirmationChange={(confirmation) => setState((s) => (s ? { ...s, confirmation } : s))}
          onAcknowledgedChange={(acknowledged) => setState((s) => (s ? { ...s, acknowledged } : s))}
          onDisarm={disarm}
          onApply={() => void apply()}
          onCancel={close}
          onOpenTrail={() => {
            close();
            setTrailOpen(true);
          }}
        />
      )}
      <TrailPanel open={trailOpen} onClose={() => setTrailOpen(false)} />
    </MutationContext.Provider>
  );
}

export function useMutation(): MutationContextValue {
  const value = useContext(MutationContext);
  if (!value) throw new Error("useMutation must be used inside MutationProvider");
  return value;
}
