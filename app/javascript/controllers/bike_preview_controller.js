import { Controller } from "@hotwired/stimulus"

// Shows the photos of whichever bike is picked in a <select>. Each preview
// carries data-bike-id; the one matching the select's value is shown, the
// rest stay hidden. The <select> itself stays native (see D52 on why).
export default class extends Controller {
  static targets = [ "select", "preview" ]

  connect() {
    this.show()
  }

  show() {
    const id = this.selectTarget.value
    this.previewTargets.forEach((preview) => {
      preview.hidden = preview.dataset.bikeId !== id
    })
  }
}
