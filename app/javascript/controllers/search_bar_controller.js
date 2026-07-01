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
  }

  collapse() {
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
