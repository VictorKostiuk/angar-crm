import { Controller } from "@hotwired/stimulus"

// Shows and hides a block behind a button — the orders filter on a phone
// (D70), where seven fields would otherwise fill the first screen. The block
// carries "hidden sm:block" itself, so from sm up it is always visible and
// the button is not shown.
export default class extends Controller {
  static targets = [ "content", "button" ]

  toggle() {
    const hidden = this.contentTarget.classList.toggle("hidden")
    this.buttonTarget.setAttribute("aria-expanded", hidden ? "false" : "true")
  }
}
