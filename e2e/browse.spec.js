const { test, expect } = require("@playwright/test")

// Public, read-only browsing — no auth required.
test.describe("Browsing the catalog", () => {
  test("home shows the lure catalog", async ({ page }) => {
    await page.goto("/en")
    await expect(page).toHaveTitle(/Lurepedia/i)
    await expect(page.getByRole("link", { name: /Vision 110/i }).first()).toBeVisible()
  })

  test("lures index lists lures and links to a detail page", async ({ page }) => {
    await page.goto("/en/lures")
    const card = page.getByRole("link", { name: /Vision 110/i }).first()
    await expect(card).toBeVisible()
    await card.click()
    await expect(page).toHaveURL(/\/en\/lures\/megabass-vision-110/)
    await expect(page.getByRole("heading", { name: "Vision 110" })).toBeVisible()
  })

  test("lures can be filtered by type", async ({ page }) => {
    await page.goto("/en/lures?type=jerkbait")
    await expect(page.getByRole("link", { name: /Vision 110/i }).first()).toBeVisible()
    // A crankbait should not appear under the jerkbait filter.
    await expect(page.getByRole("link", { name: /Squarebill/i })).toHaveCount(0)
  })

  test("lure detail shows brand, colors and switches color on click", async ({ page }) => {
    await page.goto("/en/lures/megabass-vision-110")
    await expect(page.getByRole("heading", { name: "Vision 110" })).toBeVisible()
    await expect(page.getByText("Megabass", { exact: true }).first()).toBeVisible()

    const tiles = page.locator(".color-tile")
    await expect(tiles.first()).toBeVisible()
    // Each swatch carries its color name for the hover tooltip.
    await expect(page.locator(".color-tile-tip").first()).toHaveAttribute("data-tooltip", /.+/)

    // Clicking a second color updates the hero chip name.
    const chip = page.locator("[data-variant-stage-target='chipName']")
    const firstName = await chip.textContent()
    await tiles.nth(1).click()
    await expect(chip).not.toHaveText(firstName || "")
  })

  test("brand, species and shop pages render", async ({ page }) => {
    await page.goto("/en/brands/megabass")
    await expect(page.getByRole("heading", { name: /Megabass/i })).toBeVisible()

    await page.goto("/en/species")
    await page.getByRole("link", { name: /Largemouth Bass/i }).first().click()
    await expect(page).toHaveURL(/\/en\/species\//)

    await page.goto("/en/shops")
    await expect(page.getByText(/Bass Pro Shops/i)).toBeVisible()
  })

  test("leaderboard renders", async ({ page }) => {
    await page.goto("/en/leaderboard")
    await expect(page.getByRole("heading", { name: /Leaderboard/i }).first()).toBeVisible()
  })

  test("search returns matching lures", async ({ page }) => {
    await page.goto("/en/search?q=Vision")
    await expect(page.getByRole("link", { name: /Vision 110/i }).first()).toBeVisible()
  })

  test("locale switch keeps you on the catalog", async ({ page }) => {
    await page.goto("/bg/lures")
    await expect(page).toHaveURL(/\/bg\/lures/)
    await expect(page.getByRole("link", { name: /Vision 110/i }).first()).toBeVisible()
  })
})
