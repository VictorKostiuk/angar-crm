import { Controller } from "@hotwired/stimulus"

// select2-style picker for a <select> whose list grows with the base —
// clients, bikes, parts, suppliers (D66). The control shows what is chosen;
// opening it gives a search box over the options. You asked for select2 by
// name twice; D52's narrowing input above the native picker was the first
// answer and did not land.
//
// The native <select> stays in the form, hidden, and is what gets submitted:
// a form rejected by the server comes back with the choice still in place,
// and anything listening to the select's "change" (bike-preview, the rental
// client's documents) keeps working, because every pick dispatches one.
//
// Put data-controller="combobox" on the <select> itself. A `multiple` select
// shows its choices as chips with ×. An option's data-search adds words to
// match on beyond its label, and digits typed are also matched against the
// label's digits alone, so "0971234" finds "+380 97 123 45 67".
export default class extends Controller {
  static values = {
    placeholder: { type: String, default: "Оберіть…" },
    prompt: { type: String, default: "Пошук…" }
  }

  static LIMIT = 100

  connect() {
    this.select = this.element
    this.multiple = this.select.multiple
    // A page restored from Turbo's cache still carries the UI built last time.
    if (this.select.nextElementSibling?.hasAttribute("data-combobox-ui")) this.select.nextElementSibling.remove()

    this.build()
    this.render()
    this.rerender = () => this.render()
    this.select.addEventListener("change", this.rerender)
  }

  disconnect() {
    this.close()
    this.select.removeEventListener("change", this.rerender)
    this.label?.removeEventListener("click", this.focusControl)
    this.ui.remove()
    this.select.hidden = false
  }

  // --- building -------------------------------------------------------------

  build() {
    this.select.hidden = true

    this.ui = document.createElement("div")
    this.ui.setAttribute("data-combobox-ui", "")
    this.ui.className = "relative"

    this.control = document.createElement("div")
    this.control.tabIndex = 0
    this.control.setAttribute("role", "combobox")
    this.control.setAttribute("aria-expanded", "false")
    // The <label for> points at the hidden select; let it focus this instead.
    this.label = this.select.id ? document.querySelector(`label[for="${CSS.escape(this.select.id)}"]`) : null
    this.focusControl = (event) => { event.preventDefault(); this.control.focus() }
    this.label?.addEventListener("click", this.focusControl)
    this.control.className = this.select.className.replace(/\bblock\b/, "") +
      " flex flex-wrap items-center gap-1 bg-white text-left cursor-pointer min-h-[2.5rem]"
    this.control.addEventListener("click", (event) => this.toggle(event))
    this.control.addEventListener("keydown", (event) => this.controlKeydown(event))

    this.panel = document.createElement("div")
    this.panel.hidden = true
    this.panel.className = "absolute left-0 right-0 z-30 mt-1 rounded-md border border-gray-200 bg-white shadow-lg"

    this.search = document.createElement("input")
    this.search.type = "search"
    this.search.autocomplete = "off"
    this.search.placeholder = this.promptValue
    this.search.className = "block w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-brand-600"
    this.search.addEventListener("input", () => { this.active = 0; this.renderList() })
    this.search.addEventListener("keydown", (event) => this.searchKeydown(event))

    const box = document.createElement("div")
    box.className = "p-2 border-b border-gray-100"
    box.append(this.search)

    this.list = document.createElement("ul")
    this.list.setAttribute("role", "listbox")
    this.list.className = "max-h-64 overflow-y-auto py-1 text-sm"
    // mousedown, not click: keeps focus in the search box while picking.
    this.list.addEventListener("mousedown", (event) => event.preventDefault())
    this.list.addEventListener("click", (event) => {
      const item = event.target.closest("[data-index]")
      if (item) this.pick(this.matches[Number(item.dataset.index)])
    })

    this.panel.append(box, this.list)
    this.ui.append(this.control, this.panel)
    this.select.after(this.ui)
  }

  // --- the closed control ---------------------------------------------------

  render() {
    const chosen = Array.from(this.select.selectedOptions).filter((option) => option.value !== "")
    this.control.replaceChildren()

    if (this.multiple) {
      chosen.forEach((option) => this.control.append(this.chip(option)))
      if (chosen.length === 0) this.control.append(this.placeholder(this.placeholderValue))
    } else if (chosen.length) {
      const text = document.createElement("span")
      text.className = "flex-1 min-w-0 truncate"
      text.textContent = chosen[0].text
      this.control.append(text)
    } else {
      const blank = Array.from(this.select.options).find((option) => option.value === "")
      this.control.append(this.placeholder(blank?.text || this.placeholderValue))
    }

    const chevron = document.createElement("span")
    chevron.className = "ml-auto pl-1 text-gray-400"
    chevron.setAttribute("aria-hidden", "true")
    chevron.textContent = "▾"
    this.control.append(chevron)
  }

  placeholder(text) {
    const span = document.createElement("span")
    span.className = "flex-1 min-w-0 truncate text-gray-400"
    span.textContent = text
    return span
  }

