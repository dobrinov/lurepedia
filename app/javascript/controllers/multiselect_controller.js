import { Controller } from "@hotwired/stimulus"

// Generic multi-select. Reuses the combobox styling; chosen options show as
// removable chips and their values are written to a hidden field as a
// comma-separated string (e.g. "US,CA,GB" or "spinning,trolling"), so the
// server receives a plain string. Options may carry an optional `flag` image
// (used by the country picker). The panel stays open while picking several.
export default class extends Controller {
  static targets = [ "hidden", "panel", "search", "options", "chips", "trigger", "placeholder" ]
  static values = { options: Array, selected: Array }

  connect() {
    this.onDocClick = this.onDocClick.bind(this)
    this.selected = new Set((this.selectedValue || []).map(String))
    this.activeIndex = -1
    this.renderChips()
    this.updateHidden()
  }

  toggle(event) {
    event.preventDefault()
    this.panelTarget.hidden ? this.open() : this.close()
  }

  triggerKeydown(event) {
    if (event.key === "Enter" || event.key === " ") this.toggle(event)
  }

  open() {
    this.panelTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")
    this.searchTarget.value = ""
    this.render("")
    setTimeout(() => this.searchTarget.focus(), 0)
    document.addEventListener("click", this.onDocClick)
  }

  close() {
    this.panelTarget.hidden = true
    this.triggerTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.onDocClick)
  }

  filter() {
    this.render(this.searchTarget.value.trim().toLowerCase())
  }

  keydown(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault(); this.setActive(this.activeIndex + 1); break
      case "ArrowUp":
        event.preventDefault(); this.setActive(this.activeIndex - 1); break
      case "Enter": {
        const option = this.optionElements()[this.activeIndex]
        if (option) { event.preventDefault(); option.click() }
        break
      }
      case "Escape":
        event.preventDefault(); this.close(); this.triggerTarget.focus(); break
    }
  }

  render(q) {
    const matches = this.optionsValue.filter((o) => !q || String(o.label).toLowerCase().includes(q))
    // Selected countries float to the top of the list (stable sort keeps each
    // group in its original alphabetical order).
    matches.sort((a, b) => (this.selected.has(String(a.value)) ? 0 : 1) - (this.selected.has(String(b.value)) ? 0 : 1))
    this.optionsTarget.innerHTML = ""
    if (matches.length === 0) {
      const empty = document.createElement("div")
      empty.className = "combobox-empty"
      empty.textContent = "No matches"
      this.optionsTarget.appendChild(empty)
      return
    }
    matches.forEach((o) => {
      const on = this.selected.has(String(o.value))
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "combobox-option" + (on ? " active" : "")
      btn.innerHTML = `${this.flag(o)}<span style="flex:1">${this.escape(o.label)}</span>` +
        (on ? `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6"><path d="M20 6 9 17l-5-5"></path></svg>` : "")
      btn.addEventListener("click", () => this.pick(o))
      this.optionsTarget.appendChild(btn)
    })
    this.setActive(0)
  }

  pick(o) {
    const v = String(o.value)
    this.selected.has(v) ? this.selected.delete(v) : this.selected.add(v)
    this.updateHidden()
    this.renderChips()
    this.render(this.searchTarget.value.trim().toLowerCase())
    this.searchTarget.focus()
  }

  remove(event) {
    event.stopPropagation() // don't let the click bubble to the trigger and toggle the panel
    this.selected.delete(String(event.currentTarget.dataset.value))
    this.updateHidden()
    this.renderChips()
  }

  renderChips() {
    this.chipsTarget.innerHTML = ""
    this.optionsValue
      .filter((o) => this.selected.has(String(o.value)))
      .forEach((o) => {
        const chip = document.createElement("span")
        chip.className = "ms-chip"
        chip.innerHTML = `${this.flag(o)}<span>${this.escape(o.label)}</span>`
        const x = document.createElement("button")
        x.type = "button"
        x.className = "ms-chip-x"
        x.textContent = "×"
        x.dataset.value = o.value
        x.addEventListener("click", (e) => this.remove(e))
        chip.appendChild(x)
        this.chipsTarget.appendChild(chip)
      })

    // Hide the placeholder once anything is selected.
    const empty = this.selected.size === 0
    if (this.hasPlaceholderTarget) this.placeholderTarget.hidden = !empty
    this.triggerTarget.classList.toggle("placeholder", empty)
  }

  updateHidden() {
    this.hiddenTarget.value = this.optionsValue
      .filter((o) => this.selected.has(String(o.value)))
      .map((o) => o.value)
      .join(",")
  }

  flag(o) {
    return o.flag ? `<img src="${o.flag}" width="16" height="16" alt="" style="border-radius:999px;flex-shrink:0;object-fit:cover">` : ""
  }

  optionElements() {
    return Array.from(this.optionsTarget.querySelectorAll(".combobox-option"))
  }

  setActive(index) {
    const options = this.optionElements()
    if (options.length === 0) { this.activeIndex = -1; return }
    this.activeIndex = Math.max(0, Math.min(index, options.length - 1))
    options.forEach((el, i) => el.classList.toggle("highlighted", i === this.activeIndex))
    options[this.activeIndex].scrollIntoView({ block: "nearest" })
  }

  onDocClick(event) {
    // Picking an option re-renders the list, detaching the clicked node before
    // this handler runs; a detached target means the click was inside, so the
    // panel should stay open.
    if (event.target.isConnected && !this.element.contains(event.target)) this.close()
  }

  escape(s) {
    const d = document.createElement("div")
    d.textContent = s
    return d.innerHTML
  }

  disconnect() {
    document.removeEventListener("click", this.onDocClick)
  }
}
