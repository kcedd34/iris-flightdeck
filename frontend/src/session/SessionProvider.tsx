import { useQueryClient } from "@tanstack/react-query";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { ApiError, registerSessionExpiry, request, setSessionActive, signIn as apiSignIn } from "../api/client";
import type { CapabilityEntry, Session } from "../api/types";
import { clearTrail } from "../mutation/useMutation";
import { arm } from "./safeMode";

export type SessionState = "loading" | "signed_out" | "active" | "expired";

interface SessionContextValue {
  state: SessionState;
  session: Session | null;
  capabilities: CapabilityEntry[];
  /** Incremented on every re-authentication; computed state from an older epoch must be recomputed. */
  computationEpoch: number;
  signIn: (username: string, password: string) => Promise<void>;
  reauthenticate: (username: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
}

const SessionContext = createContext<SessionContextValue | null>(null);

/**
 * Session state machine (data-model §2). Holds identity and the capability map in memory only.
 * The password passes through signIn/reauthenticate as an argument and is never kept.
 */
export function SessionProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient();
  const [state, setState] = useState<SessionState>("loading");
  const [session, setSession] = useState<Session | null>(null);
  const [capabilities, setCapabilities] = useState<CapabilityEntry[]>([]);
  const [computationEpoch, setEpoch] = useState(0);
  const stateRef = useRef(state);
  stateRef.current = state;

  const activate = useCallback(async (next: Session) => {
    const map = await request<{ entries: CapabilityEntry[] }>("/session/capabilities");
    setSession(next);
    setCapabilities(map.entries);
    setSessionActive(true);
    setState("active");
  }, []);

  useEffect(() => {
    registerSessionExpiry(() => {
      if (stateRef.current === "active") {
        setSessionActive(false);
        // The trail is cleared when expiry is detected (feature 002 spec FR-014).
        clearTrail();
        setState("expired");
      }
    });
    let cancelled = false;
    request<Session>("/session")
      .then((s) => (cancelled ? undefined : activate(s)))
      .catch(() => {
        if (!cancelled) setState("signed_out");
      });
    return () => {
      cancelled = true;
      registerSessionExpiry(null);
    };
  }, [activate]);

  const signIn = useCallback(
    async (username: string, password: string) => {
      const next = await apiSignIn<Session>(username, password);
      arm();
      await activate(next);
    },
    [activate],
  );

  const reauthenticate = useCallback(
    async (username: string, password: string) => {
      const previous = session?.username;
      const next = await apiSignIn<Session>(username, password);
      if (previous && next.username !== previous) {
        // A different user: nothing from the previous identity may survive (data-model §2).
        arm();
        queryClient.clear();
        await activate(next);
        setEpoch((e) => e + 1);
        window.location.assign("/flightdeck/");
        return;
      }
      await activate(next);
      setEpoch((e) => e + 1);
      await queryClient.invalidateQueries();
    },
    [activate, queryClient, session?.username],
  );

  const signOut = useCallback(async () => {
    try {
      await request<void>("/session", { method: "DELETE" });
    } catch (error) {
      if (!(error instanceof ApiError) || error.status !== 401) throw error;
    }
    arm();
    setSessionActive(false);
    clearTrail();
    queryClient.clear();
    setSession(null);
    setCapabilities([]);
    setState("signed_out");
  }, [queryClient]);

  const value = useMemo(
    () => ({ state, session, capabilities, computationEpoch, signIn, reauthenticate, signOut }),
    [state, session, capabilities, computationEpoch, signIn, reauthenticate, signOut],
  );
  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export function useSession(): SessionContextValue {
  const value = useContext(SessionContext);
  if (!value) throw new Error("useSession must be used inside SessionProvider");
  return value;
}

/**
 * Operations the instance does not offer, from the capability map (`available: false`). The only
 * source for limited mode in the UI: screens never ask which API version the instance speaks.
 */
export function useUnavailableOperations(): { unavailable: number; total: number } {
  const { capabilities } = useSession();
  return { unavailable: capabilities.filter((c) => !c.available).length, total: capabilities.length };
}

export function useCapability(operationId: string): CapabilityEntry | undefined {
  return useSession().capabilities.find((c) => c.operationId === operationId);
}
