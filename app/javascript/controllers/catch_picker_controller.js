import { Controller } from "@hotwired/stimulus"

// Cascading picker for the log-a-catch form: brand → lure → color → build.
//
//   brand  scopes the lure combobox to that brand's lures
//   lure   loads its colors (variants) and builds from the /variation-options JSON
//   color  filters the build select to the builds offered in that color
//
// Brand and lure are async comboboxes (large lists); color and build are native
// selects (a handful per lure). Any level can be preselected from query params —
// the matching *-value attributes are restored once the data loads.
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
      this.resetColors()
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
    this.resetColors()
  }

  // Lure picked: load its colors and builds.
  lureChanged(event) {
    this.selectedVariantValue = ""
    this.selectedBuildValue = ""
    this.loadVariations(event.target.value)
  }

  // Color picked: filter the build select to that color's builds.
  colorChanged() {
    const id = this.colorSelectTarget.value
    const color = this.variations?.colors.find((c) => String(c.id) === String(id))
    this.populateBuilds(color)
  }

  async loadVariations(slug) {
    this.variations = null
    if (!slug) return this.resetColors()
    const url = this.variationsUrlTemplateValue.replace("__SLUG__", encodeURIComponent(slug))
    try {
      const resp = await fetch(url, { headers: { Accept: "application/json" } })
      if (!resp.ok) return this.resetColors()
      this.variations = await resp.json()
    } catch (_e) {
      return this.resetColors()
    }
    this.populateColors()
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
    this.colorChanged()
  }

  populateBuilds(color) {
    const sel = this.buildSelectTarget
    sel.innerHTML = ""
    if (!color) {
      sel.appendChild(this.option("", this.label("choose_build")))
      sel.disabled = true
      return
    }
    const allowed = new Set(color.build_ids || [])
    const builds = this.variations.builds.filter((b) => allowed.has(b.id))
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

  resetColors() {
    this.colorSelectTarget.innerHTML = ""
    this.colorSelectTarget.appendChild(this.option("", this.label("choose_color")))
    this.colorSelectTarget.disabled = true
    this.populateBuilds(null)
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
