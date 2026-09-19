import { appendFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { ADMIN, IRIS } from "./users";

/**
 * What the run actually ran against, recorded before anything else (feature 008).
 *
 * A port is not an identity. The matrix was reported for three releases while two of the three
 * containers were the same product, because `iris-flightdeck:local` had been overwritten by an IRIS
 * for Health build and the port was read as if it named the image
 * (verification/functional-coverage.md, "A correction to an earlier version of this table").
 *
 * So the run asks the instance what it is, and records it with **the hash of the bundle that instance
 * actually served**. That second half matters as much as the first: a rebuilt image on an existing
 * volume keeps serving the old assets, because the installer skips on its marker and the web root
 * lives in the durable volume. Recording what was served is the only way a later gate can tell a
 * matrix that exercised this build from one that exercised the previous one.
 *
 * The file accumulates across runs on purpose — one Playwright run can only ever see one install —
 * and is not committed. `scripts/build/check-matrix-identity.py` reads it.
 */

const RECORD = resolve(process.cwd(), ".matrix", "instances.ndjson");

interface Info {
  result: { product?: string; apiVersion?: number; serverVersion?: string };
}

function basic(): string {
  return "Basic " + Buffer.from(`${ADMIN.user}:${ADMIN.password}`).toString("base64");
}

async function sha256(bytes: ArrayBuffer): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** The asset the instance itself serves, not the one on disk. */
async function servedBundle(): Promise<{ path: string; sha: string } | null> {
  const page = await fetch(`${IRIS}/flightdeck/`, { headers: { Authorization: basic() } });
  if (!page.ok) return null;
  const html = await page.text();
  const path = /\/flightdeck\/assets\/(index-[^"']+\.js)/.exec(html)?.[0];
  if (!path) return null;
  const asset = await fetch(`${IRIS}${path}`, { headers: { Authorization: basic() } });
  if (!asset.ok) return null;
  return { path, sha: await sha256(await asset.arrayBuffer()) };
}

export async function recordInstanceIdentity(): Promise<void> {
  let info: Info["result"] = {};
  try {
    const response = await fetch(`${IRIS}/api/admin/info`, { headers: { Authorization: basic() } });
    if (response.ok) info = ((await response.json()) as Info).result ?? {};
  } catch {
    // An instance that cannot answer /info is a failure the suite itself reports; the gate then sees
    // no record for it, which is the same verdict by a different route.
    return;
  }
  const bundle = await servedBundle();
  if (!info.product || !info.apiVersion || !bundle) return;
  mkdirSync(dirname(RECORD), { recursive: true });
  appendFileSync(
    RECORD,
    JSON.stringify({
      product: info.product,
      apiVersion: info.apiVersion,
      serverVersion: info.serverVersion ?? "",
      origin: IRIS,
      servedBundle: bundle.path,
      servedSha256: bundle.sha,
      at: new Date().toISOString(),
    }) + "\n",
    "utf8",
  );
}
