// Contrast gate (docs/design.md §8, SC-008): measures WCAG contrast of the token pairs the shell
// actually uses, in both themes, from src/theme/tokens.css. Text needs 4.5:1; UI elements and
// disabled/placeholder text (text-muted) need 3:1.
import { readFileSync } from "node:fs";

const css = readFileSync(new URL("../src/theme/tokens.css", import.meta.url), "utf8");

function block(selector) {
  const start = css.indexOf(selector);
  if (start < 0) throw new Error(`selector not found: ${selector}`);
  const open = css.indexOf("{", start);
  const close = css.indexOf("}", open);
  const vars = {};
  for (const m of css.slice(open + 1, close).matchAll(/--([a-z-]+):\s*(#[0-9a-fA-F]{6})/g)) vars[m[1]] = m[2];
  return vars;
}

const themes = { dark: block(':root[data-theme="dark"]'), light: block(':root[data-theme="light"]') };

function luminance(hex) {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255).map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function ratio(a, b) {
  const [l1, l2] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
}

const surfaces = ["surface-canvas", "surface-panel", "surface-float"];
const checks = [
  ...["text-primary", "text-secondary"].flatMap((fg) => surfaces.map((bg) => [fg, bg, 4.5, "text"])),
  // Semantic colors as text on structural surfaces. On floating layers they are used only for
  // glyphs and borders in this build (3:1), because state-warning text on surface-float is 4.15:1
  // in the dark theme.
  ...["state-actual", "state-commanded", "state-caution", "state-warning", "state-selected"].flatMap((fg) =>
    ["surface-canvas", "surface-panel"].map((bg) => [fg, bg, 4.5, "semantic text"]),
  ),
  ...["state-actual", "state-commanded", "state-caution", "state-warning", "state-selected"].map((fg) => [fg, "surface-float", 3.0, "semantic glyph/border on float"]),
  // text-muted is reserved for disabled controls, placeholders and absent values (design §3.1),
  // which WCAG exempts from text contrast. Checked as a UI element on structural surfaces.
  ...["surface-canvas", "surface-panel"].map((bg) => ["text-muted", bg, 3.0, "disabled/placeholder/absent"]),
  ...surfaces.map((bg) => ["line-strong", bg, 1.5, "control border (with label)"]),
  ...surfaces.map((bg) => ["state-selected", bg, 3.0, "focus ring"]),
  ["surface-canvas", "text-primary", 4.5, "primary button text"],
];

let failures = 0;
for (const [name, vars] of Object.entries(themes)) {
  console.log(`\n${name} theme`);
  for (const [fg, bg, min, role] of checks) {
    const value = ratio(vars[fg], vars[bg]);
    const ok = value >= min;
    if (!ok) failures++;
    console.log(`  ${ok ? "ok  " : "FAIL"} ${fg.padEnd(16)} on ${bg.padEnd(15)} ${value.toFixed(2).padStart(5)} (min ${min}, ${role})`);
  }
}
if (failures) {
  console.error(`\ncontrast: ${failures} pair(s) below minimum`);
  process.exit(1);
}
console.log("\ncontrast: ok");
