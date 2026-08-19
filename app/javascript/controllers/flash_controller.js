import { Controller } from "@hotwired/stimulus"

// Flash toasts sit in the fixed #flash container (shared/_shell), overlaying the
// page rather than taking up layout space — so they have to clear themselves,
// otherwise they'd cover content indefinitely. Click dismisses early.
export default class extends Controller {
  static values = { timeout: { type: Number, default: 5000 } }

  connect() {
    this.timer = setTimeout(() => this.dismiss(), this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  dismiss() {
    this.element.remove()
  }
}
