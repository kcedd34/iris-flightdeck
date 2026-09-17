import * as Dialog from "@radix-ui/react-dialog";
import { Command } from "cmdk";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { MESSAGES } from "../api/client";
import type { DomainId, EntityEntry, EntitySearchGroup, RailDomainId } from "../api/types";
import { getRecent, pushRecent } from "../prefs/storage";
import { useSession } from "../session/SessionProvider";
import { arm, disarm, getSafeMode } from "../session/safeMode";
import { DOMAINS, domainLabel } from "../shell/domains";
import { useTheme } from "../theme/ThemeProvider";
import { buildActions, matchActions, type ActionEntry } from "./actions";
import { onOpenPalette } from "./bus";
import { useEntitySearch } from "./useEntitySearch";
import "./palette.css";

const GROUP_LIMIT = 5;
const DOMAIN_ORDER: DomainId[] = ["shell", ...DOMAINS.map((d) => d.id)];

/**
 * Command palette (UC02, FR-019 to FR-028). Ctrl/Cmd+K from anywhere. Local actions resolve
 * instantly; entities come from the server. It degrades to actions only when entity search fails.
 */
export function CommandPalette() {
  const { session, capabilities, signOut } = useSession();
  const { theme, toggle } = useTheme();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [domainFilter, setDomainFilter] = useState<RailDomainId | null>(null);
  const [pendingOp, setPendingOp] = useState<ActionEntry | null>(null);
  const [announcement, setAnnouncement] = useState("");
  const [selected, setSelected] = useState("");
  const returnFocus = useRef<HTMLElement | null>(null);
  const username = session?.username ?? "";

  const show = useCallback(() => {
    returnFocus.current = document.activeElement as HTMLElement | null;
    performance.mark("palette-open");
    setQuery("");
    setDomainFilter(null);
    setPendingOp(null);
    setAnnouncement("");
    setOpen(true);
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        e.stopPropagation();
        show();
      }
    };
    window.addEventListener("keydown", onKey, { capture: true });
    const off = onOpenPalette(show);
    return () => {
      window.removeEventListener("keydown", onKey, { capture: true });
      off();
    };
  }, [show]);

  const actions = useMemo(() => buildActions(capabilities), [capabilities]);
  const actionById = useMemo(() => new Map(actions.map((a) => [a.id, a])), [actions]);
  const trimmed = query.trim();
  const search = useEntitySearch(trimmed, domainFilter, open && !pendingOp);

  const matchedActions = useMemo(() => {
    const all = matchActions(actions, trimmed);
    return domainFilter ? all.filter((a) => a.domain === domainFilter) : all;
  }, [actions, trimmed, domainFilter]);

  const close = useCallback(() => {
    setOpen(false);
    window.setTimeout(() => returnFocus.current?.focus?.(), 0);
  }, []);

  function remember(id: string, label: string, domain: DomainId, kind: "action" | "entity") {
    if (username) pushRecent(username, { id, label, domain, kind });
  }

  function runAction(action: ActionEntry) {
    if (!action.enabled) {
      setAnnouncement(action.disabledReason ?? "This action is not available to you.");
      return;
    }
    if (action.mutating && getSafeMode() === "armed") {
      // FR-025: offer to disarm first; never execute while armed.
      setPendingOp(action);
      return;
    }
    remember(action.id, action.label, action.domain, "action");
    const run = action.run;
    switch (run.type) {
      case "navigate":
      case "operation":
        navigate(run.to);
        break;
      case "theme":
        if (theme !== run.theme) toggle();
        break;
      case "safe-mode":
        if (run.to === "armed") arm();
        else disarm();
        break;
      case "sign-out":
        void signOut();
        break;
    }
    close();
  }

  function runEntity(entity: EntityEntry) {
    const id = `entity:${entity.entityType}:${entity.name}`;
    remember(id, entity.name, entity.domain, "entity");
    const inspect = encodeURIComponent(`${entity.target.inspect.entityType}:${entity.target.inspect.name}`);
    navigate(`${entity.target.route}?inspect=${inspect}`);
    close();
  }

  // Build groups in rail order: actions first, then entity groups, per domain.
  const groups = useMemo(() => {
    const byDomain = new Map<DomainId, { actions: ActionEntry[]; entities: EntitySearchGroup[] }>();
    for (const d of DOMAIN_ORDER) byDomain.set(d, { actions: [], entities: [] });
    for (const a of matchedActions) byDomain.get(a.domain)?.actions.push(a);
    for (const g of search.data?.groups ?? []) byDomain.get(g.domain)?.entities.push(g);
    return DOMAIN_ORDER.map((d) => ({ domain: d, ...byDomain.get(d)! })).filter((g) => g.actions.length || g.entities.length);
  }, [matchedActions, search.data]);

  const entityTotal = search.data?.totalResults ?? 0;
  const total = matchedActions.length + entityTotal;
  const recent = trimmed ? [] : getRecent(username);
  const noResults = trimmed && !search.pending && total === 0 && !search.unavailable;

  useEffect(() => {
    if (open) {
      requestAnimationFrame(() => performance.mark("palette-input-focused"));
    }
  }, [open]);

  // With our own filtering, keep the selection on the first visible item whenever results change,
  // so Enter always acts on what the user sees first.
  const firstValue = useMemo(() => {
    if (!trimmed) return recent[0] ? `recent:${recent[0].id}` : "";
    for (const g of groups) {
      if (g.actions[0]) return g.actions[0].id;
      const firstEntity = g.entities.find((eg) => eg.state === "ok" && eg.results.length)?.results[0];
      if (firstEntity) return `entity:${firstEntity.entityType}:${firstEntity.name}`;
    }
    return "";
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [trimmed, groups, recent.length]);
  useEffect(() => {
    setSelected(firstValue);
  }, [firstValue]);

  return (
    <Dialog.Root open={open} onOpenChange={(o) => (o ? show() : close())}>
      <Dialog.Portal>
        <Dialog.Overlay className="scrim" />
        <Dialog.Content className="float palette" aria-describedby={undefined} data-testid="command-palette">
          <Dialog.Title className="visually-hidden">Command palette</Dialog.Title>
          {pendingOp ? (
            <div className="palette-step" role="group" aria-label="Safe mode is on">
              <div className="palette-step-title">{MESSAGES.safeModeOn}</div>
              <div className="palette-step-op">
                <span>{pendingOp.label}</span>
                <span className="mono palette-ctx">{pendingOp.context}</span>
              </div>
              <div className="palette-step-actions">
                <button className="btn" type="button" onClick={() => setPendingOp(null)}>
                  Cancel
                </button>
                <button
                  className="btn btn-primary"
                  type="button"
                  autoFocus
                  onClick={() => {
                    disarm();
                    const op = pendingOp;
                    setPendingOp(null);
                    runAction(op);
                  }}
                >
                  Turn off safe mode and continue
                </button>
              </div>
            </div>
          ) : (
            <Command shouldFilter={false} loop label="Command palette" value={selected} onValueChange={setSelected}>
              <div className="palette-inputrow">
                {domainFilter && (
                  <button className="palette-chip" type="button" onClick={() => setDomainFilter(null)} aria-label={`Remove filter ${domainLabel(domainFilter)}`}>
                    {domainLabel(domainFilter)} ×
                  </button>
                )}
                <Command.Input
                  autoFocus
                  value={query}
                  onValueChange={setQuery}
                  placeholder="Search entities or run a command"
                  data-testid="palette-input"
                />
                {trimmed && (
                  <span className="palette-count num" aria-live="polite">
                    {search.pending ? "Searching" : `${total} result${total === 1 ? "" : "s"}`}
                  </span>
                )}
              </div>
              {search.unavailable && trimmed && (
                <div className="palette-degraded" role="status" data-testid="palette-unavailable">
                  {MESSAGES.entitySearch}
                </div>
              )}
              {search.data?.degraded && !search.unavailable && (
                <div className="palette-degraded" role="status">
                  {search.data.reason}
                </div>
              )}
              <Command.List className="palette-results">
                {!trimmed && recent.length > 0 && (
                  <Command.Group heading="Recent" className="palette-group">
                    {recent.map((r) => {
                      const action = actionById.get(r.id);
                      return (
                        <Command.Item
                          key={`recent:${r.id}`}
                          value={`recent:${r.id}`}
                          className="palette-row"
                          onSelect={() => (action ? runAction(action) : setQuery(r.label))}
                        >
                          <span>{r.label}</span>
                          <span className="palette-ctx">{domainLabel(r.domain as DomainId)}</span>
                        </Command.Item>
                      );
                    })}
                  </Command.Group>
                )}
                {!trimmed && recent.length === 0 && (
                  <div className="palette-hint-block">Type the name of a user, role, web application, task or any action.</div>
                )}
                {groups.map((g) => {
                  const shown = g.actions.slice(0, GROUP_LIMIT);
                  const hidden = g.actions.length - shown.length;
                  return (
                    <Command.Group key={g.domain} heading={domainLabel(g.domain)} className="palette-group">
                      {shown.map((a) => (
                        <Command.Item
                          key={a.id}
                          value={a.id}
                          className="palette-row"
                          disabled={!a.enabled}
                          data-disabled-reason={a.disabledReason ?? undefined}
                          onSelect={() => runAction(a)}
                        >
                          <span>{a.label}</span>
                          <span className={`palette-ctx${a.mono ? " mono" : ""}`}>{a.context}</span>
                          {!a.enabled && <span className="palette-reason">{a.disabledReason}</span>}
                          {a.enabled && a.mutating && getSafeMode() === "armed" && <span className="palette-lock">Safe mode</span>}
                        </Command.Item>
                      ))}
                      {g.entities.map((eg) =>
                        eg.state === "ok" ? (
                          <EntityRows key={eg.entityType} group={eg} onSelect={runEntity} onRefine={() => setDomainFilter(eg.domain as RailDomainId)} />
                        ) : eg.state === "unavailable" ? null : (
                          <div key={eg.entityType} className="palette-note" role="note">
                            {eg.entityType}: {eg.state === "timeout" ? "did not respond in time" : eg.reason}
                          </div>
                        ),
                      )}
                      <UnavailableNote groups={g.entities} />
                      {hidden > 0 && g.domain !== "shell" && (
                        <Command.Item value={`refine:${g.domain}`} className="palette-row palette-more" onSelect={() => setDomainFilter(g.domain as RailDomainId)}>
                          {hidden} more — refine to {domainLabel(g.domain)}
                        </Command.Item>
                      )}
                    </Command.Group>
                  );
                })}
                {noResults && (
                  <div className="palette-empty" role="status">
                    <div>No matches for “{trimmed}”.</div>
                    <div className="palette-ctx">
                      Searchable domains: {DOMAINS.map((d) => d.label).join(", ")}. Keyboard shortcuts: Ctrl+K opens this palette;
                      arrows move; Enter runs; Esc closes.
                    </div>
                  </div>
                )}
              </Command.List>
              <div className="palette-hint">
                <span>
                  <kbd>↑</kbd>
                  <kbd>↓</kbd> navigate
                </span>
                <span>
                  <kbd>Enter</kbd> open
                </span>
                <span>
                  <kbd>Esc</kbd> close
                </span>
              </div>
            </Command>
          )}
          <div className="visually-hidden" aria-live="assertive">
            {announcement}
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

function EntityRows({ group, onSelect, onRefine }: { group: EntitySearchGroup; onSelect: (e: EntityEntry) => void; onRefine: () => void }) {
  const more = (group.total ?? group.results.length) - group.results.length;
  return (
    <>
      {group.results.map((e) => (
        <Command.Item key={`${e.entityType}:${e.name}`} value={`entity:${e.entityType}:${e.name}`} className="palette-row" onSelect={() => onSelect(e)}>
          <span className="mono">{e.name}</span>
          <span className="palette-ctx">{e.context}</span>
        </Command.Item>
      ))}
      {more > 0 && (
        <Command.Item value={`refine-entities:${group.domain}:${group.entityType}`} className="palette-row palette-more" onSelect={onRefine}>
          {more} more {group.entityType.toLowerCase()} results — refine to {domainLabel(group.domain)}
        </Command.Item>
      )}
    </>
  );
}

/** Entity types the instance does not offer (limited mode), named once per domain with the version message. */
function UnavailableNote({ groups }: { groups: EntitySearchGroup[] }) {
  const unavailable = groups.filter((eg) => eg.state === "unavailable");
  if (unavailable.length === 0) return null;
  return (
    <div className="palette-note" role="note" data-testid="palette-unavailable-types">
      Not searched: {unavailable.map((eg) => eg.entityType).join(", ")}. {unavailable[0]!.reason}
    </div>
  );
}
