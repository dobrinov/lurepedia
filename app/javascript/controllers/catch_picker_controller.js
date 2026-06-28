import { Controller } from "@hotwired/stimulus"

// Cascading picker for the log-a-catch form: brand → lure → (color, build).
//
//   brand  scopes the lure combobox to that brand's lures
//   lure   loads its colors (variants) and builds from the /variation-options JSON
//
// Color and build are independent axes of the chosen lure — a catch records a
// color plus an optional build. Brand and lure are async comboboxes (large
// lists); color and build are native selects (a handful per lure). Any level can
// be preselected from query params — the matching *-value attributes are restored
// once the data loads.
export default class extends Controller {
  static targets = [ "lureCombobox", "colorSelect", "buildSelect" ]
  static values = {
    variationsUrlTemplate: String, // "/en/lures/__SLUG__/variation-options"
    lureOptionsUrl: String,        // base lure options endpoint, re-scoped by brand
    lureSlug: String,              // preselected lure (may be empty)
    selectedVariant: String,       // preselected color id (consumed once)
    selectedBuild: String,         // preselected build id (consumed once)
    labels: Object
  }

  connect() {
    this.variations = null
    if (this.lureSlugValue) {
      this.loadVariations(this.lureSlugValue)
    } else {
      this.resetPickers()
    }
  }

  // Brand picked: re-scope the lure combobox and clear everything downstream.
  brandChanged(event) {
    const slug = event.target.value
    const base = this.lureOptionsUrlValue
    const ctrl = this.lureCombobox
    if (ctrl) {
      ctrl.urlValue = slug ? `${base}?brand=${encodeURIComponent(slug)}` : base
      ctrl.clear()
    }
    this.lureSlugValue = ""
    this.variations = null
    this.resetPickers()
  }

  // Lure picked: load its colors and builds.
  lureChanged(event) {
    this.selectedVariantValue = ""
    this.selectedBuildValue = ""
    this.loadVariations(event.target.value)
  }

  async loadVariations(slug) {
    this.variations = null
    if (!slug) return this.resetPickers()
    const url = this.variationsUrlTemplateValue.replace("__SLUG__", encodeURIComponent(slug))
    try {
      const resp = await fetch(url, { headers: { Accept: "application/json" } })
      if (!resp.ok) return this.resetPickers()
      this.variations = await resp.json()
    } catch (_e) {
      return this.resetPickers()
    }
    this.populateColors()
    this.populateBuilds()
  }

  populateColors() {
    const sel = this.colorSelectTarget
    sel.innerHTML = ""
    sel.appendChild(this.option("", this.label("choose_color")))
    this.variations.colors.forEach((c) => sel.appendChild(this.option(c.id, c.name)))
    sel.disabled = false
    const want = String(this.selectedVariantValue || "")
    if (want && this.variations.colors.some((c) => String(c.id) === want)) sel.value = want
    this.selectedVariantValue = ""
  }

  // Every build of the lure is offered, independent of the chosen color.
  populateBuilds() {
    const sel = this.buildSelectTarget
    sel.innerHTML = ""
    const builds = this.variations?.builds || []
    if (builds.length === 0) {
      sel.appendChild(this.option("", this.label("no_builds")))
      sel.disabled = true
      return
    }
    sel.appendChild(this.option("", this.label("choose_build")))
    builds.forEach((b) => {
      const facts = [ b.length, b.depth, b.weight ].filter(Boolean).join(" · ")
      sel.appendChild(this.option(b.id, facts ? `${b.name} — ${facts}` : b.name))
    })
    sel.disabled = false
    const want = String(this.selectedBuildValue || "")
    if (want && builds.some((b) => String(b.id) === want)) sel.value = want
    this.selectedBuildValue = ""
  }

  resetPickers() {
    for (const sel of [ this.colorSelectTarget, this.buildSelectTarget ]) {
      sel.innerHTML = ""
      sel.disabled = true
    }
    this.colorSelectTarget.appendChild(this.option("", this.label("choose_color")))
    this.buildSelectTarget.appendChild(this.option("", this.label("choose_build")))
  }

  // The async-combobox controller instance backing the lure field.
  get lureCombobox() {
    const el = this.lureComboboxTarget.querySelector('[data-controller~="async-combobox"]')
    return el && this.application.getControllerForElementAndIdentifier(el, "async-combobox")
  }

  option(value, label) {
    const o = document.createElement("option")
    o.value = value
    o.textContent = label
    return o
  }

  label(key) {
    return (this.labelsValue && this.labelsValue[key]) || key
  }
}
