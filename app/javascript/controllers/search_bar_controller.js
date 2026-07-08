import { Controller } from "@hotwired/stimulus"

// Reveals the filter panel under the lures-index search field.
// No autocomplete (per design feedback).
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.onDocClick = this.onDocClick.bind(this)
  }

  expand() {
    if (this.hasPanelTarget) this.panelTarget.hidden = false
    document.addEventListener("click", this.onDocClick)
    // On mobile the panel is a full-screen overlay; lock the page behind it so
    // it can't be scrolled into view.
    if (this.isOverlay()) document.body.style.overflow = "hidden"
  }

  collapse() {
    if (this.hasPanelTarget) this.panelTarget.hidden = true
    document.removeEventListener("click", this.onDocClick)
    document.body.style.overflow = ""
  }

  isOverlay() {
    return window.matchMedia("(max-width: 880px)").matches
  }

  onDocClick(event) {
    if (!this.element.contains(event.target)) this.collapse()
  }

  disconnect() {
    document.removeEventListener("click", this.onDocClick)
    document.body.style.overflow = ""
  }
}
