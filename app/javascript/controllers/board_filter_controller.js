import { Controller } from "@hotwired/stimulus"

// Client-side status filter for the Майстерня board (docs/PLAN.md P5.1/P9).
// Deliberately client-side, not a server-rendered filter: the "approve"
// quick action's Turbo Stream targets every section's #board_section_*_cards
// id unconditionally, so every section must always exist in the DOM — this
// only ever toggles a `hidden` class, never removes/omits a section.
export default class extends Controller {
  static targets = ["section", "pill"]

  filter(event) {
    const status = event.currentTarget.dataset.status

    this.sectionTargets.forEach((section) => {
      section.classList.toggle("hidden", status !== "all" && section.dataset.status !== status)
    })

    this.pillTargets.forEach((pill) => {
      const active = pill.dataset.status === status
      pill.classList.toggle("bg-brand-600", active)
      pill.classList.toggle("text-white", active)
      pill.classList.toggle("border", !active)
      pill.classList.toggle("border-gray-200", !active)
      pill.classList.toggle("text-gray-700", !active)
      pill.classList.toggle("hover:bg-gray-50", !active)
    })
  }
}
