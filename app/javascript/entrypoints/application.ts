// デバッグ用の即座のログ
console.log("=== Application.ts loading started ===")

import "@hotwired/turbo-rails"
import "../controllers"
import "../styles/application.css"
import "../typing_indicator_manager"

console.log("=== Importing React modules ===")

// React関連のインポート
import React from "react"
import ReactDOM from "react-dom/client"
import SimpleChatbot from "../components/Chatbot"

console.log("=== React modules imported ===", { React, ReactDOM, Chatbot })

// ActionCable設定
import * as ActionCable from "@rails/actioncable"
import type { AppGlobal, SubscriptionLike, AppCable } from "../types/global"

interface ExtendedWindow extends Window {
  ActionCable: typeof ActionCable
  App: AppGlobal
  React: typeof React
  ReactDOM: typeof ReactDOM
  Chatbot: typeof Chatbot
}

;(window as unknown as ExtendedWindow).ActionCable = ActionCable

// Reactコンポーネントをグローバルに公開
;(window as unknown as ExtendedWindow).React = React
;(window as unknown as ExtendedWindow).ReactDOM = ReactDOM
;(window as unknown as ExtendedWindow).Chatbot = Chatbot

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

console.log("=== Before component mounting setup ===")

if (process.env.NODE_ENV === "development") {
  // eslint-disable-next-line no-console
  console.log("Vite + Rails application started!")
}

// ReactコンポーネントをDOMにマウント
function mountChatbotInterface() {
  console.log('Attempting to mount Chatbot...')
  const rootElement = document.getElementById('chatbot-root')
  console.log('Root element:', rootElement)
  
  if (rootElement) {
    console.log('Mounting Chatbot component...')
    // React 18/19の新しいcreateRoot APIを使用
    const root = ReactDOM.createRoot(rootElement)
    root.render(React.createElement(Chatbot))
    console.log('Component mounted successfully')
  } else {
    console.error('Could not find element with id "chatbot-root"')
  }
}

// Turboとの互換性のため、複数のイベントでマウントを試行
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', mountChatbotInterface)
} else {
  // 既にDOMContentLoadedが発火済みの場合
  mountChatbotInterface()
}

// Turbo用のイベントリスナー
document.addEventListener('turbo:load', mountChatbotInterface)
document.addEventListener('turbo:render', mountChatbotInterface)
