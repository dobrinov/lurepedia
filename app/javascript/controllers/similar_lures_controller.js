import { Controller } from "@hotwired/stimulus"

// Proposes existing look-alike lures while a contributor uploads a color
// photo: posts the picked file to the similar-preview endpoint (which scores
// it against the catalog's color signatures) and renders the matches as
// tickable checkboxes submitted with the form as similar_lure_slugs[].
// Nothing is linked unless the contributor ticks a proposal.
export default class extends Controller {
  static targets = ["section", "list"]
  static values = { url: String }

  // change-> on the file input (browse) — the same event image-upload#add reads.
  check(event) {
    const file = event.target.files && event.target.files[0]
    this.propose(file)
  }

  // drop-> on the drop zone; the input's change event doesn't fire for drops.
  drop(event) {
    const file = Array.from(event.dataTransfer?.files || []).find((f) => f.type.startsWith("image/"))
    this.propose(file)
  }

  async propose(file) {
    if (!file) return

    const body = new FormData()
    body.append("photo", file)
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    let matches = []
    try {
      const response = await fetch(this.urlValue, { method: "POST", body, headers: { "X-CSRF-Token": token } })
      if (response.ok) matches = await response.json()
    } catch {
      matches = []
    }
    this.render(matches)
  }

  render(matches) {
    this.listTarget.innerHTML = ""
    this.sectionTarget.hidden = matches.length === 0

    matches.forEach((match) => {
      const label = document.createElement("label")
      label.className = "row"
      label.style.cssText = "gap:10px;align-items:center;cursor:pointer"

      const box = document.createElement("input")
      box.type = "checkbox"
      box.name = "similar_lure_slugs[]"
      box.value = match.slug
      label.appendChild(box)

      if (match.photo_url) {
        const img = document.createElement("img")
        img.src = match.photo_url
        img.alt = match.title
        img.style.cssText = "width:44px;height:44px;object-fit:cover;border-radius:6px"
        label.appendChild(img)
      }

      const text = document.createElement("span")
      const title = document.createElement("strong")
      title.textContent = match.title
      text.appendChild(title)
      text.appendChild(document.createTextNode(" "))
      const score = document.createElement("span")
      score.className = "muted"
      score.style.fontSize = "12.5px"
      score.textContent = match.match_label
      text.appendChild(score)
      label.appendChild(text)

      this.listTarget.appendChild(label)
    })
  }
}
