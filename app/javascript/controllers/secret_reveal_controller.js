import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hidden", "value", "button"]

  toggle() {
    const isHidden = this.hiddenTarget.classList.contains("hidden")

    if (isHidden) {
      this.hiddenTarget.classList.add("hidden")
      this.valueTarget.classList.remove("hidden")
      this.buttonTarget.textContent = "Hide"
    } else {
      this.hiddenTarget.classList.remove("hidden")
      this.valueTarget.classList.add("hidden")
      this.buttonTarget.textContent = "Show"
    }
  }

  copy(event) {
    const text = event.currentTarget.dataset.clipboardText
    navigator.clipboard.writeText(text).then(() => {
      const originalText = event.currentTarget.textContent
      event.currentTarget.textContent = "Copied!"
      setTimeout(() => {
        event.currentTarget.textContent = originalText
      }, 2000)
    })
  }
}
