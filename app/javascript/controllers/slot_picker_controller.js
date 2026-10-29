import { Controller } from "@hotwired/stimulus"

// Re-fetches the free times into the "booking_slots" frame when the date or
// the type of ТО changes — the server is the only one who knows what is free.
export default class extends Controller {
  static targets = [ "date", "type", "frame" ]
  static values = { url: String }

  refresh() {
    const params = new URLSearchParams({
      date: this.dateTarget.value,
      maintenance_type_id: this.typeTarget.value
    })
    this.frameTarget.src = `${this.urlValue}?${params}`
  }
}
