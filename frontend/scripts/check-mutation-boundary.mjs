// Mutation-boundary gate (Constitution V, feature 002 research R12). The diff, confirmation and
// session trail exist once, in src/mutation/. This gate fails the build when any other module:
//  - reads or writes sessionStorage, or calls window.confirm;
//  - imports mutation internals (only src/mutation/useMutation and src/mutation/TrailPanel are public);
//  - renders a diff view (data-diff, a COMMANDED column);
//  - under src/domains/ or src/pattern/, renders a dialog (@radix-ui/react-dialog, role="dialog",
//    role="alertdialog").
// Declared exceptions carry their reason. Adding one is a reviewed decision.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const root = new URL("../src", import.meta.url).pathname;
const PUBLIC_MUTATION = new Set(["mutation/useMutation", "mutation/TrailPanel"]);

const DIALOG_EXCEPTIONS = new Map([
  ["palette/CommandPalette.tsx", "the command palette is a floating layer, not a confirmation"],
  ["session/ReauthOverlay.tsx", "re-authentication overlay from feature 001"],
  ["pattern/ListInspector.tsx", "inspector overlay below 1280px (design §8)"],
]);
const STORAGE_EXCEPTIONS = new Map([]);

const failures = [];

function walk(dir) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path);
    else if (/\.(ts|tsx)$/.test(name) && !/\.test\.tsx?$/.test(name)) check(path);
  }
}

function stripComments(text) {
  return text.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:"'`])\/\/.*$/gm, "$1");
}

function check(path) {
  const rel = relative(root, path);
  if (rel.startsWith("mutation/")) return;
  const code = stripComments(readFileSync(path, "utf8"));
  const lines = code.split("\n");
  lines.forEach((line, i) => {
    const where = `src/${rel}:${i + 1}`;
    if (/\bsessionStorage\b/.test(line) && !STORAGE_EXCEPTIONS.has(rel)) failures.push(`${where} uses sessionStorage (the trail store lives in src/mutation/)`);
    if (/\bwindow\.confirm\b|(^|[^.\w])confirm\s*\(/.test(line)) failures.push(`${where} calls confirm() (use the shared dry-run)`);
    const imported = line.match(/from\s+["'](?:\.\.?\/)+(mutation\/[A-Za-z0-9_./-]+)["']/);
    if (imported && !PUBLIC_MUTATION.has(imported[1].replace(/\.(ts|tsx)$/, ""))) failures.push(`${where} imports mutation internals (${imported[1]})`);
    if (/data-diff|["'`>]\s*COMMANDED\s*["'`<]/.test(line)) failures.push(`${where} renders a diff view (use the shared dry-run)`);
    if ((rel.startsWith("domains/") || rel.startsWith("pattern/")) && !DIALOG_EXCEPTIONS.has(rel)) {
      if (/@radix-ui\/react-dialog|role=["'](alert)?dialog["']/.test(line)) failures.push(`${where} renders a dialog (confirmations use the shared dry-run)`);
    }
  });
}

walk(root);

if (failures.length) {
  console.error("check-mutation-boundary: confirmation, diff or trail code outside src/mutation/.\n");
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}
console.log(`check-mutation-boundary: ok (${DIALOG_EXCEPTIONS.size + STORAGE_EXCEPTIONS.size} declared exceptions)`);
