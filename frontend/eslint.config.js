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
    { ignores: ["src/api/client.ts", "src/prefs/storage.ts"], fetch: true, storage: true },
    { only: "src/api/client.ts", fetch: false, storage: true },
    { only: "src/prefs/storage.ts", fetch: true, storage: false },
  ].map((c) => ({
    // Only src/api/client.ts may call fetch. Constitution IV: only src/prefs/storage.ts may touch
    // browser storage, and nothing may touch cookies.
    files: c.only ? [c.only] : ["src/**/*.{ts,tsx}"],
    ...(c.ignores ? { ignores: c.ignores } : {}),
    rules: {
      "no-restricted-globals": [
        "error",
        ...(c.fetch ? [{ name: "fetch", message: "Use src/api/client.ts." }] : []),
        ...(c.storage
          ? [
              { name: "localStorage", message: "Use src/prefs/storage.ts." },
              { name: "sessionStorage", message: "Session storage is forbidden." },
              { name: "indexedDB", message: "IndexedDB is forbidden." },
            ]
          : [{ name: "sessionStorage", message: "Session storage is forbidden." }]),
      ],
      "no-restricted-properties": [
        "error",
        { object: "document", property: "cookie", message: "FlightDeck never reads or writes cookies." },
        { object: "window", property: "sessionStorage", message: "Session storage is forbidden." },
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
