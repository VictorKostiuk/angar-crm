import { Controller } from "@hotwired/stimulus"

// The header search's dropdown (D69): typing loads matches into a Turbo Frame
// under the box; Escape or a click anywhere else closes it; Enter submits the
// box's own form to the full results page. The frame sits beside the input,
// never around it — D54: a box inside the frame it reloads loses its focus.
export default class extends Controller {
  static targets = [ "input", "frame" ]
  static values = { url: String, wait: { type: Number, default: 250 } }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.load(), this.waitValue)
  }

  load() {
    const query = this.inputTarget.value.trim()
    // One character only means something as an order number.
    if (query === "" || (query.length < 2 && !/^\d$/.test(query))) return this.close()

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)
    this.frameTarget.src = url.toString()
  }

  close() {
    clearTimeout(this.timeout)
    this.frameTarget.removeAttribute("src")
    this.frameTarget.replaceChildren()
  }

  keydown(event) {
    if (event.key === "Escape") this.close()
  }

  outside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
