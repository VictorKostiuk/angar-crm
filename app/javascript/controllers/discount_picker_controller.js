import { Controller } from "@hotwired/stimulus"

// Picking a catalog discount computes the order's discount amount
// (percentage against the order's pre-discount subtotal, fixed amount
// used as-is), writes it into a hidden field, and submits immediately.
// Picking "Без знижки" clears it back to 0. Pure picker — no free-typed
// override field.
export default class extends Controller {
  static targets = ["select", "amount"]
  static values = { subtotal: Number }

  apply() {
    const option = this.selectTarget.selectedOptions[0]

    // The <select> carries name="order[discount_record_id]" and submits itself,
    // so JS only has to work out the amount. Keeping the association in the
    // markup means a stale or broken controller can't silently drop it.
    this.amountTarget.value = option?.value ? this.#amountFor(option) : 0

    this.element.requestSubmit()
  }

  #amountFor(option) {
    return option.dataset.kind === "percentage"
      ? Math.round(this.subtotalValue * parseFloat(option.dataset.value)) / 100
      : parseFloat(option.dataset.value)
  }
}
