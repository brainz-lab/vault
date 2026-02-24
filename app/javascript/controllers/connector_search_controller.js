import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "search"]

  filter() {
    clearTimeout(this._debounce)
    this._debounce = setTimeout(() => {
      this.formTarget.requestSubmit()
    }, 300)
  }

  submit() {
    this.formTarget.requestSubmit()
  }
}
