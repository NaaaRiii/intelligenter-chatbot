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

      received: (data: any) => {
        switch (data.type) {
          case 'new_message':
            this.callbacks.onMessage?.(data.message)
            this.appendToDom(data.message)
            break
          case 'typing':
            this.callbacks.onTyping?.(data)
            break
          case 'user_connected':
            this.callbacks.onUserConnected?.(data)
            break
          case 'user_disconnected':
            this.callbacks.onUserDisconnected?.(data)
            break
          case 'error':
            this.callbacks.onError?.(data)
            break
          case 'bot_error':
            if (data.message) {
              this.callbacks.onMessage?.(data.message)
              this.appendToDom(data.message)
            }
            break
          case 'message_read':
            this.callbacks.onMessageRead?.(data)
            break
          case 'batch_messages':
            if (Array.isArray(data.messages)) {
              data.messages.forEach((m: MessageData) => {
                this.callbacks.onMessage?.(m)
                this.appendToDom(m)
              })
            }
            break
          default:
            // noop
        }
      }
    }

    this.subscription = consumer.subscriptions.create(
      {
        channel: 'ChatChannel',
        conversation_id: this.conversationId
      },
      callbacks
    )

    try {
      const w = window as any
      if (w.App && w.App.cable && w.App.cable.subscriptions && typeof w.App.cable.subscriptions.push === 'function') {
        ;(this.subscription as any).identifier = JSON.stringify({ channel: 'ChatChannel', conversation_id: this.conversationId })
        w.App.cable.subscriptions.push(this.subscription)
      }
    } catch (e) {
      // noop
    }
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
    } catch (_) {}
  }
}

// 使用例は省略（アプリ本体で利用）

function createMessageElement(message: MessageData): HTMLElement {
  const messageDiv = document.createElement('div')
  messageDiv.className = `message message-${message.role} ${message.role === 'user' ? 'user-message' : 'assistant-message'} mb-4`
  messageDiv.dataset.messageId = message.id.toString()
  
  const contentDiv = document.createElement('div')
  contentDiv.className = message.role === 'user' 
    ? 'chat-bubble chat-bubble-user' 
    : 'chat-bubble chat-bubble-assistant'
  contentDiv.textContent = message.content
  
  const metaDiv = document.createElement('div')
  metaDiv.className = 'timestamp text-xs text-gray-500 mt-1'
  metaDiv.textContent = new Date(message.created_at).toLocaleString('ja-JP')

  const readIndicator = document.createElement('span')
  readIndicator.className = 'read-indicator hidden'

  const optionsDiv = document.createElement('div')
  optionsDiv.className = 'message-options'
  const deleteBtn = document.createElement('button')
  deleteBtn.type = 'button'
  deleteBtn.textContent = '削除'
  deleteBtn.addEventListener('click', () => {
    messageDiv.remove()
  })
  optionsDiv.appendChild(deleteBtn)
  
  messageDiv.appendChild(contentDiv)
  messageDiv.appendChild(metaDiv)
  messageDiv.appendChild(readIndicator)
  messageDiv.appendChild(optionsDiv)
  
  return messageDiv
}

function showErrorNotification(message: string): void {
  const notification = document.createElement('div')
  notification.className = 'fixed top-4 right-4 bg-red-500 text-white px-4 py-2 rounded shadow-lg'
  notification.textContent = message
  
  document.body.appendChild(notification)
  
  setTimeout(() => {
    notification.remove()
  }, 5000)
}