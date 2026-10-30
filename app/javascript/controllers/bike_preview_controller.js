import { Controller } from "@hotwired/stimulus"

// Shows the photos of whichever bikes are picked in a <select> — one, or
// several when the select is `multiple` (D67). Each preview carries
// data-bike-id; the ones matching a chosen option are shown, the rest stay
// hidden.
export default class extends Controller {
  static targets = [ "select", "preview" ]

  connect() {
    this.show()
  }

  show() {
    const ids = Array.from(this.selectTarget.selectedOptions).map((option) => option.value)
    this.previewTargets.forEach((preview) => {
      preview.hidden = !ids.includes(preview.dataset.bikeId)
    })
  }
}
