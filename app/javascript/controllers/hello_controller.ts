import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]

  declare readonly outputTarget: HTMLElement
  declare readonly hasOutputTarget: boolean

  connect(): void {
    console.log("Hello controller connected")
    if (this.hasOutputTarget) {
      this.outputTarget.textContent = "Hello from Stimulus + TypeScript!"
    }
  }

  greet(event: Event): void {
    event.preventDefault()
    const name = (event.currentTarget as HTMLElement).dataset.name || "World"
    alert(`Hello, ${name}!`)
  }
}
