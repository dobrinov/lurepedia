const { test, expect } = require("@playwright/test")
const { signIn, ADMIN } = require("./helpers")

test.describe("Moderation (admin)", () => {
  test("an admin can review the queue and approve a pending item", async ({ page }) => {
    await signIn(page, ADMIN)
    await page.goto("/en/moderation")
    await expect(page).toHaveURL(/\/moderation/)

    const approve = page.getByRole("button", { name: /^Approve$/ })
    const before = await approve.count()
    expect(before).toBeGreaterThan(0)

    await approve.first().click()
    // Approving actions the item, so one fewer pending row offers Approve.
    await expect(page.getByRole("button", { name: /^Approve$/ })).toHaveCount(before - 1)
  })
})
