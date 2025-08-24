import { describe, it, expect, beforeEach, vi } from 'vitest'
import { Application } from '@hotwired/stimulus'
import HelloController from '@/controllers/hello_controller'

describe('HelloController', () => {
  let application: Application
  let element: HTMLElement

  beforeEach(() => {
    // Set up DOM
    document.body.innerHTML = `
      <div data-controller="hello">
        <div data-hello-target="output"></div>
        <button data-action="click->hello#greet" data-name="Test User">
          Greet
        </button>
      </div>
    `

    // Initialize Stimulus
    application = Application.start()
    application.register('hello', HelloController)

    const found = document.querySelector('[data-controller="hello"]')
    expect(found).not.toBeNull()
    element = found as HTMLElement
  })

  it('should connect and set output text', () => {
    const output = element.querySelector('[data-hello-target="output"]')
    expect(output?.textContent).toBe('Hello from Stimulus + TypeScript!')
  })

  it('should show alert when greet is called', () => {
    const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {})
    const button = element.querySelector('button')
    expect(button).not.toBeNull()
    ;(button as HTMLButtonElement).click()
    
    expect(alertSpy).toHaveBeenCalledWith('Hello, Test User!')
    alertSpy.mockRestore()
  })

  it('should use default name when data-name is not provided', () => {
    const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {})
    
    // Create button without data-name
    document.body.innerHTML = `
      <div data-controller="hello">
        <button data-action="click->hello#greet">Greet</button>
      </div>
    `
    
    const button2 = document.querySelector('button')
    expect(button2).not.toBeNull()
    ;(button2 as HTMLButtonElement).click()
    
    expect(alertSpy).toHaveBeenCalledWith('Hello, World!')
    alertSpy.mockRestore()
  })
})