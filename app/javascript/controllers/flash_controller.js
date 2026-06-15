import { Controller } from "@hotwired/stimulus"

// Auto-dismiss flash messages after a delay.
export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.timer = setTimeout(() => this.dismiss(), 4000)
  }

  dismiss() {
    this.itemTargets.forEach((i) => i.remove())
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
