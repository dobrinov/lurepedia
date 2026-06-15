import { Controller } from "@hotwired/stimulus"

// Catch photo carousel: thumbnails switch the main image.
export default class extends Controller {
  static targets = ["main", "thumb"]

  select(event) {
    const src = event.currentTarget.dataset.src
    this.mainTarget.src = src
    this.thumbTargets.forEach((t) => t.classList.toggle("active", t === event.currentTarget))
  }
}
