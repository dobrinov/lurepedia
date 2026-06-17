import { Controller } from "@hotwired/stimulus"

// Copies the value of the source target to the clipboard, then flashes a
// confirmation. A button carrying data-tooltip shows it via its tooltip;
// otherwise the button's text label is swapped.
export default class extends Controller {
  static targets = ["source", "button"]

  copy() {
    navigator.clipboard?.writeText(this.sourceTarget.value).then(() => {
      const btn = this.hasButtonTarget ? this.buttonTarget : null
      if (!btn) return

      clearTimeout(this.resetTimer)
      const copied = btn.dataset.copiedLabel || "Copied!"

      if (btn.dataset.tooltip !== undefined) {
        this.originalTooltip ??= btn.dataset.tooltip
        btn.dataset.tooltip = copied
        btn.classList.add("is-copied")
        this.resetTimer = setTimeout(() => {
          btn.classList.remove("is-copied")
          btn.dataset.tooltip = this.originalTooltip
        }, 1500)
      } else {
        // Capture the label once so rapid clicks don't latch on "Copied!".
        this.originalLabel ??= btn.textContent
        btn.textContent = copied
        this.resetTimer = setTimeout(() => { btn.textContent = this.originalLabel }, 1500)
      }
    })
  }
}
