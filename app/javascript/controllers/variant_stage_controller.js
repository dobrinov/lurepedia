import { Controller } from "@hotwired/stimulus"

// Hero color selector: clicking a color swaps the preview image and, on the
// Variations tab, the build table shown there. The choice is reflected in the
// URL as a path segment so it is shareable and survives tab navigation. The
// default "variations" tab is implicit (/lures/<slug>/<color>); other tabs carry
// their name (/lures/<slug>/<tab>/<color>).
export default class extends Controller {
  static targets = [ "chip", "stage", "stageImage", "stageSpinner", "stageGlyph", "stageZoom", "lightbox", "lightboxImage", "lightboxSpinner", "lightboxName", "lightboxUv", "chipName", "chipUv", "buildsTable" ]
  static values = { basePath: String, tabs: Array } // basePath: "/en/lures/<slug>"

  connect() {
    if (this.hasStageImageTarget) {
      this.stageImageTarget.addEventListener("load", () => this.setStageLoading(false))
      this.stageImageTarget.addEventListener("error", () => this.setStageLoading(false))
    }
    if (this.hasLightboxImageTarget) {
      this.lightboxImageTarget.addEventListener("load", () => this.setLightboxLoading(false))
      this.lightboxImageTarget.addEventListener("error", () => this.setLightboxLoading(false))
    }

    const initial = this.chipTargets.find((c) => c.dataset.default === "true") || this.chipTargets[0]
    if (initial) this.show(initial) // initial state only — server already set the URL
  }

  select(event) {
    const chip = event.currentTarget
    this.show(chip)
    this.syncUrl(chip.dataset.colorSlug)
  }

  show(chip) {
    this.chipTargets.forEach((c) => c.classList.toggle("selected", c === chip))
    const d = chip.dataset

    if (this.hasStageImageTarget) {
      if (d.photoUrl) {
        const nextUrl = new URL(d.photoUrl, window.location.href).href
        if (this.stageImageTarget.src !== nextUrl) {
          this.setStageLoading(true)
          this.stageImageTarget.src = d.photoUrl
        }
        this.stageImageTarget.hidden = false
        if (this.hasStageGlyphTarget) this.stageGlyphTarget.hidden = true
      } else {
        this.setStageLoading(false)
        this.stageImageTarget.hidden = true
        if (this.hasStageGlyphTarget) this.stageGlyphTarget.hidden = false
      }
    }

    // The zoom button and its lightbox only make sense with a photo to show.
    if (this.hasStageZoomTarget) this.stageZoomTarget.hidden = !d.photoUrl
    if (this.hasLightboxImageTarget) {
      if (d.photoZoomUrl) {
        const nextZoomUrl = new URL(d.photoZoomUrl, window.location.href).href
        if (this.lightboxImageTarget.src !== nextZoomUrl) {
          this.setLightboxLoading(true)
          this.lightboxImageTarget.src = d.photoZoomUrl
        }
      } else {
        this.setLightboxLoading(false)
        this.lightboxImageTarget.removeAttribute("src")
      }
    }
    if (this.hasLightboxNameTarget) this.lightboxNameTarget.textContent = d.name || ""
    if (this.hasLightboxUvTarget) this.lightboxUvTarget.hidden = d.uv !== "true"

    // Paint the stage with the photo's border color (blank restores the CSS
    // default) so letterbox bars blend into the image.
    if (this.hasStageTarget) this.stageTarget.style.background = d.photoBg || ""

    if (this.hasChipNameTarget) this.chipNameTarget.textContent = d.name || ""
    if (this.hasChipUvTarget) this.chipUvTarget.hidden = d.uv !== "true"

    // Show the build table for the selected color (only present on the Variations tab).
    this.buildsTableTargets.forEach((t) => { t.hidden = t.dataset.colorId !== d.colorId })
  }

  setStageLoading(loading) {
    if (this.hasStageTarget) this.stageTarget.classList.toggle("is-loading", loading)
  }

  setLightboxLoading(loading) {
    if (this.hasLightboxSpinnerTarget) this.lightboxSpinnerTarget.hidden = !loading
  }

  // Lightbox prev/next: cycle through the colors that have photos, keeping the
  // page-level selection (tiles, builds table, URL) in step. Only active while
  // the lightbox is open — the arrow keys are bound at the window level.
  prevColor(event) { this.stepColor(event, -1) }
  nextColor(event) { this.stepColor(event, 1) }

  stepColor(event, delta) {
    if (!this.hasLightboxTarget || this.lightboxTarget.hidden) return
    event.preventDefault()
    const chips = this.chipTargets.filter((c) => c.dataset.photoUrl)
    if (chips.length < 2) return
    const current = chips.findIndex((c) => c.classList.contains("selected"))
    const chip = chips[(current + delta + chips.length) % chips.length]
    this.show(chip)
    this.syncUrl(chip.dataset.colorSlug)
  }

  // Rewrite the color path segment on the address bar and every tab link, so the
  // selection is shareable. The variations tab keeps the color bare.
  syncUrl(colorSlug) {
    if (!this.hasBasePathValue || !colorSlug) return
    let activeHref = null

    this.element.querySelectorAll("a.tab").forEach((link) => {
      const u = new URL(link.href, window.location.origin)
      const tab = this.tabFromPath(u.pathname)
      const href = tab === "variations"
        ? `${this.basePathValue}/${colorSlug}`
        : `${this.basePathValue}/${tab}/${colorSlug}`
      link.setAttribute("href", href)
      if (link.classList.contains("active")) activeHref = href
    })

    if (activeHref) window.history.replaceState({}, "", activeHref)
  }

  // The first segment after the lure base path is the tab — but only if it is a
  // known tab; anything else is a color on the implicit variations tab.
  tabFromPath(pathname) {
    const seg = pathname.slice(this.basePathValue.length).replace(/^\//, "").split("/")[0] || ""
    return this.tabsValue.includes(seg) ? seg : "variations"
  }
}
