import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["actionSelect", "inputFields", "form", "submitBtn"]

  actionChanged() {
    const selected = this.actionSelectTarget.selectedOptions[0]
    if (!selected || !selected.value) {
      this.inputFieldsTarget.innerHTML = ""
      return
    }

    let props = {}
    try {
      props = JSON.parse(selected.dataset.props || "{}")
    } catch (e) {
      props = {}
    }

    this.renderInputFields(props)
  }

  renderInputFields(props) {
    const container = this.inputFieldsTarget
    container.innerHTML = ""

    const entries = Object.entries(props)
    if (entries.length === 0) return

    entries.forEach(([name, config]) => {
      const div = document.createElement("div")
      const isRequired = config && config.required
      const type = (config && config.type) || "string"
      const description = config && config.description

      const label = document.createElement("label")
      label.className = "label"
      label.textContent = name
      if (isRequired) {
        const req = document.createElement("span")
        req.className = "text-red-500 ml-1"
        req.textContent = "*"
        label.appendChild(req)
      }
      div.appendChild(label)

      let input
      if (type === "text" || type === "json" || type === "object") {
        input = document.createElement("textarea")
        input.rows = 3
      } else if (type === "boolean") {
        input = document.createElement("select")
        input.innerHTML = '<option value="">--</option><option value="true">true</option><option value="false">false</option>'
      } else if (type === "number" || type === "integer") {
        input = document.createElement("input")
        input.type = "number"
      } else {
        input = document.createElement("input")
        input.type = "text"
      }

      input.name = `input[${name}]`
      input.className = "input" + (type === "json" || type === "object" ? " font-mono text-sm" : "")
      if (config && config.placeholder) input.placeholder = config.placeholder
      if (isRequired) input.required = true

      div.appendChild(input)

      if (description) {
        const hint = document.createElement("p")
        hint.className = "text-xs mt-1.5"
        hint.style.color = "var(--color-ink-400)"
        hint.textContent = description
        div.appendChild(hint)
      }

      container.appendChild(div)
    })
  }
}
