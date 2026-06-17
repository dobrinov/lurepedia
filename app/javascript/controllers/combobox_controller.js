import { Controller } from "@hotwired/stimulus"

// Searchable select. Writes the chosen value to a hidden input and updates the
// trigger label. Options come from data-combobox-options-value (JSON array of
// {value,label}).
export default class extends Controller {
  static targets = ["trigger", "panel", "search", "options", "hidden", "label"]
  static values = { options: Array, placeholder: String }

  connect() {
    this.onDocClick = this.onDocClick.bind(this)
    this.activeIndex = -1
    this.render("")
  }

  toggle(event) {
    event.preventDefault()
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")
    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
      this.render("")
      setTimeout(() => this.searchTarget.focus(), 0)
    }
    document.addEventListener("click", this.onDocClick)
  }

  close() {
    this.panelTarget.hidden = true
    this.triggerTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.onDocClick)
  }

  // Arrow keys move the highlight, Enter picks it, Escape closes the panel.
  keydown(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.setActive(this.activeIndex + 1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.setActive(this.activeIndex - 1)
        break
      case "Enter": {
        const option = this.optionElements()[this.activeIndex]
        if (option) {
          event.preventDefault()
          option.click()
        }
        break
      }
      case "Escape":
        event.preventDefault()
        this.close()
        this.triggerTarget.focus()
        break
    }
  }

  optionElements() {
    return Array.from(this.optionsTarget.querySelectorAll(".combobox-option"))
  }

  setActive(index) {
    const options = this.optionElements()
    if (options.length === 0) {
      this.activeIndex = -1
      return
    }
    this.activeIndex = Math.max(0, Math.min(index, options.length - 1))
    options.forEach((el, i) => el.classList.toggle("highlighted", i === this.activeIndex))
    options[this.activeIndex].scrollIntoView({ block: "nearest" })
  }

  filter() {
    this.render(this.searchTarget.value.trim().toLowerCase())
  }

  render(q) {
    const current = this.hiddenTarget.value
    const matches = this.optionsValue.filter(
      (o) => !q || String(o.label).toLowerCase().includes(q)
    )
    this.optionsTarget.innerHTML = ""
    if (matches.length === 0) {
      const empty = document.createElement("div")
      empty.className = "combobox-empty"
      empty.textContent = "No matches"
      this.optionsTarget.appendChild(empty)
      return
    }
    matches.forEach((o) => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "combobox-option" + (String(o.value) === current ? " active" : "")
      btn.innerHTML = `<span>${this.escape(o.label)}</span>`
      if (String(o.value) === current) {
        btn.innerHTML += `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6"><path d="M20 6 9 17l-5-5"></path></svg>`
      }
      btn.addEventListener("click", () => this.pick(o))
      this.optionsTarget.appendChild(btn)
    })
    this.setActive(0)
  }

  pick(o) {
    this.hiddenTarget.value = o.value
    this.labelTarget.textContent = o.label
    this.triggerTarget.classList.remove("placeholder")
    this.close()
    this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  onDocClick(event) {
    if (!this.element.contains(event.target)) this.close()
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
