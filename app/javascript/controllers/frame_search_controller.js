import { Controller } from "@hotwired/stimulus"

// Debounced search that drives a Turbo Frame's src directly, for inputs that
// can't sit in their own <form> — the client search on the intake screen is
// inside the order form, and the HTML parser silently drops a nested <form>
// (and every attribute on it), which is why that search did nothing at all.
export default class extends Controller {
  static values = {
    url: String,
    frame: String,
    wait: { type: Number, default: 300 }
  }

  search(event) {
    const query = event.target.value
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.load(query), this.waitValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  load(query) {
    const frame = document.getElementById(this.frameValue)
    if (!frame) return

    if (query.trim() === "") {
      frame.innerHTML = ""
      return
    }

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)
    frame.src = url.toString()
  }
}
