const { test, expect } = require("@playwright/test")
const { signIn } = require("./helpers")

test.describe("Shop shipping-country multi-select", () => {
  test("a member can pick several shipping countries as chips", async ({ page }) => {
    await signIn(page)
    await page.goto("/en/shops/new")

    const ms = page.locator(".country-multiselect")
    const hidden = ms.locator("input[name='shop[ships_to]']")

    await ms.locator(".combobox-trigger").click()
    await ms.locator(".combobox-search input").fill("united states")
    await ms.getByRole("button", { name: /United States/i }).click()

    await ms.locator(".combobox-search input").fill("canada")
    await ms.getByRole("button", { name: /Canada/i }).click()

    // Two removable chips, both codes in the hidden comma-separated value.
    await expect(ms.locator(".ms-chip")).toHaveCount(2)
    await expect(hidden).toHaveValue(/US/)
    await expect(hidden).toHaveValue(/CA/)

    // Removing a chip drops it from the value.
    await ms.locator(".ms-chip", { hasText: "Canada" }).locator(".ms-chip-x").click()
    await expect(ms.locator(".ms-chip")).toHaveCount(1)
    await expect(hidden).not.toHaveValue(/CA/)
  })

  test("the country multi-select appears in the design system", async ({ page }) => {
    await page.goto("/en/design-system")
    await page.getByRole("button", { name: "Buttons & Forms" }).click()
    const ms = page.locator(".country-multiselect")
    await expect(ms).toBeVisible()
    await expect(ms.locator(".ms-chip")).toHaveCount(3) // US, CA, GB preselected
  })
})
