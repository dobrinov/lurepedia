import { Controller } from "@hotwired/stimulus"

// Open/close a modal dialog. The modal markup lives inside the controller
// element and starts hidden.
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    if (event) event.preventDefault()
    this.dialogTarget.hidden = false
    document.body.style.overflow = "hidden"
  }

  close(event) {
    if (event) event.preventDefault()
    this.dialogTarget.hidden = true
    document.body.style.overflow = ""
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close(event)
  }
}
