import { appendFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";

/**
 * The record of operations whose effect a test actually verified (feature 008).
 *
 * `check-coverage.py` proves an operation is *reachable*. This proves one was *executed and its
 * result read back*, which is a different claim and the one that was missing: 165 of 268 shipped
 * operations had never run at all, and the gate reported them as covered because a descriptor
 * existed.
 *
 * A file-level measurement — "the spec that fires this also contains a read somewhere" — is not
 * enough, because it cannot tell whether the read was of *that object* after *that mutation*. So the
 * record is written by this helper and only by this helper: a test calls it with the operation it
 * just performed, the object it performed it on, and a function that re-reads that object through the
 * official API and asserts on what came back. Nothing is recorded unless that function runs and
 * returns without throwing.
 *
 * The helper records. It never fixes, never retries and never softens an assertion: if the read-back
 * disagrees with what the mutation claimed, the test fails and the operation stays unverified, which
 * is the entire point.
 */

const RECORD = resolve(process.cwd(), "test-results", "effects.ndjson");

export interface EffectEvidence {
  /** The official operation, as `METHOD /v2/path` — the form the coverage document uses. */
  operationId: string;
  /** What it acted on, so the record shows the read was of the same object. */
  subject: string;
  /** What the independent read proved. */
  proves: string;
}

/**
 * Runs `readBack` — an independent read of the same object through the official API, with its
 * assertions — and records the operation as effect-verified only if it passes.
 */
export async function verifiedEffect<T>(evidence: EffectEvidence, readBack: () => Promise<T>): Promise<T> {
  const result = await readBack();
  mkdirSync(dirname(RECORD), { recursive: true });
  appendFileSync(
    RECORD,
    JSON.stringify({
      operationId: evidence.operationId,
      subject: evidence.subject,
      proves: evidence.proves,
      at: new Date().toISOString(),
    }) + "\n",
    "utf8",
  );
  return result;
}

/**
 * For reads: the operation *is* the observation, so there is nothing to read back afterwards. The
 * evidence is that the answer was inspected rather than counted — `readBack` must assert on the
 * content it returns.
 */
export async function verifiedRead<T>(operationId: string, proves: string, readBack: () => Promise<T>): Promise<T> {
  return verifiedEffect({ operationId, subject: "the answer itself", proves }, readBack);
}
