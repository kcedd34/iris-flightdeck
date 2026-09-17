import { useEffect, useState } from "react";
import { request } from "../api/client";
import type { Session } from "../api/types";
import { useSession } from "../session/SessionProvider";

/**
 * Fixtures build only (FR-017a). Holds typed input and a computed difference so UC01 scenario 4
 * can be proven before any real edit form exists. Excluded from the production bundle.
 */
export default function ReauthFixture() {
  const { session, computationEpoch } = useSession();
  const current = session?.username ?? "";
  const [draft, setDraft] = useState("");
  const [diff, setDiff] = useState<{ field: string; before: string; after: string }[]>([]);
  const [diffEpoch, setDiffEpoch] = useState(-1);
  const [recomputed, setRecomputed] = useState(false);
  const [check, setCheck] = useState<string>("");

  useEffect(() => {
    if (diffEpoch !== -1 && diffEpoch !== computationEpoch) {
      // Stale computation from before re-authentication: discard and recompute (FR-017).
      setDiff(draft && draft !== current ? [{ field: "description", before: current, after: draft }] : []);
      setDiffEpoch(computationEpoch);
      setRecomputed(true);
    }
  }, [computationEpoch, diffEpoch, draft, current]);

  function compute(value: string) {
    setDraft(value);
    setDiff(value && value !== current ? [{ field: "description", before: current, after: value }] : []);
    setDiffEpoch(computationEpoch);
  }

  const canApply = diff.length > 0 && diffEpoch === computationEpoch;
  return (
    <div className="home">
      <h1>Re-authentication fixture</h1>
      <label className="credentials-field">
        <span>Description</span>
        <input className="field-input" data-testid="fixture-input" value={draft} onChange={(e) => compute(e.target.value)} />
      </label>
      <div data-testid="fixture-diff">
        {diff.map((d) => (
          <div key={d.field} className="field">
            <span className="field-k">{d.field}</span>
            <span className="field-v">
              {d.before} → {d.after}
            </span>
          </div>
        ))}
      </div>
      {recomputed && <div data-testid="fixture-recomputed">Differences recomputed</div>}
      <div className="workhead-right">
        <button
          className="btn"
          type="button"
          onClick={() =>
            request<Session>("/session")
              .then(() => setCheck("Server session is active"))
              .catch(() => setCheck("Server rejected the session"))
          }
        >
          Check server
        </button>
        <button className="btn btn-primary" type="button" disabled={!canApply} data-testid="fixture-apply">
          Apply
        </button>
      </div>
      <div role="status">{check}</div>
    </div>
  );
}
