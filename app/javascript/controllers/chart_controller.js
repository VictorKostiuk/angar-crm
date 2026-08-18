import { Controller } from "@hotwired/stimulus"
import { Chart } from "chart.js/auto"

// Renders one Chart.js chart from a JSON config passed straight through
// via data-chart-config-value — generic on purpose, so every chart on
// Статистика shares one controller instead of one per chart type.
export default class extends Controller {
  static values = { config: Object }

  connect() {
    this.chart = new Chart(this.element, this.configValue)
  }

  disconnect() {
    this.chart?.destroy()
  }
}
