import { Controller } from "@hotwired/stimulus"

// Debounced search that drives a Turbo Frame's src, for inputs that can't sit
// in their own <form> — the client search on the intake screen is inside the
// order form, and the HTML parser drops a nested <form> (and every attribute on
// it) outright.
//
// It owns *both* query params. The category pills are links-shaped buttons that
// know nothing about what's typed in the box, and the box knows nothing about
// the selected pill — so one place has to hold both or each clobbers the other.
export default class extends Controller {
  static targets = ["input", "pill"]
  static values = {
    url: String,
    frame: String,
    category: String,
    wait: { type: Number, default: 300 },
    // Intake: an empty query means "show nothing". Catalog modals: it means
    // "show everything", which is what the frame's server-rendered src already
    // did on open.
    clearWhenBlank: Boolean
  }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.load(), this.waitValue)
  }

  filter(event) {
    clearTimeout(this.timeout)
    this.categoryValue = event.currentTarget.dataset.categoryId || ""
    this.syncPills()
    this.load()
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  load() {
    const frame = document.getElementById(this.frameValue)
    if (!frame) return

    const query = this.hasInputTarget ? this.inputTarget.value.trim() : ""

    if (this.clearWhenBlankValue && query === "") {
      frame.innerHTML = ""
      return
    }

    const url = new URL(this.urlValue, window.location.origin)
    if (query !== "") url.searchParams.set("q", query)
    if (this.categoryValue !== "") url.searchParams.set("category_id", this.categoryValue)
    frame.src = url.toString()
  }

  syncPills() {
    this.pillTargets.forEach((pill) => {
      const active = (pill.dataset.categoryId || "") === this.categoryValue
      pill.classList.toggle("bg-brand-600", active)
      pill.classList.toggle("text-white", active)
      pill.classList.toggle("border", !active)
      pill.classList.toggle("border-gray-200", !active)
      pill.classList.toggle("text-gray-700", !active)
      pill.classList.toggle("hover:bg-gray-50", !active)
    })
  }
}
