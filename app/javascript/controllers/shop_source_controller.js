import { Controller } from "@hotwired/stimulus"

// Toggles the "add a place to buy" form between picking an existing shop and
// creating a brand-new one. Inputs in the hidden section are disabled so their
// (stale) values aren't submitted; the server keys off the chosen radio.
export default class extends Controller {
  static targets = ["existing", "new"]

  connect() {
    this.sync()
  }

  switch() {
    this.sync()
  }

  sync() {
    const mode = this.element.querySelector("input[name='shop_source']:checked")?.value
    const showNew = mode === "new"
    this.toggle(this.newTarget, showNew)
    this.toggle(this.existingTarget, !showNew)
  }

  toggle(section, visible) {
    section.hidden = !visible
    section.querySelectorAll("input").forEach((input) => { input.disabled = !visible })
  }
}
