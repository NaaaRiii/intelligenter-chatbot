import "@hotwired/turbo-rails"
import "./controllers"
import "./styles/application.css"

// ActionCable設定
import * as ActionCable from "@rails/actioncable"

interface ExtendedWindow extends Window {
  ActionCable: typeof ActionCable
}

;(window as ExtendedWindow).ActionCable = ActionCable

// Development環境でのみログ出力
if (process.env.NODE_ENV === "development") {
  // eslint-disable-next-line no-console
  console.log("Vite + Rails application started!")
}
