import { Controller } from "@hotwired/stimulus"

// Drives a <dialog> rendered inside the #modal Turbo Frame (docs/PLAN.md §8).
export default class extends Controller {
  connect() {
    this.element.showModal()
  }

  close() {
    this.element.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.element) this.close()
  }

  // Bound to the dialog's native "close" event (Escape key, .close(), <form method="dialog">)
  clearFrame() {
    const frame = document.getElementById("modal")
    if (frame) frame.innerHTML = ""
  }
}
