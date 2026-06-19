import { Controller } from "@hotwired/stimulus"

// Disables the per-country "ships to" field while the "ships worldwide"
// checkbox is ticked — a worldwide shop has no need for a country list.
export default class extends Controller {
  static targets = [ "toggle", "countries" ]

  connect() {
    this.sync()
  }

  sync() {
    const worldwide = this.toggleTarget.checked
    this.countriesTarget.disabled = worldwide
    this.countriesTarget.closest(".field").style.opacity = worldwide ? "0.5" : ""
  }
}
