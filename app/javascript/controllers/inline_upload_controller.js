import { Controller } from "@hotwired/stimulus"

// Hover-to-change profile picture: clicking the overlay opens the file picker,
// and choosing a file submits the surrounding form immediately.
export default class extends Controller {
  static targets = ["input"]

  browse() {
    this.inputTarget.click()
  }

  submit() {
    if (this.inputTarget.files.length) this.element.requestSubmit()
  }
}
