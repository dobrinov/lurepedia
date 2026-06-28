const { test, expect } = require("@playwright/test")
const { signIn } = require("./helpers")

test.describe("Contributing (signed in)", () => {
  test.beforeEach(async ({ page }) => {
    await signIn(page)
  })

  test("a member can favorite a lure", async ({ page }) => {
    await page.goto("/en/lures/megabass-vision-110")
    // Start from a clean state: if already favorited, unfavorite first.
    const favorited = page.getByRole("button", { name: /favorited/i })
    if (await favorited.count()) await favorited.click()

    await page.getByRole("button", { name: /^☆?\s*Favorite$/i }).click()
    await expect(page.getByRole("button", { name: /favorited/i })).toBeVisible()
  })

  test("a member's edit is filed as a suggestion for review", async ({ page }) => {
    await page.goto("/en/lures/megabass-vision-110")
    await page.getByRole("link", { name: /suggest an edit/i }).click()
    await expect(page).toHaveURL(/\/lures\/megabass-vision-110\/edit/)

    await page.locator("textarea[name='lure[blurb]']").fill("An e2e-suggested blurb " + Date.now())
    await page.getByRole("button", { name: /^Submit$/ }).click()

    await expect(page.getByText(/Suggestion submitted/i)).toBeVisible()
  })

  test("a member can log a catch", async ({ page }) => {
    // Prefill the brand → lure → species cascade via query params.
    await page.goto("/en/catches/new?lure=megabass-vision-110&species=largemouth-bass")

    // The color select is populated by JS once the lure's variations load.
    const color = page.locator("select[name='catch[variant_id]']")
    await expect(color).toBeEnabled()
    await color.selectOption({ index: 1 })

    await page.getByRole("button", { name: /^Submit$/ }).click()
    await expect(page.getByText(/Submitted for review/i)).toBeVisible()
  })
})
