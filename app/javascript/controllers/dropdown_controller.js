import { Controller } from "@hotwired/stimulus"

// Toggleable menu (avatar menu, language switcher). Only one dropdown is open at
// a time; closes on outside click.
export default class extends Controller {
  static targets = ["menu", "trigger"]

  connect() {
    this.onDocClick = this.onDocClick.bind(this)
    this.onOtherOpen = this.onOtherOpen.bind(this)
    document.addEventListener("dropdown:open", this.onOtherOpen)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.menuTarget.hidden ? this.open() : this.close()
  }

  open() {
    // Tell any other open dropdown to close.
    document.dispatchEvent(new CustomEvent("dropdown:open", { detail: this }))
    this.menuTarget.hidden = false
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.onDocClick)
  }

  close() {
    this.menuTarget.hidden = true
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.onDocClick)
  }

  onOtherOpen(event) {
    if (event.detail !== this) this.close()
  }

  onDocClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  disconnect() {
    document.removeEventListener("click", this.onDocClick)
    document.removeEventListener("dropdown:open", this.onOtherOpen)
  }
}
