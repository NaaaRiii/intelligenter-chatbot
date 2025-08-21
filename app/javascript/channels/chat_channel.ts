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

    this.subscription = consumer.subscriptions.create(
      {
        channel: 'ChatChannel',
        conversation_id: this.conversationId
      },
      {
        connected: () => {
          console.log(`Connected to ChatChannel for conversation ${this.conversationId}`)
          this.callbacks.onConnected?.()
        },

        disconnected: () => {
          console.log(`Disconnected from ChatChannel for conversation ${this.conversationId}`)
          this.callbacks.onDisconnected?.()
        },

        received: (data: any) => {
          console.log('Received data:', data)
          
          switch (data.type) {
            case 'new_message':
              this.callbacks.onMessage?.(data.message)
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
            case 'message_read':
              this.callbacks.onMessageRead?.(data)
              break
            default:
              console.warn('Unknown message type:', data.type)
          }
        }
      }
    )
  }

  disconnect(): void {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
  }

  sendMessage(content: string): void {
    if (!this.subscription) {
      console.error('Not connected to chat channel')
      return
    }

    this.subscription.perform('send_message', { content })
  }

  sendTypingNotification(isTyping: boolean): void {
    if (!this.subscription) {
      return
    }

    this.subscription.perform('typing', { is_typing: isTyping })
  }

  markAsRead(messageId: number): void {
    if (!this.subscription) {
      return
    }

    this.subscription.perform('mark_as_read', { message_id: messageId })
  }

  isConnected(): boolean {
    return this.subscription !== null
  }
}

// 使用例
export function setupChatChannel(
  conversationId: number,
  messageContainer: HTMLElement
): ChatChannel {
  const channel = new ChatChannel(conversationId, {
    onConnected: () => {
      const statusElement = document.getElementById('connection-status')
      if (statusElement) {
        statusElement.textContent = '接続済み'
        statusElement.classList.add('text-green-500')
        statusElement.classList.remove('text-red-500')
      }
    },
    
    onDisconnected: () => {
      const statusElement = document.getElementById('connection-status')
      if (statusElement) {
        statusElement.textContent = '切断'
        statusElement.classList.add('text-red-500')
        statusElement.classList.remove('text-green-500')
      }
    },
    
    onMessage: (message) => {
      const messageElement = createMessageElement(message)
      messageContainer.appendChild(messageElement)
      messageContainer.scrollTop = messageContainer.scrollHeight
    },
    
    onTyping: (data) => {
      const typingIndicator = document.getElementById('typing-indicator')
      if (typingIndicator) {
        if (data.is_typing) {
          typingIndicator.textContent = `${data.user.name}が入力中...`
          typingIndicator.classList.remove('hidden')
        } else {
          typingIndicator.classList.add('hidden')
        }
      }
    },
    
    onError: (data) => {
      console.error('Chat error:', data.message)
      showErrorNotification(data.message)
    }
  })

  channel.connect()
  return channel
}

function createMessageElement(message: MessageData): HTMLElement {
  const messageDiv = document.createElement('div')
  messageDiv.className = `message message-${message.role} mb-4`
  messageDiv.dataset.messageId = message.id.toString()
  
  const contentDiv = document.createElement('div')
  contentDiv.className = message.role === 'user' 
    ? 'chat-bubble chat-bubble-user' 
    : 'chat-bubble chat-bubble-assistant'
  contentDiv.textContent = message.content
  
  const metaDiv = document.createElement('div')
  metaDiv.className = 'text-xs text-gray-500 mt-1'
  metaDiv.textContent = new Date(message.created_at).toLocaleString('ja-JP')
  
  messageDiv.appendChild(contentDiv)
  messageDiv.appendChild(metaDiv)
  
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