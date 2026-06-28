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

  test("selected countries render as tags inside the control and float to the top of the list", async ({ page }) => {
    await signIn(page)
    await page.goto("/en/shops/new")

    const ms = page.locator(".country-multiselect")
    const trigger = ms.locator(".combobox-trigger")

    // Nothing chosen yet: the placeholder shows and there are no tags.
    await expect(ms.locator(".ms-placeholder")).toBeVisible()
    await expect(trigger.locator(".ms-chip")).toHaveCount(0)

    // Pick two countries out of alphabetical order.
    await trigger.click()
    await ms.locator(".combobox-search input").fill("united states")
    await ms.getByRole("button", { name: /United States/i }).click()
    await ms.locator(".combobox-search input").fill("canada")
    await ms.getByRole("button", { name: /Canada/i }).click()

    // Back on the full list, the selected ones float to the top (A–Z within the
    // group) and are marked as chosen.
    await ms.locator(".combobox-search input").fill("")
    await expect(ms.locator(".combobox-option").nth(0)).toContainText("Canada")
    await expect(ms.locator(".combobox-option").nth(1)).toContainText("United States")
    await expect(ms.locator(".combobox-option.active")).toHaveCount(2)

    // Closed, the tags live INSIDE the trigger box and the placeholder is gone.
    await page.keyboard.press("Escape")
    await expect(trigger.locator(".ms-chip")).toHaveCount(2)
    await expect(ms.locator(".ms-placeholder")).toBeHidden()
  })

  test("removing a tag does not reopen the dropdown", async ({ page }) => {
    await signIn(page)
    await page.goto("/en/shops/new")

    const ms = page.locator(".country-multiselect")
    await ms.locator(".combobox-trigger").click()
    await ms.locator(".combobox-search input").fill("canada")
    await ms.getByRole("button", { name: /Canada/i }).click()
    await page.keyboard.press("Escape")
    await expect(ms.locator(".combobox-panel")).toBeHidden()

    // Clicking the tag's × removes it without toggling the panel back open.
    await ms.locator(".combobox-trigger .ms-chip-x").first().click()
    await expect(ms.locator(".combobox-trigger .ms-chip")).toHaveCount(0)
    await expect(ms.locator(".combobox-panel")).toBeHidden()
  })

  test("the country multi-select appears in the design system", async ({ page }) => {
    await page.goto("/en/design-system")
    await page.getByRole("button", { name: "Buttons & Forms" }).click()
    const ms = page.locator(".country-multiselect")
    await expect(ms).toBeVisible()
    await expect(ms.locator(".combobox-trigger .ms-chip")).toHaveCount(3) // US, CA, GB preselected, shown inside the box
  })

  test("the add-a-shop modal uses the country multi-select", async ({ page }) => {
    await signIn(page)
    await page.goto("/en/lures/megabass-vision-110/buy")
    await page.getByRole("button", { name: /add a place to buy/i }).click()
    await page.getByText("New shop", { exact: true }).click()

    const ms = page.locator(".modal .country-multiselect")
    await ms.locator(".combobox-trigger").click()
    await ms.locator(".combobox-search input").fill("germany")
    await ms.getByRole("button", { name: /Germany/i }).click()
    await expect(ms.locator("input[name='new_shop[ships_to]']")).toHaveValue(/DE/)
  })
})
