import { Controller } from "@hotwired/stimulus"

// Toggleable menu (avatar menu, language switcher). Closes on outside click.
export default class extends Controller {
  static targets = ["menu", "trigger"]

  connect() {
    this.onDocClick = this.onDocClick.bind(this)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.menuTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.menuTarget.hidden = false
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.onDocClick)
  }

  close() {
    this.menuTarget.hidden = true
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.onDocClick)
  }

  onDocClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  disconnect() {
    document.removeEventListener("click", this.onDocClick)
  }
}
