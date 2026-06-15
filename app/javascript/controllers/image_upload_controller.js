import { Controller } from "@hotwired/stimulus"

// Multi-image upload with previews, remove, and set-cover. The first file is
// the cover. Uses a DataTransfer to keep the file input in sync after removals.
export default class extends Controller {
  static targets = ["input", "previews", "drop"]

  connect() {
    this.files = []
  }

  browse() {
    this.inputTarget.click()
  }

  add(event) {
    const incoming = Array.from(event.target.files || [])
    incoming.forEach((f) => this.files.push(f))
    this.sync()
    this.render()
  }

  remove(event) {
    const i = parseInt(event.currentTarget.dataset.index, 10)
    this.files.splice(i, 1)
    this.sync()
    this.render()
  }

  setCover(event) {
    const i = parseInt(event.currentTarget.dataset.index, 10)
    const [picked] = this.files.splice(i, 1)
    this.files.unshift(picked)
    this.sync()
    this.render()
  }

  sync() {
    const dt = new DataTransfer()
    this.files.forEach((f) => dt.items.add(f))
    this.inputTarget.files = dt.files
  }

  render() {
    this.previewsTarget.innerHTML = ""
    this.files.forEach((file, i) => {
      const wrap = document.createElement("div")
      wrap.className = "upload-thumb"
      const img = document.createElement("img")
      img.src = URL.createObjectURL(file)
      wrap.appendChild(img)
      if (i === 0) {
        const cover = document.createElement("span")
        cover.className = "cover-badge"
        cover.textContent = "Cover"
        wrap.appendChild(cover)
      } else {
        const setBtn = document.createElement("button")
        setBtn.type = "button"
        setBtn.className = "remove"
        setBtn.style.right = "auto"
        setBtn.style.left = "3px"
        setBtn.textContent = "★"
        setBtn.dataset.index = i
        setBtn.title = "Set as cover"
        setBtn.addEventListener("click", (e) => this.setCover(e))
        wrap.appendChild(setBtn)
      }
      const rm = document.createElement("button")
      rm.type = "button"
      rm.className = "remove"
      rm.textContent = "×"
      rm.dataset.index = i
      rm.addEventListener("click", (e) => this.remove(e))
      wrap.appendChild(rm)
      this.previewsTarget.appendChild(wrap)
    })
  }
}
