import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  copy() {
    navigator.clipboard.writeText(this.textValue).then(() => {
      const originalContent = this.element.textContent
      this.element.textContent = "Copied!"
      setTimeout(() => {
        this.element.textContent = originalContent
      }, 2000)
    })
  }
}
