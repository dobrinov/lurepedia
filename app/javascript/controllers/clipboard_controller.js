import { Controller } from "@hotwired/stimulus"

// Copies the value of the source target to the clipboard.
export default class extends Controller {
  static targets = ["source", "button"]

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.value).then(() => {
      const btn = this.hasButtonTarget ? this.buttonTarget : null
      if (!btn) return
      const original = btn.textContent
      btn.textContent = btn.dataset.copiedLabel || "Copied!"
      setTimeout(() => { btn.textContent = original }, 1500)
    })
  }
}
