import * as Dialog from "@radix-ui/react-dialog";
import { useEffect, useState, type ReactNode } from "react";
import { useSearchParams } from "react-router-dom";

function useWide(): boolean {
  const query = "(min-width: 1280px)";
  const [wide, setWide] = useState(() => window.matchMedia?.(query).matches ?? true);
  useEffect(() => {
    const media = window.matchMedia?.(query);
    if (!media) return;
    const onChange = () => setWide(media.matches);
    media.addEventListener("change", onChange);
    return () => media.removeEventListener("change", onChange);
  }, []);
  return wide;
}

/** Parses ?inspect=<entityType>:<name>. */
export function useInspect(): [{ entityType: string; name: string } | null, () => void] {
  const [params, setParams] = useSearchParams();
  const raw = params.get("inspect");
  const close = () => {
    const next = new URLSearchParams(params);
    next.delete("inspect");
    setParams(next);
  };
  if (!raw) return [null, close];
  const index = raw.indexOf(":");
  if (index < 0) return [null, close];
  return [{ entityType: raw.slice(0, index), name: raw.slice(index + 1) }, close];
}

/**
 * List plus inspector (design §4, FR-034). Detail never navigates away: it opens beside the list
 * at 1280px and wider, and as an overlay below.
 */
export function ListInspector({ list, inspector, inspectorLabel, onClose }: { list: ReactNode; inspector: ReactNode | null; inspectorLabel: string; onClose?: () => void }) {
  const wide = useWide();
  const [, closeInspect] = useInspect();
  const close = onClose ?? closeInspect;
  return (
    <div className="view">
      <div className="list">{list}</div>
      {inspector &&
        (wide ? (
          <aside className="inspector" aria-label={inspectorLabel} data-testid="inspector">
            {inspector}
          </aside>
        ) : (
          <Dialog.Root open onOpenChange={(open) => !open && close()} modal={false}>
            <Dialog.Portal>
              <Dialog.Content className="float inspector-overlay" aria-describedby={undefined} data-testid="inspector">
                <Dialog.Title className="visually-hidden">{inspectorLabel}</Dialog.Title>
                {inspector}
              </Dialog.Content>
            </Dialog.Portal>
          </Dialog.Root>
        ))}
    </div>
  );
}
