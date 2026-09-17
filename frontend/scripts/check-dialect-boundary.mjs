// Dialect-boundary gate (Constitution I and III dialect notes; feature 001 T109). Fails the build
// when code outside the SysAdmin API dialect layer asks which API version or dialect the instance
// speaks. Whether an operation exists comes only from the capability map (`available`,
// FlightDeck.Admin.Client.Has / UnavailableReason).
//
// Checked: backend/cls, backend/test, frontend/src, frontend/e2e (.cls, .ts, .tsx), comments removed.
// Flagged: the identifiers dialect / Dialect, limited, Limited(...) and apiVersion in code, and a
// string literal that is exactly one of those names (e.g. %Get("dialect"), body["limited"]).
// Other string contents (UI text, test titles, test ids such as "limited-mode-indicator") are not
// version checks and are ignored.
// Allowed: the dialect layer (FlightDeck.Admin), the installer (bootstrap, runs before the map
// exists), and the declared exceptions below, each with its reason. Adding an exception is a
// reviewed decision, not a way to make the build pass.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const repo = new URL("../..", import.meta.url).pathname;
const roots = ["backend/cls", "backend/test", "frontend/src", "frontend/e2e"];

const ALLOWED_PREFIXES = [
  ["backend/cls/FlightDeck/Admin/", "the dialect layer itself"],
  ["backend/cls/FlightDeck/Install/Installer.cls", "installer bootstrap: checks the API before any capability map exists"],
];

const DECLARED_EXCEPTIONS = [
  ["backend/test/FlightDeck/Test/Dialect.cls", "tests dialect selection, which is its object"],
  ["backend/test/FlightDeck/Test/V1Translations.cls", "verifies the v1 translations, which exist only on the v1 dialect"],
  ["backend/cls/FlightDeck/API/Session.cls", "reports instance.dialect and apiVersion as diagnostics only; no decision reads them"],
  ["backend/cls/FlightDeck/API/OpenAPI.cls", "generated verbatim from the contract, which documents the diagnostic fields"],
  ["frontend/e2e/setup/users.ts", "test infrastructure: creates e2e users through whichever admin API the install exposes"],
];

const NAMES = /^(dialect|Dialect|limited|Limited|apiVersion)$/;
const FLAGGED = /(?<![-\w$])(dialect|Dialect|limited|apiVersion)(?![-\w])|(?<![-\w$])Limited\s*\(/;

// Blanks string literal contents, keeping a literal that is exactly a flagged name.
function maskStrings(line, quotes) {
  let out = "", quote = null, content = "";
  for (const c of line) {
    if (quote) {
      if (c === quote) {
        out += quote + (NAMES.test(content) ? content : "") + quote;
        quote = null;
        content = "";
      } else content += c;
    } else if (quotes.includes(c)) {
      quote = c;
    } else out += c;
  }
  return out;
}

function stripComments(line, ext) {
  if (ext === "cls") {
    if (/^\s*(\/\/\/|\/\/|;|#;)/.test(line)) return "";
    return cutOutsideStrings(line, "//", ['"']);
  }
  return cutOutsideStrings(line.replace(/\/\*.*?\*\//g, ""), "//", ['"', "'", "`"]);
}

// Removes a trailing comment marker only when it is not inside a string literal.
function cutOutsideStrings(line, marker, quotes) {
  let quote = null;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (quote) {
      if (c === quote) quote = null;
    } else if (quotes.includes(c)) {
      quote = c;
    } else if (line.startsWith(marker, i) && (i === 0 || line[i - 1] !== ":")) {
      return line.slice(0, i);
    }
  }
  return line;
}

const failures = [];

function walk(dir) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path);
    else if (/\.(cls|ts|tsx)$/.test(name)) check(path);
  }
}

function check(path) {
  const rel = relative(repo, path);
  if (ALLOWED_PREFIXES.some(([p]) => rel.startsWith(p))) return;
  if (DECLARED_EXCEPTIONS.some(([p]) => rel === p)) return;
  const ext = rel.split(".").pop();
  let block = false;
  readFileSync(path, "utf8")
    .split("\n")
    .forEach((line, i) => {
      let text = line;
      if (ext !== "cls") {
        if (block) {
          const end = text.indexOf("*/");
          if (end < 0) return;
          text = text.slice(end + 2);
          block = false;
        }
        const start = text.indexOf("/*");
        if (start >= 0 && text.indexOf("*/", start) < 0) {
          text = text.slice(0, start);
          block = true;
        }
      }
      const code = maskStrings(stripComments(text, ext), ext === "cls" ? ['"'] : ['"', "'", "`"]);
      if (FLAGGED.test(code)) failures.push(`${rel}:${i + 1}: ${line.trim()}`);
    });
}

for (const r of roots) walk(join(repo, r));

if (failures.length) {
  console.error("check-dialect-boundary: version or dialect checks outside the dialect layer.");
  console.error("Decide availability from the capability map (available / Client.Has), or declare an exception with its reason.\n");
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}
console.log(`check-dialect-boundary: ok (${DECLARED_EXCEPTIONS.length} declared exceptions)`);
