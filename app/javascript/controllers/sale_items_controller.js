import { Controller } from "@hotwired/stimulus"

// Adds another line to the sale form. The blank row lives in a <template> so
// Rails renders its field names once, server-side, and JS only has to swap the
// child index — no field names built in JavaScript.
export default class extends Controller {
  static targets = ["rows", "template"]

  add() {
    const markup = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, crypto.randomUUID())
    this.rowsTarget.insertAdjacentHTML("beforeend", markup)
  }
}
