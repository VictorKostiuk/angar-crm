import { Controller } from "@hotwired/stimulus"

// Instant auto-submit for filter selects/checkboxes. Attach to the <form>,
// data-action="change->autosubmit#submit" on each filter control.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
