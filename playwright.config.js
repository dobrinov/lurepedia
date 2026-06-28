// @ts-check
const { defineConfig, devices } = require("@playwright/test")

// Happy-path end-to-end suite. Runs against an isolated Rails server on port
// 3201 backed by a dedicated seeded SQLite db (see bin/e2e-server), so it never
// touches the development database.
const PORT = process.env.E2E_PORT || 3201
const BASE_URL = `http://127.0.0.1:${PORT}`

module.exports = defineConfig({
  testDir: "./e2e",
  fullyParallel: false,
  workers: 1,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? "list" : [ [ "list" ], [ "html", { open: "never" } ] ],
  timeout: 30_000,
  expect: { timeout: 7_000 },
  use: {
    baseURL: BASE_URL,
    locale: "en-US",
    trace: "on-first-retry",
    screenshot: "only-on-failure"
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } }
  ],
  webServer: {
    command: "bin/e2e-server",
    url: `${BASE_URL}/up`,
    timeout: 120_000,
    reuseExistingServer: true
  }
})
