import { Controller } from "@hotwired/stimulus"

// Tile background override. The color input is only a picker; the value that
// persists lives in the hidden photo_bg_color field — blank means "auto"
// (use the color measured from the photo, shown as the picker's default).
export default class extends Controller {
  static targets = ["field", "picker", "status"]
  static values = { detected: String }

  connect() {
    this.render()
  }

  pick() {
    this.fieldTarget.value = this.pickerTarget.value
    this.render()
  }

  auto() {
    this.fieldTarget.value = ""
    this.pickerTarget.value = this.detectedValue || "#f4f4f5"
    this.render()
  }

  render() {
    const custom = this.fieldTarget.value !== ""
    if (this.hasStatusTarget) this.statusTarget.hidden = !custom
  }
}
