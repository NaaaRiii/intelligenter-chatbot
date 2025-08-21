import "@hotwired/turbo-rails"
import "./controllers"

// ActionCable設定
import * as ActionCable from "@rails/actioncable"
(window as any).ActionCable = ActionCable

console.log("Vite + Rails application started!")