// Design-token gate (Constitution X, docs/design.md §3 and §7). Fails the build on:
//  - any color literal (hex, rgb/rgba, hsl/hsla) outside src/theme/tokens.css
//  - any border-radius other than 0, 2px, 6px, 50% or a --r-* token
//  - any transition or animation duration above 200ms
//  - any text-transform: uppercase
// Spacing is not checked against the 4px scale: docs/prototype.html, which prevails for the
// components it implements (design §10), uses off-scale spacing itself.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const root = new URL("../src", import.meta.url).pathname;
const failures = [];

function walk(dir) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path);
    else if (/\.(css|ts|tsx)$/.test(name)) check(path);
  }
}

function check(path) {
  const rel = relative(root, path);
  const text = readFileSync(path, "utf8");
  const lines = text.split("\n");
  lines.forEach((line, i) => {
    const where = `src/${rel}:${i + 1}`;
    const code = line.replace(/\/\/.*$|\/\*.*?\*\//g, "");
    if (rel !== "theme/tokens.css") {
      if (/#[0-9a-fA-F]{3,8}\b/.test(code) && !/&#|href="#|#root|url\(#/.test(code)) failures.push(`${where} color literal: ${line.trim()}`);
      if (/\b(rgba?|hsla?)\(/.test(code)) failures.push(`${where} color function: ${line.trim()}`);
    }
    const radius = code.match(/border-radius\s*:\s*([^;]+)/);
    if (radius && !/^(0|2px|6px|50%|var\(--r-[a-z-]+\))$/.test(radius[1].trim())) {
      failures.push(`${where} off-hierarchy radius: ${radius[1].trim()}`);
    }
    for (const m of code.matchAll(/(\d+(?:\.\d+)?)(ms|s)\b/g)) {
      const ms = m[2] === "s" ? parseFloat(m[1]) * 1000 : parseFloat(m[1]);
      // Named exception (docs/design.md §6, feature 002 research R12): the dry-run reveal's 240ms
      // decay of changed rows, in the shared dry-run stylesheet only.
      const dryRunReveal = rel === "mutation/dryrun.css" && ms === 240;
      if (/transition|animation|--t-/.test(code) && ms > 200 && !dryRunReveal) failures.push(`${where} motion over 200ms: ${line.trim()}`);
    }
    if (/text-transform\s*:\s*uppercase/.test(code) || /textTransform:\s*["']uppercase/.test(code)) {
      failures.push(`${where} uppercase transform`);
    }
  });
}

walk(root);
if (failures.length) {
  console.error(`check-tokens: ${failures.length} violation(s)`);
  for (const f of failures) console.error("  " + f);
  process.exit(1);
}
console.log("check-tokens: ok");
