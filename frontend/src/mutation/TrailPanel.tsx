import * as Dialog from "@radix-ui/react-dialog";
import { useState } from "react";
import type { TrailRecord } from "../api/types";
import { formatField, humanize } from "../domains/presentation";
import { exportTrail, TRAIL_NOTICE, useTrail } from "./trail";
import "./dryrun.css";

/** The session trail (RN-FD-27, contracts/ui-pattern.md §5): newest first, exportable as JSON. */
export function TrailPanel({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { document, persistent } = useTrail();
  const entries = [...document.entries].reverse();
  const download = () => {
    const { fileName, text } = exportTrail();
    const url = URL.createObjectURL(new Blob([text], { type: "application/json" }));
    const anchor = window.document.createElement("a");
    anchor.href = url;
    anchor.download = fileName;
    anchor.click();
    URL.revokeObjectURL(url);
  };
  return (
    <Dialog.Root open={open} onOpenChange={(o) => !o && onClose()}>
      <Dialog.Portal>
        <Dialog.Overlay className="scrim" />
        <Dialog.Content className="float dryrun" data-testid="trail-panel" aria-describedby="trail-notice">
          <div className="dhead">
            <Dialog.Title className="dtitle">Session trail</Dialog.Title>
            <div id="trail-notice" className="dsub">
              {TRAIL_NOTICE}
              {!persistent && " This trail is kept in memory and will not survive a reload."}
              {document.dropped > 0 && ` ${document.dropped} older entries were dropped.`}
            </div>
          </div>
          <div className="dbody">
            {entries.length === 0 ? (
              <div className="empty">
                <div className="empty-t">No changes in this tab yet</div>
                <div className="empty-d">Applied, failed and blocked changes appear here as you make them. Nothing is recorded for reads.</div>
              </div>
            ) : (
              entries.map((entry) => <Entry key={entry.id} entry={entry} />)
            )}
          </div>
          <div className="dfoot">
            <span className="dsp">
              <button className="btn" type="button" onClick={download} disabled={entries.length === 0} data-testid="trail-export">
                Export JSON
              </button>
              <button className="btn btn-primary" type="button" onClick={onClose}>
                Close
              </button>
            </span>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

function Entry({ entry }: { entry: TrailRecord }) {
  const [expanded, setExpanded] = useState(false);
  const changed = entry.rows.filter((r) => r.changed);
  return (
    <div className="trail-entry" data-testid="trail-entry" data-result={entry.result}>
      <button type="button" className="item" aria-expanded={expanded} onClick={() => setExpanded((v) => !v)}>
        <span className="mono num">{entry.time.slice(11, 19)}</span>
        <span className={`trail-result trail-${entry.result.toLowerCase()}`}>{entry.result}</span>
        <span className="nm mono">{entry.target}</span>
        <span className="meta mono">
          {entry.request ? <span className="num">{entry.status} · </span> : null}
          {entry.operationId}
        </span>
      </button>
      {expanded && (
        <div className="trail-detail">
          {entry.message && <div className="impact-u">{entry.message}</div>}
          {entry.request && (
            <div className="impact-u mono">
              {entry.request.method} {entry.request.path}
            </div>
          )}
          {changed.map((row) => (
            <div className="drow changed" key={row.field}>
              <span className="k">{humanize(row.field)}</span>
              <span className="cur mono">{row.secret ? "changed" : formatField(row.field, row.current)}</span>
              <span className="cmd mono">{row.secret ? "changed" : formatField(row.field, row.commanded)}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
