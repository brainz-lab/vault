import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "credentialFields", "otpFields", "periodField", "valueLabel"]

  connect() {
    // Initial toggle based on current selection
    this.toggle()
  }

  toggle() {
    const selectedType = this.hasSelectTarget ? this.selectTarget.value : null
    const isCredentialType = ["credential", "totp", "hotp"].includes(selectedType)
    const isOtpType = isCredentialType
    const isHotp = selectedType === "hotp"

    // Toggle credential fields
    if (this.hasCredentialFieldsTarget) {
      this.credentialFieldsTarget.classList.toggle("hidden", !isCredentialType)
    }

    // Toggle OTP fields
    if (this.hasOtpFieldsTarget) {
      this.otpFieldsTarget.classList.toggle("hidden", !isOtpType)
    }

    // Hide period field for HOTP (counter-based doesn't use period)
    if (this.hasPeriodFieldTarget) {
      this.periodFieldTarget.classList.toggle("hidden", isHotp)
    }

    // Update value label
    if (this.hasValueLabelTarget) {
      this.valueLabelTarget.textContent = isCredentialType ? "Password" : "Secret Value"
    }
  }
}
