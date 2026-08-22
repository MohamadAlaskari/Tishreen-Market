// Eigene Vitest-Config, damit Vitest nicht die vite.config.ts
// (TanStack-Start- und Devtools-Plugins) für Unit-Tests lädt.
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    // Phase 1 hat noch keine Komponenten mit Logik (docs/13 §1) —
    // der CI-Schritt existiert ab P1-T8, Tests folgen mit den Features.
    passWithNoTests: true,
  },
});
