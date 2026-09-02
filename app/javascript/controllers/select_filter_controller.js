import { Controller } from "@hotwired/stimulus"

// Type-to-narrow for a long <select>, without replacing it.
//
// select2 and friends swap the native control for a scripted listbox. On this
// app's primary device — a shop-floor tablet (D45) — that trades the OS picker,
// which is the best control touch has, for a fiddly div. So the <select> stays
// exactly what it was; an input above it just narrows which options are in it.
//
// Options are rebuilt from a snapshot rather than hidden in place: `display:
// none` on an <option> is ignored by Safari, which would leave the filter
// looking broken on precisely the iPads this is for. A blank option (the "own
// item" / "no selection" row) always survives the filter, and so does whatever
// is currently selected — narrowing the list must never silently change what
// the form will submit.
export default class extends Controller {
  static targets = ["input", "select"]

  connect() {
    this.options = Array.from(this.selectTarget.options).map((option) => ({
      value: option.value,
      text: option.text,
      haystack: option.text.toLowerCase()
    }))
  }

  filter() {
    const needle = this.inputTarget.value.trim().toLowerCase()
    const selected = this.selectTarget.value
    const matches = this.options.filter(
      (option) => option.value === "" || option.value === selected || option.haystack.includes(needle)
    )

    this.selectTarget.replaceChildren(
      ...matches.map((option) => new Option(option.text, option.value, false, option.value === selected))
    )
  }
}
