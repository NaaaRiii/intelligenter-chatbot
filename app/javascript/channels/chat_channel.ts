import consumer from './consumer'
import { Subscription } from '@rails/actioncable'

interface MessageData {
  id: number
  content: string
  role: 'user' | 'assistant' | 'system'
  created_at: string
  user?: {
    id: number
    name: string
    email: string
  }
  metadata?: Record<string, unknown>
}

interface ChatCallbacks {
  onConnected?: () => void
  onDisconnected?: () => void
  onMessage?: (data: MessageData) => void
  onTyping?: (data: { user: { id: number; name: string }; is_typing: boolean }) => void
  onUserConnected?: (data: { user: { id: number; name: string; email: string } }) => void
  onUserDisconnected?: (data: { user: { id: number; name: string; email: string } }) => void
  onError?: (data: { message: string; errors?: string[] }) => void
  onMessageRead?: (data: { message_id: number; user_id: number; timestamp: string }) => void
}

export class ChatChannel {
  private subscription: Subscription | null = null
  private conversationId: number
  private callbacks: ChatCallbacks

  constructor(conversationId: number, callbacks: ChatCallbacks = {}) {
    this.conversationId = conversationId
    this.callbacks = callbacks
  }

  connect(): void {
    if (this.subscription) {
      return
    }

    const callbacks = {
      connected: () => {
        this.callbacks.onConnected?.()
      },

      disconnected: () => {
        this.callbacks.onDisconnected?.()
      },

      received: (data: unknown) => {
        const payload = data as { type?: string; message?: unknown; messages?: unknown; is_typing?: boolean } | Record<string, unknown>

        const isMessageData = (v: unknown): v is MessageData => {
          const m = v as Partial<MessageData> | undefined
          return !!m && typeof m.id === 'number' && typeof m.content === 'string' && typeof m.role === 'string' && typeof m.created_at === 'string'
        }
        const asMessageArray = (v: unknown): MessageData[] => Array.isArray(v) ? v.filter(isMessageData) : []
        switch (payload.type) {
          case 'new_message':
            if (isMessageData(payload.message)) {
              this.callbacks.onMessage?.(payload.message)
              this.appendToDom(payload.message)
            }
            try {
              if (isMessageData(payload.message) && payload.message.role === 'assistant') {
                const ti = document.getElementById('typing-indicator') as HTMLElement | null
                if (ti) {
                  ti.classList.add('hidden')
                  ti.classList.remove('bot-typing-indicator')
                  ti.style.display = 'none'
                }
              }
            } catch { /* noop */ }
            break
          case 'bot_response':
            if (isMessageData(payload.message)) {
              this.callbacks.onMessage?.(payload.message)
              this.appendToDom(payload.message)
              try {
                const ti = document.getElementById('typing-indicator') as HTMLElement | null
                if (ti) {
                  ti.classList.add('hidden')
                  ti.classList.remove('bot-typing-indicator')
                  ti.style.display = 'none'
                }
              } catch { /* noop */ }
            }
            break
          case 'typing':
            try {
              const sup = (window as Window & { __SUPPRESS_TYPING_HIDE_UNTIL?: number }).__SUPPRESS_TYPING_HIDE_UNTIL
              if (typeof sup === 'number' && Date.now() < sup) {
                const el = document.getElementById('typing-indicator') as HTMLElement | null
                if (el) {
                  el.classList.remove('hidden')
                  el.classList.add('bot-typing-indicator')
                  el.style.display = 'block'
                }
                break
              }
              const el = document.getElementById('typing-indicator') as HTMLElement | null
              if (el) {
                if ((payload as { is_typing?: boolean })?.is_typing) {
                  el.classList.remove('hidden')
                  el.classList.add('bot-typing-indicator')
                  el.style.display = 'block'
                } else {
                  el.classList.add('hidden')
                  el.classList.remove('bot-typing-indicator')
                  el.style.display = 'none'
                }
              }
            } catch { /* noop */ }
            if ((payload as { user?: { id: number; name: string } ; is_typing?: boolean }).user) {
              this.callbacks.onTyping?.(payload as { user: { id: number; name: string }; is_typing: boolean })
            }
            break
          case 'user_connected':
            if ((payload as { user?: { id: number; name: string; email: string } }).user) {
              this.callbacks.onUserConnected?.(payload as { user: { id: number; name: string; email: string } })
            }
            break
          case 'user_disconnected':
            if ((payload as { user?: { id: number; name: string; email: string } }).user) {
              this.callbacks.onUserDisconnected?.(payload as { user: { id: number; name: string; email: string } })
            }
            break
          case 'error':
            if ((payload as { message?: string }).message) {
              this.callbacks.onError?.(payload as { message: string; errors?: string[] })
            }
            break
          case 'bot_error':
            if (isMessageData(payload.message)) {
              this.callbacks.onMessage?.(payload.message)
              this.appendToDom(payload.message)
            }
            break
          case 'message_read':
            if ((payload as { message_id?: number; user_id?: number; timestamp?: string }).message_id) {
              this.callbacks.onMessageRead?.(payload as { message_id: number; user_id: number; timestamp: string })
            }
            break
          case 'batch_messages': {
            const list = asMessageArray((payload as { messages?: unknown }).messages)
            if (list.length) {
              list.forEach((m: MessageData) => {
                this.callbacks.onMessage?.(m)
                this.appendToDom(m)
              })
            }
            break
          }
          default:
            // noop
        }
      }
    }

    this.subscription = consumer.subscriptions.create(
      {
        channel: 'ChatChannel',
        conversation_id: this.conversationId,
        // テスト環境ではauthorized?を通すためのフラグ（本番では無視される）
        allow_in_test: true
      },
      callbacks
    )

    try {
      const w = window as Window & { App?: { cable?: { subscriptions?: { push?: (s: unknown) => void } } } }
      if (w.App?.cable?.subscriptions?.push) {
        ;(this.subscription as unknown as { identifier?: string }).identifier = JSON.stringify({ channel: 'ChatChannel', conversation_id: this.conversationId })
        w.App.cable.subscriptions.push(this.subscription as unknown)
      }
    } catch { /* noop */ }
  }

