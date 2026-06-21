import { Controller } from "@hotwired/stimulus"

// Swaps the contribution note on the add-lure form as the brand is chosen:
// admins and the brand's verified owner publish without review, everyone
// else's submission is moderated. Listens for the bubbled `change` the brand
// combobox fires on its hidden input.
export default class extends Controller {
  static targets = ["note"]
  static values = { ownedIds: Array, admin: Boolean, reviewed: String, direct: String }

  update(event) {
    if (event.target.name !== "lure[brand_id]") return
    const direct = this.adminValue || this.ownedIdsValue.includes(Number(event.target.value))
    this.noteTarget.textContent = direct ? this.directValue : this.reviewedValue
  }
}
