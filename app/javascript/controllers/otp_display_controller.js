import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["code", "countdown", "progress", "indicator"]
  static values = {
    url: String,
    type: String,
    period: { type: Number, default: 30 }
  }

  connect() {
    this.currentCode = null
    this.expiresAt = null
    this.refreshTimer = null
    this.countdownTimer = null

    // Fetch initial OTP code
    this.fetchOtp()

    // For TOTP, set up automatic refresh
    if (this.typeValue !== "hotp") {
      this.startCountdown()
    }
  }

  disconnect() {
    if (this.refreshTimer) clearTimeout(this.refreshTimer)
    if (this.countdownTimer) clearInterval(this.countdownTimer)
  }

  async fetchOtp() {
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        }
      })

      if (!response.ok) {
        const error = await response.json()
        console.error("OTP fetch error:", error)
        this.codeTarget.textContent = "Error"
        return
      }

      const data = await response.json()
      this.currentCode = data.code
      this.expiresAt = data.expires_at ? new Date(data.expires_at) : null

      // Display the code with spacing for readability
      this.codeTarget.textContent = this.formatCode(data.code)

      // For TOTP, schedule next refresh
      if (this.typeValue !== "hotp" && data.remaining_seconds) {
        this.scheduleRefresh(data.remaining_seconds)
      }
    } catch (error) {
      console.error("Failed to fetch OTP:", error)
      this.codeTarget.textContent = "Error"
    }
  }

  formatCode(code) {
    // Add space in the middle for 6-digit codes: "123 456"
    if (code && code.length === 6) {
      return `${code.slice(0, 3)} ${code.slice(3)}`
    }
    return code || "------"
  }

  scheduleRefresh(remainingSeconds) {
    // Clear any existing timer
    if (this.refreshTimer) clearTimeout(this.refreshTimer)

    // Schedule refresh 1 second before expiry to ensure smooth transition
    const refreshIn = Math.max(0, (remainingSeconds - 1) * 1000)
    this.refreshTimer = setTimeout(() => {
      this.fetchOtp()
    }, refreshIn)
  }

  startCountdown() {
    // Clear any existing countdown
    if (this.countdownTimer) clearInterval(this.countdownTimer)

    // Update countdown every second
    this.countdownTimer = setInterval(() => {
      this.updateCountdown()
    }, 1000)

    // Initial update
    this.updateCountdown()
  }

  updateCountdown() {
    if (!this.expiresAt) return

    const now = new Date()
    const remaining = Math.max(0, Math.ceil((this.expiresAt - now) / 1000))

    // Update countdown text
    if (this.hasCountdownTarget) {
      this.countdownTarget.textContent = `${remaining}s`
    }

    // Update progress bar
    if (this.hasProgressTarget) {
      const progress = (remaining / this.periodValue) * 100
      this.progressTarget.style.width = `${progress}%`

      // Change color when low
      if (remaining <= 5) {
        this.progressTarget.style.background = "var(--color-red-500)"
      } else if (remaining <= 10) {
        this.progressTarget.style.background = "var(--color-amber-500)"
      } else {
        this.progressTarget.style.background = "var(--color-primary-500)"
      }
    }

    // Update indicator color
    if (this.hasIndicatorTarget) {
      if (remaining <= 5) {
        this.indicatorTarget.style.background = "var(--color-red-500)"
      } else if (remaining <= 10) {
        this.indicatorTarget.style.background = "var(--color-amber-500)"
      } else {
        this.indicatorTarget.style.background = "var(--color-emerald-500)"
      }
    }

    // If expired, fetch new code
    if (remaining === 0) {
      this.fetchOtp()
    }
  }

  copy() {
    if (!this.currentCode) return

    navigator.clipboard.writeText(this.currentCode)
      .then(() => {
        // Show feedback
        const originalText = this.codeTarget.textContent
        this.codeTarget.textContent = "Copied!"
        setTimeout(() => {
          this.codeTarget.textContent = this.formatCode(this.currentCode)
        }, 1000)
      })
      .catch(err => {
        console.error("Failed to copy:", err)
      })
  }

  refresh() {
    // For HOTP - manually generate next code
    this.fetchOtp()
  }
}
