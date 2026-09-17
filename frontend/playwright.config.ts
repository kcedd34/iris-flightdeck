import { defineConfig, devices } from "@playwright/test";

// End-to-end tests run against a real FlightDeck install (docker compose up -d) through the Vite
// dev server, which proxies /api/flightdeck to it. FLIGHTDECK_PORT selects the install.
const irisPort = process.env.FLIGHTDECK_PORT ?? "52780";

export default defineConfig({
  testDir: "e2e",
  timeout: 90_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  workers: 1,
  reporter: [["list"]],
  globalSetup: "./e2e/setup/global.ts",
  use: { ...devices["Desktop Chrome"], viewport: { width: 1440, height: 900 }, trace: "retain-on-failure" },
  projects: [
    { name: "session", testMatch: /session\.spec\.ts/, use: { baseURL: "http://127.0.0.1:5173/flightdeck/" } },
    { name: "palette", testMatch: /palette\.spec\.ts/, use: { baseURL: "http://127.0.0.1:5173/flightdeck/" } },
    { name: "shell", testMatch: /shell\.spec\.ts/, use: { baseURL: "http://127.0.0.1:5173/flightdeck/" } },
    { name: "fixtures", testMatch: /fixtures\.spec\.ts/, use: { baseURL: "http://127.0.0.1:5174/flightdeck/" } },
    // Reduced IRIS 2026.1 matrix (FR-012a limited mode); skipped on a 2026.2 install.
    { name: "limited", testMatch: /limited\.spec\.ts/, use: { baseURL: "http://127.0.0.1:5173/flightdeck/" } },
  ],
  webServer: [
    {
      command: `FLIGHTDECK_PORT=${irisPort} npx vite --host 127.0.0.1 --port 5173 --strictPort`,
      url: "http://127.0.0.1:5173/flightdeck/",
      reuseExistingServer: true,
      timeout: 120_000,
    },
    {
      command: `FLIGHTDECK_PORT=${irisPort} npx vite --host 127.0.0.1 --port 5174 --strictPort --mode fixtures`,
      url: "http://127.0.0.1:5174/flightdeck/",
      reuseExistingServer: true,
      timeout: 120_000,
    },
  ],
});
