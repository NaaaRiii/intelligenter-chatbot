import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon"]
  
  declare readonly iconTarget: HTMLElement
  declare readonly hasIconTarget: boolean

  connect(): void {
    // ローカルストレージから設定を読み込み
    const darkMode = localStorage.getItem("darkMode") === "true"
    if (darkMode) {
      document.documentElement.classList.add("dark")
      this.updateIcon(true)
    }
  }

  toggle(): void {
    const isDark = document.documentElement.classList.toggle("dark")
    localStorage.setItem("darkMode", isDark.toString())
    this.updateIcon(isDark)
  }

  private updateIcon(isDark: boolean): void {
    if (this.hasIconTarget) {
      this.iconTarget.textContent = isDark ? "☀️" : "🌙"
    }
  }
}