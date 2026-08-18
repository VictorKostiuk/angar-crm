import { Controller } from "@hotwired/stimulus"

// Debounced auto-submit for search inputs. Attach to the <form>,
// data-action="input->debounce#submit" on the text field.
export default class extends Controller {
  static values = { wait: { type: Number, default: 300 } }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.waitValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
