import { Controller } from "@hotwired/stimulus"

/**
 * Dark Mode Controller - BrainzLab Standard
 *
 * Standardized dark mode implementation for all BrainzLab products.
 * Uses unified localStorage key: `brainzlab-theme`
 *
 * Features:
 * - localStorage persistence with unified key across all products
 * - System preference detection (prefers-color-scheme)
 * - Smooth transitions between themes
 * - Consistent API: toggle(), setLight(), setDark(), setSystem()
 *
 * Usage:
 *   <html data-controller="dark-mode">
 *     <%%= render Brainzlab::Components::DarkModeToggle.new(data_action: "click->dark-mode#toggle") %>
 *   </html>
 */
export default class extends Controller {
  static targets = ["sunIcon", "moonIcon"]

  // Unified localStorage key for all BrainzLab products
  static values = {
    storageKey: { type: String, default: "brainzlab-theme" },
    defaultTheme: { type: String, default: "light" }
  }

  connect() {
    // Prevent transition flash on initial load
    document.documentElement.classList.add("no-transitions")

    // Initialize theme based on stored preference or system preference
    this.initializeTheme()

    // Re-enable transitions after initial render
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        document.documentElement.classList.remove("no-transitions")
      })
    })

    // Listen for system theme changes
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.boundHandleSystemChange = this.handleSystemChange.bind(this)
    this.mediaQuery.addEventListener("change", this.boundHandleSystemChange)
  }

  disconnect() {
    if (this.mediaQuery && this.boundHandleSystemChange) {
      this.mediaQuery.removeEventListener("change", this.boundHandleSystemChange)
    }
  }

  /**
   * Initialize theme based on stored preference or system preference
   */
  initializeTheme() {
    const storedTheme = localStorage.getItem(this.storageKeyValue)

    if (storedTheme === "dark") {
      this.applyTheme("dark", false)
    } else if (storedTheme === "light") {
      this.applyTheme("light", false)
    } else if (this.defaultThemeValue) {
      // ENV-configured default theme (e.g., light when BRAINZLAB_LOGO_LIGHT_URL is set)
      this.applyTheme(this.defaultThemeValue, false)
    } else {
      // No stored preference - use system preference
      const prefersDark = this.mediaQuery.matches
      this.applyTheme(prefersDark ? "dark" : "light", false)
    }
  }

  /**
   * Toggle between light and dark themes
   */
  toggle(event) {
    if (event) event.preventDefault()

    const newTheme = this.isDark ? "light" : "dark"
    this.setTheme(newTheme)
  }

  /**
   * Set theme to light mode
   */
  setLight(event) {
    if (event) event.preventDefault()
    this.setTheme("light")
  }

  /**
   * Set theme to dark mode
   */
  setDark(event) {
    if (event) event.preventDefault()
    this.setTheme("dark")
  }

  /**
   * Reset to system preference
   */
  setSystem(event) {
    if (event) event.preventDefault()
    localStorage.removeItem(this.storageKeyValue)
    const prefersDark = this.mediaQuery.matches
    this.applyTheme(prefersDark ? "dark" : "light", true)
  }

  /**
   * Set and persist a theme
   */
  setTheme(theme) {
    localStorage.setItem(this.storageKeyValue, theme)
    this.applyTheme(theme, true)
  }

  /**
   * Apply theme to document
   */
  applyTheme(theme, animate = true) {
    const html = document.documentElement

    if (animate) {
      html.classList.add("transitioning")
    }

    if (theme === "dark") {
      html.classList.add("dark")
      html.classList.remove("light")
    } else {
      html.classList.remove("dark")
      html.classList.add("light")
    }

    // Update meta theme-color for mobile browsers
    this.updateThemeColor(theme)

    // Update icon if target exists
    this.updateIcon(theme)

    if (animate) {
      setTimeout(() => {
        html.classList.remove("transitioning")
      }, 200)
    }

    // Dispatch custom event for other components to react
    this.dispatch("changed", { detail: { theme, isDark: theme === "dark" } })
  }

  /**
   * Update meta theme-color tag for mobile browsers
   */
  updateThemeColor(theme) {
    const meta = document.querySelector('meta[name="theme-color"]')
    if (meta) {
      meta.setAttribute("content", theme === "dark" ? "#121212" : "#FAFAF9")
    }
  }

  /**
   * Update toggle button icons (show/hide sun/moon from gem component)
   */
  updateIcon(theme) {
    const isDark = theme === "dark"
    if (this.hasSunIconTarget) this.sunIconTarget.classList.toggle("hidden", !isDark)
    if (this.hasMoonIconTarget) this.moonIconTarget.classList.toggle("hidden", isDark)
  }

  /**
   * Handle system color scheme changes
   */
  handleSystemChange(event) {
    // Only respond to system changes if no explicit preference is stored
    const storedTheme = localStorage.getItem(this.storageKeyValue)
    if (!storedTheme) {
      this.applyTheme(event.matches ? "dark" : "light", true)
    }
  }

  /**
   * Check if dark mode is currently active
   */
  get isDark() {
    return document.documentElement.classList.contains("dark")
  }

  /**
   * Get current theme
   */
  get currentTheme() {
    return this.isDark ? "dark" : "light"
  }

  /**
   * Get stored preference
   * Returns: "dark", "light", or null (system)
   */
  get storedPreference() {
    return localStorage.getItem(this.storageKeyValue)
  }
}
