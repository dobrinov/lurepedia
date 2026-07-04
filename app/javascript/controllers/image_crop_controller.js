import { Controller } from "@hotwired/stimulus"

// Inline crop editor for an already-uploaded photo. The stage shows the
// original image; a draggable/resizable box selects the crop, which is written
// into hidden photo_crop_* fields in ORIGINAL-image pixel coordinates (display
// coords scaled by naturalWidth/clientWidth), so the stored geometry is
// independent of how large the editor happens to render. Picking a new file in
// the same form clears the crop — it described the previous image.
export default class extends Controller {
  static targets = ["editor", "stage", "image", "box", "fieldX", "fieldY", "fieldW", "fieldH", "aspect"]

  MIN_SIZE = 24 // px, display coordinates

  connect() {
    this.aspect = null
    this.crop = null // {x, y, w, h} in display coordinates
    // A newly selected photo invalidates the stored crop of the old one.
    this.fileInput = this.element.closest("form")?.querySelector('input[type="file"]')
    this.onFileChange = () => this.disable()
    this.fileInput?.addEventListener("change", this.onFileChange)
  }

  disconnect() {
    this.fileInput?.removeEventListener("change", this.onFileChange)
  }

  toggle() {
    if (this.editorTarget.hidden) {
      this.editorTarget.hidden = false
      this.whenBoxReady(() => {})
    } else {
      this.editorTarget.hidden = true
    }
  }

  close() {
    this.editorTarget.hidden = true
  }

  // Clear the crop: full frame again, back to free aspect.
  reset() {
    this.aspect = null
    this.markAspect(null)
    this.whenBoxReady(() => {
      this.crop = { x: 0, y: 0, w: this.imageTarget.clientWidth, h: this.imageTarget.clientHeight }
      this.writeFields()
      this.layout()
    })
  }

  setAspect(event) {
    const raw = event.currentTarget.dataset.aspect
    this.aspect = raw ? parseFloat(raw) : null
    this.markAspect(event.currentTarget)
    this.whenBoxReady(() => {
      if (this.aspect) this.fitToAspect()
      this.writeFields()
      this.layout()
    })
  }

  startMove(event) {
    event.preventDefault()
    this.beginGesture(event, "move")
  }

  startResize(event) {
    event.preventDefault()
    event.stopPropagation()
    this.beginGesture(event, event.currentTarget.dataset.handle)
  }

  // --- internals ---

  // Run fn once the stage image has loaded and the box has been initialised —
  // every interaction needs both, and clicks can arrive before the (original,
  // possibly large) image finishes loading.
  whenBoxReady(fn) {
    const run = () => {
      if (!this.crop) this.initBox()
      fn()
    }
    if (this.imageTarget.complete && this.imageTarget.naturalWidth) run()
    else this.imageTarget.addEventListener("load", run, { once: true })
  }

  scale() {
    return this.imageTarget.naturalWidth / this.imageTarget.clientWidth
  }

  // Box from the stored fields (converted to display px), or the full image.
  initBox() {
    const s = this.scale()
    const px = [this.fieldXTarget, this.fieldYTarget, this.fieldWTarget, this.fieldHTarget].map((f) => parseInt(f.value, 10))
    if (px.every((v) => Number.isFinite(v))) {
      this.crop = { x: px[0] / s, y: px[1] / s, w: px[2] / s, h: px[3] / s }
      this.clamp()
    } else {
      this.crop = { x: 0, y: 0, w: this.imageTarget.clientWidth, h: this.imageTarget.clientHeight }
    }
    this.layout()
  }

  // Largest box of the chosen ratio that fits the image, centered on the old box.
  fitToAspect() {
    const W = this.imageTarget.clientWidth
    const H = this.imageTarget.clientHeight
    const w = Math.min(W, H * this.aspect)
    const h = w / this.aspect
    const cx = this.crop.x + this.crop.w / 2
    const cy = this.crop.y + this.crop.h / 2
    this.crop = { x: cx - w / 2, y: cy - h / 2, w, h }
    this.clamp()
  }

