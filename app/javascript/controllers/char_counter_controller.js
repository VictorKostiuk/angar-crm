import { Controller } from "@hotwired/stimulus"

// Live "N/limit" counter for a textarea. data-char-counter-limit-value sets
// the limit, data-char-counter-target="count" marks the display element.
export default class extends Controller {
  static targets = ["count"]
  static values = { limit: Number }

  connect() {
    this.update()
  }

  update() {
    this.countTarget.textContent = `${this.element.value.length}/${this.limitValue}`
  }
}
