import * as Dialog from "@radix-ui/react-dialog";
import { useEffect, useRef, useState } from "react";
import type { DiffRow } from "../api/types";
import { formatField, humanize } from "../domains/presentation";
import { MUTATION_MESSAGES, type DryRunState } from "./useMutation";
import "./dryrun.css";

interface Props {
  state: DryRunState;
  armed: boolean;
  onConfirmationChange: (value: string) => void;
  onAcknowledgedChange: (value: boolean) => void;
  onDisarm: () => void;
  onApply: () => void;
  onCancel: () => void;
  onOpenTrail: () => void;
}

const VERB = { create: "Create", edit: "Apply changes to", delete: "Delete", request: "Send test request to", action: "Apply to" } as const;

/** What the impact block says when the platform answered but there was nothing to analyse. */
const NO_IMPACT_NONE =
  "Nothing beyond the difference above. FlightDeck reports impact where a change to one object reaches others, and this operation does not.";
const NO_IMPACT_CREATE = "Nothing is affected yet: this object does not exist until you apply.";

/**
 * The only confirmation view in the product (Constitution V, docs/design.md §6,
 * contracts/ui-pattern.md §4): CURRENT against COMMANDED, impact, graded confirmation, one reveal.
 */
export function DryRun(props: Props) {
  const { state } = props;
  const preview = state.preview;
  const [revealed, setRevealed] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const applyRef = useRef<HTMLButtonElement>(null);

  // The orchestrated reveal runs once per preview (instant under prefers-reduced-motion, via CSS).
  useEffect(() => {
    setRevealed(false);
    const frame = requestAnimationFrame(() => setRevealed(true));
    return () => cancelAnimationFrame(frame);
  }, [preview?.fingerprint, preview?.rows]);

  // The confirmation field and an enabled Apply only exist once the preview has landed, which is
  // after the dialog opened. Focus follows them, so a keyboard user does not have to discover by
  // tabbing that the thing they must do has appeared. A recomputed preview moves focus again,
  // because it clears the typed confirmation and asks for it afresh (RN-FD-31).
  useEffect(() => {
    if (state.phase !== "ready") return;
    if (inputRef.current) inputRef.current.focus();
    else if (applyRef.current && !applyRef.current.disabled) applyRef.current.focus();
  }, [state.phase, preview?.fingerprint]);

  const grade = preview?.grade ?? "simple";
  const needsText = grade !== "simple";
  const textOk = !needsText || state.confirmation === preview?.confirmText;
  const ackOk = grade !== "maximum" || state.acknowledged;
  const blocked = Boolean(preview?.blocked);
  const noChange = Boolean(preview?.noChange);
  const ready = state.phase === "ready" && preview !== null && !blocked && !noChange;
  const canApply = ready && !props.armed && textOk && ackOk;
  const title = preview ? `${VERB[preview.kind]} ${state.start.noun}` : `Preparing changes to ${state.start.noun}`;
  const target = preview?.target ?? Object.values(state.start.keys ?? {}).join(" ");
  const changedCount = preview?.rows.filter((r) => r.changed).length ?? 0;

  return (
    <Dialog.Root open onOpenChange={(open) => !open && props.onCancel()}>
      <Dialog.Portal>
        <Dialog.Overlay className="scrim" />
        <Dialog.Content
          className={`float dryrun${revealed ? " reveal" : ""}`}
          data-testid="dry-run"
          aria-describedby="dryrun-summary"
          onOpenAutoFocus={(e) => {
            // At mount the preview is still in flight, so the confirmation field does not exist and
            // Apply is disabled. Focusing a disabled button is a no-op, and preventing the default
            // as well used to leave focus outside the dialog, on a control the overlay had just
            // hidden from assistive technology (verification/ux-review.md, D2). When there is
            // nothing better to aim at, let the focus scope take its own first element.
            const target = needsText ? inputRef.current : applyRef.current?.disabled === false ? applyRef.current : null;
            if (!target) return;
            e.preventDefault();
            target.focus();
          }}
        >
          <div className="dhead">
            <Dialog.Title className="dtitle">
              {title} <span className="mono">{target}</span>
            </Dialog.Title>
            <div id="dryrun-summary" className="dsub">
              {state.phase === "previewing"
                ? "Reading the current state from the instance."
                : preview?.requestMode
                  ? preview.requestMode.reason
                  : preview?.kind === "action"
                    ? `${changedCount === 0 ? "Nothing changes" : "One change"} in what the instance reports today. Nothing is sent until you apply.`
                    : `${changedCount} of ${preview?.rows.length ?? 0} fields change. Nothing is sent until you apply.`}
            </div>
          </div>

          {preview?.notice && (
            <div className="dmessage" role="status" data-testid="dry-run-notice">
              {preview.notice}
            </div>
          )}
          {state.phase === "applying" && (
            <div className="dmessage" role="status" data-testid="dry-run-applying">
              Applying. The instance is working on it{preview?.applyNotice ? `. ${preview.applyNotice}` : "; nothing else is sent until it answers."}
            </div>
          )}
          {state.message && (
            <div className="dmessage" role={state.phase === "failed" ? "alert" : "status"} data-testid="dry-run-message">
              {state.message}
            </div>
          )}
          {state.phase === "expired" && (
            <div className="dmessage" role="status" data-testid="dry-run-message">
              Your session expired. Sign in again: the differences are recomputed before anything is applied.
            </div>
          )}

          {/* Focusable so keyboard users can scroll a long diff (WCAG 2.1.1, axe scrollable-region-focusable). */}
          <div className="dbody" aria-busy={state.phase === "previewing"} tabIndex={0} role="region" aria-label={preview?.requestMode ? "Request to send" : "Differences"}>
            {preview?.requestMode ? (
              <RequestBlock preview={preview} />
            ) : (
              preview && preview.rows.length > 0 && (
                <div className="diff" role="table" aria-label="Current and commanded values">
                  <div className="dcols" role="row">
                    <span role="columnheader">Field</span>
                    <span role="columnheader">CURRENT</span>
                    <span role="columnheader">COMMANDED</span>
                  </div>
                  {preview.rows.map((row) => (
                    <Row key={row.field} row={row} />
                  ))}
                </div>
              )
            )}
          </div>
          {/* Always rendered. A missing impact block reads as an impact that failed to compute, which
              is the same defect as a log severity of "unknown" or a duration that quietly becomes
              zero: the absence is indistinguishable from the failure. When a provider ran and found
              nothing it already says so in its own words; when no analysis applies, say that
              (verification/ux-review.md, A4). */}
          {preview?.impact && (
              <div className="impact" data-testid="dry-run-impact" data-state={preview.impact.state}>
                <div className="impact-h">
                  {preview.impact.state !== "none" && (
                    <svg className="glyph" viewBox="0 0 10 10" fill="currentColor" aria-hidden="true">
                      <path d="M5 0l5 9H0z" />
                    </svg>
                  )}
                  <span>Impact</span>
                </div>
                <div className="impact-b">{preview.impact.summary ?? (preview.kind === "create" ? NO_IMPACT_CREATE : NO_IMPACT_NONE)}</div>
                {preview.impact.state === "undetermined" && <div className="impact-u">{preview.impact.reason}</div>}
                {preview.impact.users && preview.impact.users.length > 0 && <div className="impact-u mono">{preview.impact.users.join(" · ")}</div>}
                {/* What becomes unreachable, not only who loses access (RN-FD-11). */}
                {preview.impact.objects && preview.impact.objects.length > 0 && (
                  <div className="impact-u mono" data-testid="dry-run-impact-objects">
                    {preview.impact.objects.map((o) => `${o.displayName}${o.detail ? ` (${o.detail})` : ""}`).join(" · ")}
                  </div>
                )}
              </div>
          )}

          <div className="dfoot">
            {state.phase === "applied" ? (
              <>
                <span className="dapplied" role="status" data-testid="dry-run-applied">
                  Applied
                </span>
                <span className="dsp">
                  <button className="btn" type="button" onClick={props.onOpenTrail}>
                    Open session trail
                  </button>
                  <button className="btn btn-primary" type="button" onClick={props.onCancel}>
                    Close
                  </button>
                </span>
              </>
            ) : (
              <>
                {ready && needsText && (
                  <label className="dask">
                    <span>
                      Type <span className="mono">{preview?.confirmText}</span> to confirm
                    </span>
                    <input
                      ref={inputRef}
                      value={state.confirmation}
                      onChange={(e) => props.onConfirmationChange(e.target.value)}
                      spellCheck={false}
                      autoComplete="off"
                      data-testid="dry-run-confirm-input"
                    />
                  </label>
                )}
                {ready && grade === "maximum" && (
                  <label className="dack">
                    <input type="checkbox" checked={state.acknowledged} onChange={(e) => props.onAcknowledgedChange(e.target.checked)} data-testid="dry-run-acknowledge" />
                    <span>{preview?.consequence}</span>
                  </label>
                )}
                {/* A consequence is stated whenever the rule declared one; the maximum grade also
                    asks the user to acknowledge it. */}
                {ready && grade !== "maximum" && preview?.consequence && (
                  <span className="dack" data-testid="dry-run-consequence">
                    {preview.consequence}
                  </span>
                )}
                {/* How long the platform is expected to take, stated before anything is sent: an
                    operation of minutes shown as a synchronous request reads as a frozen
                    application (feature 004 spec FR-037b). */}
                {ready && preview?.expectedDuration && (
                  <span className="dack" data-testid="dry-run-duration">
                    {`The instance usually takes ${preview.expectedDuration}. FlightDeck follows it and reports what the platform says.`}
                  </span>
                )}
                <span className="dsp">
                  <button className="btn" type="button" onClick={props.onCancel}>
                    Cancel
                  </button>
                  {ready && props.armed ? (
                    <button className="btn btn-primary" type="button" onClick={props.onDisarm} title={MUTATION_MESSAGES.safeMode} data-testid="dry-run-disarm">
                      Turn off safe mode and continue
                    </button>
                  ) : (
                    <button
                      ref={applyRef}
                      className="btn btn-primary"
                      type="button"
                      disabled={!canApply || state.phase === "applying"}
                      onClick={props.onApply}
                      data-testid="dry-run-apply"
                      aria-busy={state.phase === "applying" ? "true" : undefined}
                    >
                      {state.phase === "applying" ? "Applying…" : "Apply"}
                    </button>
                  )}
                </span>
              </>
            )}
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

function Row({ row }: { row: DiffRow }) {
  return (
    <div className={`drow${row.changed ? " changed" : ""}`} role="row" data-testid={`dry-run-row-${row.field}`} data-changed={row.changed ? "true" : "false"}>
      <span className="k" role="cell">
        {humanize(row.field)}
      </span>
      <span className="cur mono" role="cell">
        {row.secret ? (row.changed ? "changed" : "unchanged") : formatField(row.field, row.current)}
      </span>
      <span className="cmd mono" role="cell">
        {row.secret ? (row.changed ? "changed" : "unchanged") : formatField(row.field, row.commanded)}
      </span>
    </div>
  );
}

function RequestBlock({ preview }: { preview: NonNullable<DryRunState["preview"]> }) {
  const req = preview.requestMode!.request;
  return (
    <div className="drequest" data-testid="dry-run-request">
      <div className="dcols">
        <span>REQUEST</span>
      </div>
      <div className="drow changed">
        <span className="k">Method and path</span>
        <span className="cmd mono">
          {req.method} {req.path}
        </span>
      </div>
      {req.query && Object.keys(req.query).length > 0 && (
        <div className="drow changed">
          <span className="k">Query</span>
          <span className="cmd mono">{new URLSearchParams(req.query).toString()}</span>
        </div>
      )}
      {req.headers && Object.keys(req.headers).length > 0 && (
        <div className="drow changed">
          <span className="k">Headers</span>
          <span className="cmd mono">
            {Object.entries(req.headers)
              .map(([k, v]) => `${k}: ${v}`)
              .join("\n")}
          </span>
        </div>
      )}
      {req.body && (
        <div className="drow changed">
          <span className="k">Body</span>
          <pre className="cmd mono dbody-pre">{req.body}</pre>
        </div>
      )}
    </div>
  );
}
