import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "connectorSelect",
    "secretTextFields",
    "basicFields",
    "customAuthFields",
    "customAuthContainer",
    "customAuthDescription",
    "oauth2Fields"
  ]

  connect() {
    // Show correct fields if connector is pre-selected
    this.connectorChanged()
  }

  connectorChanged() {
    this.hideAllFields()

    const selected = this.connectorSelectTarget.selectedOptions[0]
    if (!selected || !selected.value) return

    const authType = selected.dataset.authType

    switch (authType) {
      case "SECRET_TEXT":
        this.secretTextFieldsTarget.classList.remove("hidden")
        break
      case "BASIC":
        this.basicFieldsTarget.classList.remove("hidden")
        break
      case "CUSTOM_AUTH":
        this.customAuthFieldsTarget.classList.remove("hidden")
        this.renderCustomAuthFields(selected.dataset.authSchema)
        break
      case "OAUTH2":
        this.oauth2FieldsTarget.classList.remove("hidden")
        break
    }
  }

  hideAllFields() {
    if (this.hasSecretTextFieldsTarget) this.secretTextFieldsTarget.classList.add("hidden")
    if (this.hasBasicFieldsTarget) this.basicFieldsTarget.classList.add("hidden")
    if (this.hasCustomAuthFieldsTarget) this.customAuthFieldsTarget.classList.add("hidden")
    if (this.hasOauth2FieldsTarget) this.oauth2FieldsTarget.classList.add("hidden")
  }

  renderCustomAuthFields(schemaJson) {
    const container = this.customAuthContainerTarget
    container.innerHTML = ""

    let schema = {}
    try {
      schema = JSON.parse(schemaJson || "{}")
    } catch (e) {
      schema = {}
    }

    const entries = Object.entries(schema)
    if (entries.length === 0) {
      container.innerHTML = '<p class="text-sm text-muted">No custom fields defined</p>'
      return
    }

    entries.forEach(([name, config]) => {
      const div = document.createElement("div")

      const label = document.createElement("label")
      label.className = "label"
      label.textContent = config.displayName || name

      const input = document.createElement("input")
      input.type = config.type === "password" ? "password" : "text"
      input.name = `credentials[${name}]`
      input.className = "input"
      if (config.description) input.placeholder = config.description
      if (config.required) input.required = true

      div.appendChild(label)
      div.appendChild(input)

      if (config.description) {
        const hint = document.createElement("p")
        hint.className = "text-xs mt-1.5"
        hint.style.color = "var(--color-ink-400)"
        hint.textContent = config.description
        div.appendChild(hint)
      }

      container.appendChild(div)
    })
  }
}
