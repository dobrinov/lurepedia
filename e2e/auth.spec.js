const { test, expect } = require("@playwright/test")
const { signIn, MEMBER } = require("./helpers")

test.describe("Authentication", () => {
  test("a member can sign in", async ({ page }) => {
    await signIn(page, MEMBER)
    // The sign-in entry point is gone once authenticated.
    await page.goto("/en")
    await expect(page.getByRole("link", { name: /sign in/i })).toHaveCount(0)
  })

  test("signing in is required to log a catch", async ({ page }) => {
    await page.goto("/en/catches/new")
    await expect(page).toHaveURL(/\/session\/new/)
  })
})
