import { openPalette } from "../palette/bus";
import type { Domain, Section } from "./domains";
import { EmptyState } from "./EmptyState";
import { ListInspector, useInspect } from "../pattern/ListInspector";

/**
 * Every domain section in this feature (contracts/ui-shell.md). The list shows a declared empty
 * state; an entity opened from the palette appears in the inspector without leaving the route.
 */
export function PlaceholderSection({ domain, section }: { domain: Domain; section: Section }) {
  const [inspect, close] = useInspect();
  const list = (
    <EmptyState
      title="Not available in this build yet"
      cause={`The ${section.label} section ships with the ${domain.label} screens.`}
      nextAction="Open the command palette (Ctrl+K) to find entities across the instance."
      action={
        <button className="btn" type="button" onClick={openPalette}>
          Search <kbd>Ctrl K</kbd>
        </button>
      }
    />
  );
  const inspector = inspect ? (
    <>
      <button className="btn inspector-close" type="button" onClick={close} aria-label="Close inspector">
        Close
      </button>
      <h2 className="mono">{inspect.name}</h2>
      <div className="inspector-sub">{inspect.entityType}</div>
      <div className="field">
        <span className="field-k">Type</span>
        <span className="field-v">{inspect.entityType}</span>
      </div>
      <div className="field">
        <span className="field-k">Name</span>
        <span className="field-v mono">{inspect.name}</span>
      </div>
      <div className="field">
        <span className="field-k">Domain</span>
        <span className="field-v">{domain.label}</span>
      </div>
      <div className="sect">
        <div className="sect-h">Detail</div>
        <p className="empty-d">
          Detail view for {inspect.entityType} arrives with the {domain.label} screens.
        </p>
      </div>
    </>
  ) : null;
  return <ListInspector list={list} inspector={inspector} inspectorLabel={`${inspect?.entityType ?? "Entity"} details`} />;
}
