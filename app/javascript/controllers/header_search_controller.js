import { Controller } from "@hotwired/stimulus"

// Expands the search field over the nav and reveals the filter panel.
// No autocomplete (per design feedback).
export default class extends Controller {
  static targets = ["input", "panel"]

  connect() {
    this.onDocClick = this.onDocClick.bind(this)
  }

  expand() {
    this.element.classList.add("expanded")
    if (this.hasPanelTarget) this.panelTarget.hidden = false
    document.addEventListener("click", this.onDocClick)
  }

  collapse() {
    this.element.classList.remove("expanded")
    if (this.hasPanelTarget) this.panelTarget.hidden = true
    document.removeEventListener("click", this.onDocClick)
  }

  onDocClick(event) {
    if (!this.element.contains(event.target)) this.collapse()
  }

  disconnect() {
    document.removeEventListener("click", this.onDocClick)
  }
}
