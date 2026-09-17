import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const irisPort = process.env.FLIGHTDECK_PORT ?? "52780";

export default defineConfig({
  base: "/flightdeck/",
  plugins: [react()],
  server: {
    // /mnt/d is DrvFs under WSL2: inotify events do not arrive, so watch by polling.
    watch: { usePolling: true, interval: 300 },
    proxy: {
      "/api/flightdeck": { target: `http://localhost:${irisPort}`, changeOrigin: false },
    },
  },
  build: { outDir: "dist", assetsDir: "assets", sourcemap: false },
  test: {
    environment: "jsdom",
    globals: true,
    include: ["test/**/*.test.{ts,tsx}"],
    exclude: ["e2e/**", "node_modules/**"],
    setupFiles: ["test/setup.ts"],
  },
});
