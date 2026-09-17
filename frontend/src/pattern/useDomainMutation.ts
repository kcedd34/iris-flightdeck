import { useQueryClient } from "@tanstack/react-query";
import { useCallback, useState } from "react";
import { useMutation, type MutationStart, type MutationOutcome } from "../mutation/useMutation";

/**
 * Runs a mutation through the shared layer and refreshes descriptor reads after it is applied.
 * Rejections keep the caller's form and show the IRIS text verbatim (spec FR-013).
 */
export function useDomainMutation() {
  const { start } = useMutation();
  const queryClient = useQueryClient();
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const run = useCallback(
    async (request: MutationStart): Promise<MutationOutcome> => {
      setBusy(true);
      setError(null);
      try {
        const outcome = await start(request);
        if (outcome.status === "applied") {
          await Promise.all([
            queryClient.invalidateQueries({ queryKey: ["entities"] }),
            queryClient.invalidateQueries({ queryKey: ["entity"] }),
            queryClient.invalidateQueries({ queryKey: ["links"] }),
          ]);
        } else if (outcome.status === "rejected" || outcome.status === "blocked") {
          setError(outcome.message);
        }
        return outcome;
      } finally {
        setBusy(false);
      }
    },
    [start, queryClient],
  );
  return { run, error, setError, busy };
}
