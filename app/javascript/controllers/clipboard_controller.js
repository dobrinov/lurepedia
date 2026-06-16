import { Controller } from "@hotwired/stimulus"

// Copies the value of the source target to the clipboard.
export default class extends Controller {
  static targets = ["source", "button"]

  copy() {
    navigator.clipboard?.writeText(this.sourceTarget.value).then(() => {
      const btn = this.hasButtonTarget ? this.buttonTarget : null
      if (!btn) return
      // Capture the label once so rapid clicks don't latch on "Copied!".
      this.originalLabel ??= btn.textContent
      clearTimeout(this.resetTimer)
      btn.textContent = btn.dataset.copiedLabel || "Copied!"
      this.resetTimer = setTimeout(() => { btn.textContent = this.originalLabel }, 1500)
    })
  }
}
