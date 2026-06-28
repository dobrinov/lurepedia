// Shared helpers for the Lurepedia e2e suite.
const { expect } = require("@playwright/test")

// Seeded credentials (see db/seeds.rb): members sign in with password "1".
const MEMBER = { email: "user1@example.com", password: "1" }
const ADMIN = { email: "admin@example.com", password: "1" }

async function signIn(page, who = MEMBER) {
  await page.goto("/en/session/new")
  await page.getByLabel(/email/i).fill(who.email)
  await page.getByLabel(/password/i).fill(who.password)
  await page.getByRole("button", { name: /sign in/i }).click()
  // Landed somewhere other than the sign-in form.
  await expect(page).not.toHaveURL(/\/session\/new/)
}

module.exports = { signIn, MEMBER, ADMIN }
