import { Controller } from "@hotwired/stimulus"

// Points a Turbo Frame at a URL built from a <select>'s value, so part of a
// form can follow a choice made in it — the rental form's "documents already
// on file" box follows the chosen client (D67). The URL carries "__id__"
// where the value goes; a blank choice empties the frame.
export default class extends Controller {
  static values = { url: String, frame: String }

  load() {
    const frame = document.getElementById(this.frameValue)
    if (!frame) return

    const id = this.element.value
    if (id === "") {
      frame.removeAttribute("src")
      frame.replaceChildren()
    } else {
      frame.src = this.urlValue.replace("__id__", encodeURIComponent(id))
    }
  }
}