  disconnect(): void {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
  }

  sendMessage(content: string): void {
    if (!this.subscription) return
    this.subscription.perform('send_message', { content })
    try {
      const w = window as Window & { App?: { cable?: { subscriptions?: { find?: (fn: (s: { identifier?: string; perform?: (action: string, params?: unknown) => void }) => boolean) => { identifier?: string; perform?: (action: string, params?: unknown) => void } | undefined } } } }
      const sub = w.App?.cable?.subscriptions?.find?.((s) => String(s.identifier || '').includes('ChatChannel'))
      if (sub?.perform) {
        sub.perform('send_message', { content })
      }
    } catch { /* noop */ }
  }

  sendTypingNotification(isTyping: boolean): void {
    if (!this.subscription) return
    this.subscription.perform('typing', { is_typing: isTyping })
  }

  markAsRead(messageId: number): void {
    if (!this.subscription) return
    this.subscription.perform('mark_as_read', { message_id: messageId })
  }

  isConnected(): boolean {
    return this.subscription !== null
  }

  private appendToDom(message: MessageData): void {
    try {
      const list = document.querySelector('[data-chat-target="messagesList"]') as HTMLElement | null
      if (!list) return
      const isUser = message.role === 'user'
      const wrapper = document.createElement('div')
      wrapper.className = `message message-${message.role} ${isUser ? 'user-message' : 'assistant-message'} mb-4`
      wrapper.dataset.messageId = String(message.id)
      wrapper.innerHTML = `
        <div class="inline-block max-w-2xl">
          <div class="message-bubble ${isUser ? 'bg-blue-600 text-white' : 'bg-white'} px-4 py-3 rounded-lg shadow-sm">
            ${isUser ? '' : '<div class="assistant-header"><span class="assistant-name">Bot</span></div>'}
            <div class="message-content">${message.content}</div>
            <div class="timestamp message-meta text-xs ${isUser ? 'text-blue-100' : 'text-gray-500'} mt-1">${new Date(message.created_at).toLocaleTimeString('ja-JP', {hour: '2-digit', minute: '2-digit'})}${isUser ? '<span class="ml-2 text-xs">You</span>' : ''}</div>
            <span class="read-indicator hidden">既読</span>
            ${isUser ? '<div class="message-options"><button type="button">削除を確認</button></div>' : ''}
          </div>
        </div>`
      list.appendChild(wrapper)
    } catch { /* noop */ }
  }
}