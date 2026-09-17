import js from "@eslint/js";
import tseslint from "typescript-eslint";
import reactHooks from "eslint-plugin-react-hooks";
import globals from "globals";

const colorLiteral = "/#[0-9a-fA-F]{3,8}\\b|\\b(rgb|rgba|hsl|hsla)\\(/";

export default tseslint.config(
  { ignores: ["dist/", "node_modules/", "test-results/", "playwright-report/"] },
  js.configs.recommended,
  {
    files: ["scripts/**/*.mjs", "*.config.{js,ts}"],
    languageOptions: { globals: { ...globals.node } },
  },
  ...tseslint.configs.recommended,
  {
    files: ["src/**/*.{ts,tsx}", "test/**/*.{ts,tsx}", "e2e/**/*.ts"],
    languageOptions: { globals: { ...globals.browser } },
    plugins: { "react-hooks": reactHooks },
    rules: {
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "warn",
    },
  },
  {
    // Constitution X: no color literal outside theme/tokens.css.
    files: ["src/**/*.{ts,tsx}"],
    rules: {
      "no-restricted-syntax": [
        "error",
        { selector: `Literal[value=${colorLiteral}]`, message: "Color literals are forbidden; use theme tokens." },
        { selector: `TemplateElement[value.raw=${colorLiteral}]`, message: "Color literals are forbidden; use theme tokens." },
      ],
    },
  },
  ...[
    { ignores: ["src/api/client.ts", "src/prefs/storage.ts", "src/mutation/trail.ts"], fetch: true, storage: true, session: true },
    { only: "src/api/client.ts", fetch: false, storage: true, session: true },
    { only: "src/prefs/storage.ts", fetch: true, storage: false, session: true },
    // Feature 002 spec FR-014 (author decision 2026-09-17): the session trail, and only the trail,
    // lives in this tab's sessionStorage. Safe mode stays memory-only (Constitution IV).
    { only: "src/mutation/trail.ts", fetch: true, storage: true, session: false },
  ].map((c) => ({
    // Only src/api/client.ts may call fetch. Constitution IV: only src/prefs/storage.ts may touch
    // localStorage, only src/mutation/trail.ts may touch sessionStorage, and nothing may touch cookies.
    files: c.only ? [c.only] : ["src/**/*.{ts,tsx}"],
    ...(c.ignores ? { ignores: c.ignores } : {}),
    rules: {
      "no-restricted-globals": [
        "error",
        ...(c.fetch ? [{ name: "fetch", message: "Use src/api/client.ts." }] : []),
        ...(c.storage
          ? [
              { name: "localStorage", message: "Use src/prefs/storage.ts." },
              ...(c.session ? [{ name: "sessionStorage", message: "Session storage is forbidden outside src/mutation/trail.ts." }] : []),
              { name: "indexedDB", message: "IndexedDB is forbidden." },
            ]
          : c.session
            ? [{ name: "sessionStorage", message: "Session storage is forbidden outside src/mutation/trail.ts." }]
            : []),
      ],
      "no-restricted-properties": [
        "error",
        { object: "document", property: "cookie", message: "FlightDeck never reads or writes cookies." },
        ...(c.session ? [{ object: "window", property: "sessionStorage", message: "Session storage is forbidden outside src/mutation/trail.ts." }] : []),
        ...(c.storage
          ? [
              { object: "window", property: "localStorage", message: "Use src/prefs/storage.ts." },
              { object: "window", property: "indexedDB", message: "IndexedDB is forbidden." },
            ]
          : []),
      ],
    },
  })),
);
