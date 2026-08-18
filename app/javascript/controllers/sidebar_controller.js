import { Controller } from "@hotwired/stimulus"

// Off-canvas nav drawer below the `lg` breakpoint (docs/PLAN.md P9.6). No
// state persists across navigation on purpose: the panel/backdrop always
// render closed in the server HTML, so a full Turbo Drive page swap closes
// the drawer for free — do not mark the sidebar data-turbo-permanent, or
// server-rendered active-nav-item highlighting would freeze on whatever
// page was open when it was first rendered.
export default class extends Controller {
  static targets = ["panel", "backdrop"]

  open() {
    this.panelTarget.classList.remove("-translate-x-full")
    this.backdropTarget.classList.remove("hidden")
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("hidden")
  }
}