  chip(option) {
    const chip = document.createElement("span")
    chip.className = "inline-flex items-center gap-1 rounded bg-gray-100 px-2 py-0.5 text-sm text-gray-800 max-w-full"
    const text = document.createElement("span")
    text.className = "truncate"
    text.textContent = option.text
    const remove = document.createElement("span")
    remove.setAttribute("role", "button")
    remove.setAttribute("aria-label", `Прибрати ${option.text}`)
    remove.className = "px-1 -mr-1 text-gray-500 hover:text-gray-900 cursor-pointer"
    remove.textContent = "×"
    remove.addEventListener("click", (event) => {
      event.stopPropagation()
      option.selected = false
      this.changed()
    })
    chip.append(text, remove)
    return chip
  }

  // --- opening, closing, keys ----------------------------------------------

  toggle(event) {
    if (event.target.closest("[role=button]")) return
    this.panel.hidden ? this.open() : this.close()
  }

  open(seed = "") {
    if (!this.panel.hidden) return

    this.panel.hidden = false
    this.control.setAttribute("aria-expanded", "true")
    this.search.value = seed
    this.active = 0
    this.renderList()
    this.search.focus()

    this.outside = (event) => { if (!this.ui.contains(event.target)) this.close() }
    document.addEventListener("click", this.outside, true)
  }

  close({ focus = false } = {}) {
    if (!this.panel || this.panel.hidden) return

    this.panel.hidden = true
    this.control.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.outside, true)
    if (focus) this.control.focus()
  }

  controlKeydown(event) {
    if ([ "Enter", " ", "ArrowDown" ].includes(event.key)) {
      event.preventDefault()
      this.open()
    } else if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
      // Typing straight onto the closed control starts a search with it.
      event.preventDefault()
      this.open(event.key)
    }
  }

  searchKeydown(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.move(1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.move(-1)
        break
      case "Enter":
        // Never submit the surrounding form from the search box.
        event.preventDefault()
        if (this.matches[this.active]) this.pick(this.matches[this.active])
        break
      case "Escape":
        // Inside a <dialog>, Escape would otherwise close the whole modal.
        event.preventDefault()
        event.stopPropagation()
        this.close({ focus: true })
        break
      case "Tab":
        this.close()
        break
    }
  }

  move(step) {
    if (this.matches.length === 0) return

    this.active = (this.active + step + this.matches.length) % this.matches.length
    this.renderList()
    this.list.querySelector(`[data-index="${this.active}"]`)?.scrollIntoView({ block: "nearest" })
  }

  // --- the list -------------------------------------------------------------

  renderList() {
    const needle = this.search.value.trim().toLowerCase()
    const digits = needle.replace(/\D/g, "")
    const numeric = digits.length >= 3 && /^[\d\s()+-]+$/.test(needle)

    const candidates = Array.from(this.select.options).filter((option) => !option.disabled &&
      !(this.multiple && option.value === ""))
    const found = candidates.filter((option) => {
      if (needle === "" || option.value === "") return true

      const haystack = `${option.text} ${option.dataset.search || ""}`.toLowerCase()
      return needle.split(/\s+/).every((word) => haystack.includes(word)) ||
        (numeric && haystack.replace(/\D/g, "").includes(digits))
    })

    this.matches = found.slice(0, this.constructor.LIMIT)
    if (this.active >= this.matches.length) this.active = 0

    const items = this.matches.map((option, index) => {
      const item = document.createElement("li")
      item.setAttribute("role", "option")
      item.setAttribute("aria-selected", option.selected ? "true" : "false")
      item.dataset.index = index
      item.className = [
        "flex items-center gap-2 px-3 py-2 cursor-pointer",
        index === this.active ? "bg-brand-50" : "hover:bg-gray-50",
        option.value === "" ? "text-gray-500" : "text-gray-900",
        option.selected && option.value !== "" ? "font-medium" : ""
      ].join(" ")

      const text = document.createElement("span")
      text.className = "flex-1 min-w-0"
      text.textContent = option.text
      item.append(text)
      if (option.selected && option.value !== "") {
        const tick = document.createElement("span")
        tick.className = "text-brand-600"
        tick.textContent = "✓"
        item.append(tick)
      }
      return item
    })

    if (this.matches.length === 0) items.push(this.note("Нічого не знайдено"))
    if (found.length > this.matches.length) items.push(this.note(`Ще ${found.length - this.matches.length} — уточніть пошук`))
    this.list.replaceChildren(...items)
  }

  note(text) {
    const item = document.createElement("li")
    item.className = "px-3 py-2 text-gray-400"
    item.textContent = text
    return item
  }

  pick(option) {
    if (!option) return

    if (this.multiple) {
      // Several picks in a row: the panel stays open and the search clears.
      option.selected = !option.selected
      this.search.value = ""
      this.changed()
      this.renderList()
      this.search.focus()
    } else {
      this.select.value = option.value
      this.changed()
      this.close({ focus: true })
    }
  }

  changed() {
    this.select.dispatchEvent(new Event("input", { bubbles: true }))
    this.select.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
