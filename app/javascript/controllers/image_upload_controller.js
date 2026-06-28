import { Controller } from "@hotwired/stimulus"

// Image upload with previews, drag-and-drop, remove, and (when the input takes
// many files) set-cover. The first file is the cover. Uses a DataTransfer to
// keep the file input in sync. A non-multiple input acts as a single-photo
// picker: a new selection replaces the previous one.
export default class extends Controller {
  static targets = ["input", "previews", "drop"]

  connect() {
    this.files = []
    this.multiple = this.inputTarget.multiple
  }

  browse() {
    this.inputTarget.click()
  }

  add(event) {
    this.addFiles(event.target.files)
  }

  dragover(event) {
    event.preventDefault()
    this.dropTarget.classList.add("is-dragover")
  }

  dragleave(event) {
    event.preventDefault()
    this.dropTarget.classList.remove("is-dragover")
  }

  drop(event) {
    event.preventDefault()
    this.dropTarget.classList.remove("is-dragover")
    this.addFiles(event.dataTransfer.files)
  }

  addFiles(list) {
    const incoming = Array.from(list || []).filter((f) => f.type.startsWith("image/"))
    if (!incoming.length) return

    if (this.multiple) {
      incoming.forEach((f) => this.files.push(f))
    } else {
      this.files = incoming.slice(-1)
    }
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
      // Cover badge / set-cover star only make sense when several files compete.
      if (this.multiple && this.files.length > 1) {
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
