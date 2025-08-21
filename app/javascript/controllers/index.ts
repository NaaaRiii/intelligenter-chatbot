import { Application, Controller } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

// Auto-register all controllers
interface ControllerModule {
  default: typeof Controller
}

const controllers = import.meta.glob<ControllerModule>("./*_controller.ts", { eager: true })

Object.entries(controllers).forEach(([path, module]) => {
  const name = path.replace("./", "").replace("_controller.ts", "").replace(/_/g, "-")

  application.register(name, module.default)
})

export { application }
