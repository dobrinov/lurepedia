import { Controller } from "@hotwired/stimulus"

// Crop + tile-background tools for a photo. The stage shows the original
// image (or a freshly picked local file, before upload); a draggable/
// resizable box selects the crop, written into hidden photo_crop_* fields in
// ORIGINAL-image pixel coordinates (display coords scaled by naturalWidth /
// clientWidth), so the stored geometry is independent of the editor's
// rendered size. The background override lives in the hidden photo_bg_color
// field — blank means "auto" (the analyzer's measured color, shown as the
// picker default) — and can be sampled straight off the image (eyedropper).
export default class extends Controller {
  static targets = ["editor", "stage", "image", "box",
    "fieldX", "fieldY", "fieldW", "fieldH", "aspect",
    "bgField", "bgPicker", "bgAuto"]
  static values = { detected: String }

  MIN_SIZE = 24 // px, display coordinates
  FALLBACK_COLOR = "#f4f4f5" // --surface-2, the default tile background

  connect() {
    this.aspect = null
    this.crop = null // {x, y, w, h} in display coordinates
    this.sampling = false
    this.objectUrl = null
    this.fileInput = this.element.closest("form")?.querySelector('input[type="file"]')
    this.onFileChange = (event) => this.newFile(event.target.files[0])
    this.fileInput?.addEventListener("change", this.onFileChange)
  }

  disconnect() {
    this.fileInput?.removeEventListener("change", this.onFileChange)
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
  }

  // A newly picked file replaces whatever the editor showed: stale crop and
  // background override are cleared, the stage points at the local file, and
  // the editor opens so the image can be processed before upload.
  newFile(file) {
    if (!file || !file.type.startsWith("image/")) return

    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = URL.createObjectURL(file)
    this.crop = null
    this.aspect = null
    this.markAspect(null)
    this.cropFields.forEach((f) => (f.value = ""))
    this.bgFieldTarget.value = ""
    this.bgPickerTarget.value = this.FALLBACK_COLOR
    this.bgAutoTarget.hidden = true
    this.stopSampling()
    this.imageTarget.src = this.objectUrl
    this.element.hidden = false
    this.editorTarget.hidden = false
    this.whenBoxReady(() => {})
  }

  toggle() {
    if (this.editorTarget.hidden) {
      this.editorTarget.hidden = false
      this.whenBoxReady(() => {})
    } else {
      this.editorTarget.hidden = true
      this.stopSampling()
    }
  }

  close() {
    this.editorTarget.hidden = true
    this.stopSampling()
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

  // --- tile background ---

  pickColor() {
    this.bgFieldTarget.value = this.bgPickerTarget.value
    this.bgAutoTarget.hidden = false
  }

  autoColor() {
    this.bgFieldTarget.value = ""
    this.bgPickerTarget.value = this.detectedValue || this.FALLBACK_COLOR
    this.bgAutoTarget.hidden = true
  }

  // Eyedropper: opens the editor and arms a one-shot click-to-sample on the
  // stage image. Clicking the button again cancels.
  startSample() {
    if (this.sampling) {
      this.stopSampling()
      return
    }
    if (this.element.hidden || !this.imageTarget.getAttribute("src")) return

    this.editorTarget.hidden = false
    this.whenBoxReady(() => {
      this.sampling = true
      this.stageTarget.classList.add("is-sampling")
    })
  }

  stageClick(event) {
    if (!this.sampling) return

    const img = this.imageTarget
    const rect = img.getBoundingClientRect()
    const x = Math.floor((event.clientX - rect.left) * (img.naturalWidth / rect.width))
    const y = Math.floor((event.clientY - rect.top) * (img.naturalHeight / rect.height))
    const color = this.colorAt(x, y)
    if (color) {
      this.bgFieldTarget.value = color
      this.bgPickerTarget.value = color
      this.bgAutoTarget.hidden = false
    }
    this.stopSampling()
  }

  stopSampling() {
    this.sampling = false
    if (this.hasStageTarget) this.stageTarget.classList.remove("is-sampling")
  }

  colorAt(x, y) {
    const img = this.imageTarget
    const canvas = document.createElement("canvas")
    canvas.width = img.naturalWidth
    canvas.height = img.naturalHeight
    const ctx = canvas.getContext("2d")
    ctx.drawImage(img, 0, 0)
    try {
      const [r, g, b] = ctx.getImageData(x, y, 1, 1).data
      return `#${[r, g, b].map((v) => v.toString(16).padStart(2, "0")).join("")}`
    } catch {
      return null // tainted canvas (cross-origin image) — sampling unavailable
    }
  }

  // --- crop internals ---

  get cropFields() {
    return [this.fieldXTarget, this.fieldYTarget, this.fieldWTarget, this.fieldHTarget]
  }

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
    const px = this.cropFields.map((f) => parseInt(f.value, 10))
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
    if (this.sampling) return

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
    this.cropFields.forEach((f, i) => (f.value = values[i]))
  }

  markAspect(active) {
    this.aspectTargets.forEach((b) => b.classList.toggle("is-active", b === active))
  }
}
