# End-to-end tests (Playwright)

Happy-path browser tests for Lurepedia. These are **dev-only** tooling — the app
itself still has no Node build step (importmap + Propshaft).

## Running

```bash
npm install                 # once: installs @playwright/test
npx playwright install chromium   # once: downloads the browser
npm run test:e2e            # run the suite
npm run test:e2e:ui         # interactive UI mode
```

`playwright.config.js` starts an **isolated** Rails server via `bin/e2e-server`
on port 3201, backed by a dedicated seeded SQLite database
(`storage/e2e.sqlite3`) — it never touches `storage/development.sqlite3`. If a
server is already answering on 3201 it is reused.

## What's covered

- **browse.spec.js** — home, lures index + type filter, lure detail (colors,
  tooltip, color switch), brand/species/shop pages, leaderboard, search,
  locale switch.
- **auth.spec.js** — member sign-in; sign-in gate on contribution routes.
- **contribute.spec.js** — favorite a lure, file an edit suggestion, log a catch.
- **admin.spec.js** — review the moderation queue and approve a pending item.

Seeded credentials (see `db/seeds.rb`): `admin@example.com` / `user1@example.com`,
password `1`.
