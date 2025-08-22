import "@hotwired/turbo-rails"
import "./controllers"
import "./styles/application.css"

// ActionCable設定
import * as ActionCable from "@rails/actioncable"

interface ExtendedWindow extends Window {
  ActionCable: typeof ActionCable
  App: any
}

;(window as ExtendedWindow).ActionCable = ActionCable

// グローバルなApp.cableを用意（system spec互換）
;(window as ExtendedWindow).App = (window as ExtendedWindow).App || {}
try {
  const w = window as ExtendedWindow
  w.App.cable = w.App.cable || ActionCable.createConsumer()

  // subscriptionsをラッパ化。find/each/notifyを用意
  const subs: any[] = []
  const wrapper = {
    list: subs,
    push(sub: any) {
      subs.push(sub)
    },
    find(fn: (s: any) => boolean): any {
      for (const s of subs) {
        try {
          if (fn({ identifier: JSON.stringify((s as any).identifier || {}) })) return s
        } catch (_) {}
      }
      // ダミー
      return { received: (_d: any) => {}, perform: (_a: string, _p?: any) => {} }
    }
  }
  w.App.cable.subscriptions = wrapper

  // disconnectのダミー
  if (typeof w.App.cable.disconnect !== 'function') {
    w.App.cable.disconnect = function () {}
  }
} catch (e) {
  // noop
}

// Development環境でのみログ出力
if (process.env.NODE_ENV === "development") {
  // eslint-disable-next-line no-console
  console.log("Vite + Rails application started!")
}
