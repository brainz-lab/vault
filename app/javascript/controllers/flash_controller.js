import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: Number }

  connect() {
    if (this.timeoutValue > 0) {
      setTimeout(() => {
        this.dismiss()
      }, this.timeoutValue)
    }
  }

  dismiss() {
    this.element.style.opacity = "0"
    this.element.style.transition = "opacity 0.3s ease-out"
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}
