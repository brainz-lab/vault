import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hidden", "value", "button"]

  connect() {
    console.log("SecretRevealController connected", this.element)
  }

  toggle() {
    console.log("toggle called")
    this.hiddenTarget.classList.toggle("hidden")
    this.valueTarget.classList.toggle("hidden")

    const isRevealed = !this.valueTarget.classList.contains("hidden")
    this.buttonTarget.textContent = isRevealed ? "Hide" : "Show"
  }

  copy(event) {
    console.log("copy called")
    const button = event.currentTarget
    const text = button.dataset.clipboardText
    console.log("clipboard text:", text)

    if (!text) {
      console.error("No clipboard text found")
      return
    }

    navigator.clipboard.writeText(text)
      .then(() => {
        const originalText = button.textContent
        button.textContent = "Copied!"
        setTimeout(() => {
          button.textContent = originalText
        }, 2000)
      })
      .catch((err) => {
        console.error("Failed to copy:", err)
        // Fallback for older browsers or non-secure contexts
        const textarea = document.createElement("textarea")
        textarea.value = text
        textarea.style.position = "fixed"
        textarea.style.opacity = "0"
        document.body.appendChild(textarea)
        textarea.select()
        try {
          document.execCommand("copy")
          const originalText = button.textContent
          button.textContent = "Copied!"
          setTimeout(() => {
            button.textContent = originalText
          }, 2000)
        } catch (e) {
          console.error("Fallback copy failed:", e)
        }
        document.body.removeChild(textarea)
      })
  }
}
