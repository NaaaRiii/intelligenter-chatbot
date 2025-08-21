import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

// Auto-register all controllers
const controllers = import.meta.glob("./*_controller.ts", { eager: true })

Object.entries(controllers).forEach(([path, module]: [string, any]) => {
  const name = path.replace("./", "").replace("_controller.ts", "").replace(/_/g, "-")

  application.register(name, module.default)
})

export { application }