  beginGesture(event, mode) {
    const start = { x: event.clientX, y: event.clientY, crop: { ...this.crop } }
    const move = (e) => {
      const dx = e.clientX - start.x
      const dy = e.clientY - start.y
      if (mode === "move") this.moveTo(start.crop, dx, dy)
      else this.resizeTo(start.crop, mode, dx, dy)
      this.layout()
    }
    const up = () => {
      window.removeEventListener("pointermove", move)
      window.removeEventListener("pointerup", up)
      this.writeFields()
    }
    window.addEventListener("pointermove", move)
    window.addEventListener("pointerup", up)
  }

  moveTo(from, dx, dy) {
    const W = this.imageTarget.clientWidth
    const H = this.imageTarget.clientHeight
    this.crop.x = Math.min(Math.max(from.x + dx, 0), W - from.w)
    this.crop.y = Math.min(Math.max(from.y + dy, 0), H - from.h)
  }

  // Resize by dragging one corner; the opposite corner stays anchored and the
  // box stays on its own side of the anchor (no flipping past it).
  resizeTo(from, handle, dx, dy) {
    const W = this.imageTarget.clientWidth
    const H = this.imageTarget.clientHeight
    const left = handle.includes("w")
    const up = handle.includes("n")
    const anchorX = left ? from.x + from.w : from.x
    const anchorY = up ? from.y + from.h : from.y
    const maxW = left ? anchorX : W - anchorX
    const maxH = up ? anchorY : H - anchorY

    let w = Math.min(Math.max(left ? from.w - dx : from.w + dx, this.MIN_SIZE), maxW)
    let h = Math.min(Math.max(up ? from.h - dy : from.h + dy, this.MIN_SIZE), maxH)
    if (this.aspect) {
      if (w / this.aspect >= h) h = w / this.aspect
      else w = h * this.aspect
      if (w > maxW) { w = maxW; h = w / this.aspect }
      if (h > maxH) { h = maxH; w = h * this.aspect }
    }

    this.crop = { x: left ? anchorX - w : anchorX, y: up ? anchorY - h : anchorY, w, h }
  }

  clamp() {
    const W = this.imageTarget.clientWidth
    const H = this.imageTarget.clientHeight
    this.crop.w = Math.min(this.crop.w, W)
    this.crop.h = Math.min(this.crop.h, H)
    this.crop.x = Math.min(Math.max(this.crop.x, 0), W - this.crop.w)
    this.crop.y = Math.min(Math.max(this.crop.y, 0), H - this.crop.h)
  }

  layout() {
    const b = this.boxTarget.style
    b.left = `${this.crop.x}px`
    b.top = `${this.crop.y}px`
    b.width = `${this.crop.w}px`
    b.height = `${this.crop.h}px`
  }

  // Persist the crop in original-image pixels. A full-frame box means "no
  // crop": blank fields take the columns back to NULL.
  writeFields() {
    const s = this.scale()
    const W = this.imageTarget.naturalWidth
    const H = this.imageTarget.naturalHeight
    const x = Math.round(this.crop.x * s)
    const y = Math.round(this.crop.y * s)
    const w = Math.min(Math.round(this.crop.w * s), W - x)
    const h = Math.min(Math.round(this.crop.h * s), H - y)

    const fullFrame = x === 0 && y === 0 && w >= W - 1 && h >= H - 1
    const values = fullFrame ? ["", "", "", ""] : [x, y, w, h]
    ;[this.fieldXTarget, this.fieldYTarget, this.fieldWTarget, this.fieldHTarget].forEach((f, i) => (f.value = values[i]))
  }

  markAspect(active) {
    this.aspectTargets.forEach((b) => b.classList.toggle("is-active", b === active))
  }

  // Hide the whole tool and drop the crop — the photo it described is being
  // replaced by a new upload.
  disable() {
    ;[this.fieldXTarget, this.fieldYTarget, this.fieldWTarget, this.fieldHTarget].forEach((f) => (f.value = ""))
    this.element.hidden = true
  }
}
