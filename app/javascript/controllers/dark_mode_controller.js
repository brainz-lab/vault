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
 *     <button class="dm-toggle" data-action="click->dark-mode#toggle">
 *       <svg class="icon-sun">...</svg>
 *       <svg class="icon-moon">...</svg>
 *     </button>
 *   </html>
 */
export default class extends Controller {
  static targets = ["icon"]

  // Unified localStorage key for all BrainzLab products
  static values = {
    storageKey: { type: String, default: "brainzlab-theme" }
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
   * Update toggle button icon
   */
  updateIcon(theme) {
    if (!this.hasIconTarget) return

    if (theme === "dark") {
      // Sun icon for dark mode (click to go light)
      this.iconTarget.innerHTML = `
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
        </svg>
      `
    } else {
      // Moon icon for light mode (click to go dark)
      this.iconTarget.innerHTML = `
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
        </svg>
      `
    }
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
