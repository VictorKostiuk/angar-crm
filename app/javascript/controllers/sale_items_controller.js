import { Controller } from "@hotwired/stimulus"

// Adds another line to the sale form. The blank row lives in a <template> so
// Rails renders its field names once, server-side, and JS only has to swap the
// child index — no field names built in JavaScript.
export default class extends Controller {
  static targets = ["rows", "template"]

  add() {
    // A NUMERIC index, not a UUID: params.expect's array form only accepts
    // hash keys that look like indices, so a UUID-keyed row is dropped whole —
    // silently, since the rest of the sale saves fine.
    const index = Date.now()
    this.rowsTarget.insertAdjacentHTML("beforeend",
      this.templateTarget.innerHTML.replace(/NEW_RECORD/g, index))
  }
}
