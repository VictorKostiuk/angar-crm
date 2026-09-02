import { Controller } from "@hotwired/stimulus"

// Copies the source target's text and flips the button label to confirm it.
//
// navigator.clipboard exists only in a secure context — on a shop-floor tablet
// opening the app over plain http on a LAN address it is simply undefined, and
// the promise form also rejects when the permission is denied. Both paths fall
// back to selecting the textarea and letting the deprecated execCommand copy,
// and the textarea stays readable and hand-selectable even if that fails too.
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { copiedLabel: String }

  connect() {
    this.defaultLabel = this.buttonTarget.textContent
  }

  disconnect() {
    clearTimeout(this.resetTimeout)
  }

  copy() {
    if (navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(this.sourceTarget.value)
        .then(() => this.confirm())
        .catch(() => this.fallbackCopy())
    } else {
      this.fallbackCopy()
    }
  }

  fallbackCopy() {
    this.sourceTarget.focus()
    this.sourceTarget.select()
    if (document.execCommand("copy")) this.confirm()
  }

  confirm() {
    this.buttonTarget.textContent = this.copiedLabelValue
    clearTimeout(this.resetTimeout)
    this.resetTimeout = setTimeout(() => { this.buttonTarget.textContent = this.defaultLabel }, 2000)
  }
}
