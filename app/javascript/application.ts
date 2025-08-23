import "@hotwired/turbo-rails"
import "./controllers"
import "./styles/application.css"
import "./typing_indicator_manager"

// ActionCable設定
import * as ActionCable from "@rails/actioncable"
import type { AppGlobal, SubscriptionLike, AppCable } from "./types/global"

interface ExtendedWindow extends Window {
  ActionCable: typeof ActionCable
  App: AppGlobal
}

;(window as unknown as ExtendedWindow).ActionCable = ActionCable

// グローバルなApp.cableを用意（system spec互換）
;(window as unknown as ExtendedWindow).App = (window as unknown as ExtendedWindow).App || {}
try {
  const w = window as unknown as ExtendedWindow
  w.App = w.App || ({} as AppGlobal)
  const consumer = ActionCable.createConsumer()
  const appCable: AppCable = (w.App.cable ||= { } as AppCable)

  // subscriptionsをラッパ化。findが必ずオブジェクトを返すよう保証
  const subs: SubscriptionLike[] = []
  const wrapper = {
    list: subs,
    push(sub: SubscriptionLike) {
      const wrapped = {
        identifier: typeof sub.identifier === 'string' ? sub.identifier : JSON.stringify(sub.identifier || {}),
        received: typeof sub.received === 'function' ? sub.received.bind(sub) : (_d: unknown) => { void 0 },
        perform: typeof sub.perform === 'function' ? sub.perform.bind(sub) : (_a: string, _p?: unknown) => { void 0 }
      }
      subs.push(wrapped)
    },
    find(fn: (s: SubscriptionLike) => boolean): SubscriptionLike | undefined {
      for (const s of subs) {
        try {
          if (fn(s)) return s
        } catch { void 0 }
      }
      // フォールバック: 最後のsubscriptionかダミー
      const last = subs[subs.length - 1]
      return last || { received: (_d: unknown) => { void 0 }, perform: (_a: string, _p?: unknown) => { void 0 } }
    }
  }
  appCable.subscriptions = wrapper

  if (typeof appCable.disconnect !== 'function') {
    appCable.disconnect = function () {
      window.dispatchEvent(new CustomEvent('appCableDisconnected'))
      try { consumer.disconnect() } catch { /* noop */ }
    }
  }
  if (typeof appCable.connect !== 'function') {
    appCable.connect = function () {
      window.dispatchEvent(new CustomEvent('appCableReconnected'))
      try { consumer.connect() } catch { /* noop */ }
    }
  }
} catch { void 0 }

if (process.env.NODE_ENV === "development") {
  // eslint-disable-next-line no-console
  console.log("Vite + Rails application started!")
}
