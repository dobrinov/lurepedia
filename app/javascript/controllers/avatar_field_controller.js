import { Controller } from "@hotwired/stimulus"

// Styled single-image picker for the profile avatar. Triggers the hidden
// file input, live-previews the chosen image in the avatar circle, and shows
// the file name. Picking a file also clears any pending "remove" checkbox.
export default class extends Controller {
  static targets = ["input", "preview", "filename", "remove", "clear"]
  static values = { placeholder: String }

  browse() {
    this.inputTarget.click()
  }

  change() {
    const file = this.inputTarget.files && this.inputTarget.files[0]
    if (!file) return this.reset()

    if (this.hasRemoveTarget) this.removeTarget.checked = false
    this.filenameTarget.textContent = file.name
    if (this.hasClearTarget) this.clearTarget.hidden = false

    const url = URL.createObjectURL(file)
    this.previewTarget.innerHTML = `<img src="${url}" alt="">`
  }

  clear(event) {
    event.preventDefault()
    this.inputTarget.value = ""
    this.reset()
  }

  reset() {
    this.filenameTarget.textContent = this.placeholderValue
    if (this.hasClearTarget) this.clearTarget.hidden = true
  }
}
