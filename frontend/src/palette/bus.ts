// Lets any component open the command palette without prop drilling.
type Listener = () => void;
const listeners = new Set<Listener>();

export function openPalette(): void {
  listeners.forEach((l) => l());
}

export function onOpenPalette(listener: Listener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}
