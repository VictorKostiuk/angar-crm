import { Controller } from "@hotwired/stimulus"

// Click a photo to see it full size. Uses the same native <dialog> the modals
// use, so Escape and the backdrop close it for free.
export default class extends Controller {
  static targets = ["dialog", "image"]

  open(event) {
    this.imageTarget.src = event.currentTarget.dataset.fullSrc
    this.imageTarget.alt = event.currentTarget.dataset.fullAlt || ""
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
