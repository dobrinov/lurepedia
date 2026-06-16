import { Controller } from "@hotwired/stimulus"

// Searchable select backed by a server endpoint. Loads the first page of options
// when opened, fetches more as the options list is scrolled to the bottom, and
// re-queries the server (from page 1) when the search term changes. The endpoint
// returns { results: [{value, label}], next_page: <n|null> }.
export default class extends Controller {
  static targets = ["trigger", "panel", "search", "options", "hidden", "label"]
  static values = { url: String, placeholder: String }

  connect() {
    this.onDocClick = this.onDocClick.bind(this)
    this.loaded = false
    this.loading = false
    this.nextPage = null
    this.query = ""
    this.debounce = null
  }

  toggle(event) {
    event.preventDefault()
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.onDocClick)
    setTimeout(() => this.searchTarget.focus(), 0)
    if (!this.loaded) this.reload()
  }

  close() {
    this.panelTarget.hidden = true
    this.triggerTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.onDocClick)
  }

  search() {
    clearTimeout(this.debounce)
    this.debounce = setTimeout(() => {
      this.query = this.searchTarget.value.trim()
      this.reload()
    }, 250)
  }

  // (Re)load from page 1 with the current query.
  reload() {
    this.loaded = true
    this.nextPage = 1
    this.optionsTarget.innerHTML = ""
    this.fetchPage(true)
  }

  fetchPage(reset) {
    if (this.loading || this.nextPage == null) return
    this.loading = true
    const page = this.nextPage
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("page", page)
    if (this.query) url.searchParams.set("q", this.query)
    url.searchParams.set("format", "json")

    fetch(url, { headers: { Accept: "application/json" } })
      .then((r) => r.json())
      .then((data) => {
        this.nextPage = data.next_page
        this.append(data.results || [], reset)
      })
      .catch(() => { this.nextPage = null })
      .finally(() => { this.loading = false })
  }

  append(results, reset) {
    this.removeSentinel()
    if (reset && results.length === 0) {
      const empty = document.createElement("div")
      empty.className = "combobox-empty"
      empty.textContent = "No matches"
      this.optionsTarget.appendChild(empty)
      return
    }
    const current = this.hiddenTarget.value
    results.forEach((o) => {
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
    if (this.nextPage != null) this.addSentinel()
  }

  // A zero-height marker at the bottom of the list; when it scrolls into view we
  // load the next page.
  addSentinel() {
    const sentinel = document.createElement("div")
    sentinel.dataset.sentinel = "true"
    this.optionsTarget.appendChild(sentinel)
    this.observer = new IntersectionObserver(
      (entries) => { if (entries[0].isIntersecting) this.fetchPage(false) },
      { root: this.optionsTarget }
    )
    this.observer.observe(sentinel)
  }

  removeSentinel() {
    if (this.observer) { this.observer.disconnect(); this.observer = null }
    const existing = this.optionsTarget.querySelector("[data-sentinel]")
    if (existing) existing.remove()
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
    this.removeSentinel()
    document.removeEventListener("click", this.onDocClick)
  }
}
