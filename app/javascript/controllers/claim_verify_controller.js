import { Controller } from "@hotwired/stimulus"

// Copies the TXT record to the clipboard and shows a confirmation.
export default class extends Controller {
  static targets = ["record", "copyButton"]

  copy() {
    const text = this.recordTarget.textContent.trim()
    navigator.clipboard?.writeText(text)
    const original = this.copyButtonTarget.textContent
    this.copyButtonTarget.textContent = this.copyButtonTarget.dataset.copied || "Copied!"
    setTimeout(() => (this.copyButtonTarget.textContent = original), 1500)
  }
}
