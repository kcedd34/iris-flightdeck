import * as Tooltip from "@radix-ui/react-tooltip";
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { request } from "../api/client";
import type { Vital } from "../api/types";

const NAMES: Record<Vital["id"], { label: string; accessible: string }> = {
  cpu: { label: "CPU", accessible: "Host CPU in use" },
  memory: { label: "Memory", accessible: "Host memory in use" },
  shm: { label: "Shared memory", accessible: "IRIS shared memory heap in use" },
  disk: { label: "Disk", accessible: "Fullest database" },
};

const ORDER: Vital["id"][] = ["cpu", "memory", "shm", "disk"];

function Glyph({ state }: { state: Vital["state"] }) {
  if (state !== "caution" && state !== "warning") return null;
  return (
    <svg className="glyph" viewBox="0 0 10 10" fill="currentColor" aria-hidden="true">
      <path d="M5 0l5 9H0z" />
    </svg>
  );
}

/**
 * Glareshield vitals (FR-029 to FR-031a). Refreshes every 10 s, pauses while the tab is hidden, and
 * keeps the last known value while a refresh (including async disk) is in flight.
 */
export function Vitals() {
  const { data, isError } = useQuery({
    queryKey: ["vitals"],
    queryFn: ({ signal }) => request<{ vitals: Vital[] }>("/vitals", { signal }),
    refetchInterval: 10_000,
    refetchIntervalInBackground: false,
    placeholderData: keepPreviousData,
    retry: false,
  });
  const byId = new Map((data?.vitals ?? []).map((v) => [v.id, v]));

  return (
    <Tooltip.Provider delayDuration={200}>
      <div className="vitals" data-testid="vitals">
        {ORDER.map((id) => {
          const vital = byId.get(id);
          const names = NAMES[id];
          const scope = vital?.scope ? ` (${vital.scope})` : "";
          let valueNode;
          let tip = names.accessible + scope;
          if (!vital) {
            // The skeleton is decoration: a bare span may not carry aria-label (axe aria-prohibited-attr),
            // and the reading it stands in for is named on the .vital element around it.
            valueNode = isError ? "—" : <span className="vital-skeleton" aria-hidden="true" />;
            tip = isError ? `${names.accessible}: not available right now` : `${names.accessible}${scope}: reading it now`;
          } else if (vital.state === "unavailable" || vital.value === null) {
            valueNode = "—";
            tip = `${names.accessible}: ${vital.reason ?? "not available"}${vital.requires ? ` Requires ${vital.requires}.` : ""}`;
          } else {
            valueNode = (
              <>
                <Glyph state={vital.state} />
                {`${Math.round(vital.value)}%`}
              </>
            );
          }
          return (
            <Tooltip.Root key={id}>
              <Tooltip.Trigger asChild>
                <span className="vital" tabIndex={0} aria-label={tip} data-testid={`vital-${id}`}>
                  <span className="vital-k">{names.label}</span>
                  <span className="vital-v num" data-state={vital?.state ?? "pending"} data-pending={vital?.pending ?? false}>
                    {valueNode}
                  </span>
                </span>
              </Tooltip.Trigger>
              <Tooltip.Portal>
                <Tooltip.Content className="tip" sideOffset={6}>
                  {tip}
                </Tooltip.Content>
              </Tooltip.Portal>
            </Tooltip.Root>
          );
        })}
      </div>
    </Tooltip.Provider>
  );
}
