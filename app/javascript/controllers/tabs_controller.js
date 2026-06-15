import { Controller } from "@hotwired/stimulus"

// Simple tab switcher. Tabs have data-tab-name; panels have data-tab-panel.
export default class extends Controller {
  static targets = ["tab", "panel"]

  select(event) {
    const name = event.currentTarget.dataset.tabName
    this.tabTargets.forEach((t) => t.classList.toggle("active", t.dataset.tabName === name))
    this.panelTargets.forEach((p) => p.classList.toggle("active", p.dataset.tabPanel === name))
  }
}
