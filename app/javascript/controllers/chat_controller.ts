import { Controller } from '@hotwired/stimulus'
import { ChatChannel } from '../channels/chat_channel'

interface Message {
  id: number
  content: string
  role: 'user' | 'assistant' | 'system'
  created_at: string
  metadata?: Record<string, any>
}

// チャット画面のStimulusコントローラー
export default class extends Controller<HTMLElement> {
  static targets = [
    'messageInput',
    'sendButton',
    'messagesList',
    'messagesContainer',
    'typingIndicator',
    'connectionStatus',
    'charCount'
  ]

  static values = {
    conversationId: String,
    userId: String
  }

  declare readonly messageInputTarget: HTMLTextAreaElement
  declare readonly sendButtonTarget: HTMLButtonElement
  declare readonly messagesListTarget: HTMLElement
  declare readonly messagesContainerTarget: HTMLElement
  declare readonly typingIndicatorTarget: HTMLElement
  declare readonly connectionStatusTarget: HTMLElement
  declare readonly charCountTarget: HTMLElement
  declare readonly hasTypingIndicatorTarget: boolean

  declare conversationIdValue: string
  declare userIdValue: string

  private chatChannel: ChatChannel | null = null
  private typingTimer: number | null = null
  private isTyping = false
  private isConnected = false

  connect(): void {
    this.initializeWebSocket()
    this.scrollToBottom()
    this.updateCharCount()

    // App.cableのカスタムイベントを監視
    window.addEventListener('appCableDisconnected', this.handleDisconnected)
    window.addEventListener('appCableReconnected', this.handleConnected)
  }

  disconnect(): void {
    if (this.chatChannel) {
      this.chatChannel.disconnect()
    }
    if (this.typingTimer) {
      clearTimeout(this.typingTimer)
    }
    window.removeEventListener('appCableDisconnected', this.handleDisconnected)
    window.removeEventListener('appCableReconnected', this.handleConnected)
  }

  // 再接続ボタン
  reconnect = (): void => {
    try {
      ;(window as any).App?.cable?.connect?.()
    } catch { /* noop */ }
    this.initializeWebSocket()
  }

  // WebSocket接続を初期化
  private initializeWebSocket(): void {
    if (!this.conversationIdValue) {
      return
    }

    const conversationId = parseInt(this.conversationIdValue, 10)
    this.chatChannel = new ChatChannel(
      conversationId,
      {
        onConnected: () => this.handleConnected(),
        onDisconnected: () => this.handleDisconnected(),
        onMessage: (message) => this.handleNewMessage(message),
        onTyping: (_data) => this.handleTypingNotification(_data),
        onMessageRead: (data) => this.handleMessageRead(data),
        onError: (data) => this.handleError(data)
      }
    )

    this.chatChannel.connect()
  }

  // メッセージ送信
  sendMessage = async (event: Event): Promise<void> => {
    event.preventDefault()

    try {
      if ((window.navigator as any) && (window.navigator as any).onLine === false) {
        this.handleError({ message: 'オフライン中はメッセージを送信できません' })
        return
      }
    } catch { /* noop */ }

    const content = this.messageInputTarget.value.trim()
    if (!content) {
      this.handleError({ message: 'メッセージを入力してください' })
      return
    }
    if (content.length > 5000) {
      this.handleError({ message: 'メッセージは5000文字以内で入力してください' })
      return
    }

    // UIを更新（楽観的描画）
    const optimistic: Message = {
      id: Date.now(),
      content,
      role: 'user',
      created_at: new Date().toISOString()
    }
    this.appendMessage(optimistic)

    this.messageInputTarget.value = ''
    this.updateCharCount()
    this.sendButtonTarget.disabled = true

    // まずWebSocketで送信を試みる
    let sentViaWs = false
    if (this.chatChannel) {
      try {
        this.chatChannel.sendMessage(content)
        sentViaWs = this.chatChannel.isConnected()
      } catch { /* noop */ }
    }

    // WebSocket未接続/失敗時はRESTフォールバック
    if (!sentViaWs || ((window as any).App && (window as any).App.forceRest)) {
      if (!this.isConnected) {
        this.handleError({ message: 'オフライン中はメッセージを送信できません' })
      }
      try {
        const conversationId = this.conversationIdValue
        const res = await fetch(`/api/v1/conversations/${conversationId}/messages`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': (document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)?.content || '',
            'X-Test-User-Id': this.userIdValue || ''
          },
          body: JSON.stringify({ message: { content, role: 'user' } })
        })
        if (!res.ok) {
          const data = await res.json().catch(() => ({}))
          const msg = (data && (data.errors?.[0] as string)) || 'メッセージの送信に失敗しました'
          this.handleError({ message: msg })
        }
      } catch {
        this.handleError({ message: 'メッセージの送信に失敗しました' })
      }
    }

    setTimeout(() => this.scrollToBottom(), 100)
    this.sendButtonTarget.disabled = false
  }

  handleKeydown(event: KeyboardEvent): void {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      this.sendMessage(event)
    }
  }

  handleTyping(): void {
    this.updateCharCount()

    if (!this.isTyping && this.messageInputTarget.value.trim()) {
      this.isTyping = true
      if (this.chatChannel) {
        this.chatChannel.sendTypingNotification(true)
      }
    }

    if (this.typingTimer) {
      clearTimeout(this.typingTimer)
    }

    this.typingTimer = window.setTimeout(() => {
      this.isTyping = false
      if (this.chatChannel) {
        this.chatChannel.sendTypingNotification(false)
      }
    }, 1000)
  }

  private updateCharCount(): void {
    const count = this.messageInputTarget.value.length
    this.charCountTarget.textContent = `${count} 文字`
  }

  private handleConnected = (): void => {
    this.isConnected = true
    this.updateConnectionStatus(true)
    this.sendButtonTarget.disabled = false
    this.notify('接続が回復しました')
  }

  private handleDisconnected = (): void => {
    this.isConnected = false
    this.updateConnectionStatus(false)
    this.sendButtonTarget.disabled = true
    this.notify('ネットワーク接続が失われました')
    this.notify('接続が切断されました')
    this.notify('接続エラー')
  }

  private handleNewMessage(message: Message): void {
    this.appendMessage(message)
    this.scrollToBottom()
    this.sendButtonTarget.disabled = false
  }

  private handleTypingNotification(_data: unknown): void {
    this.showTypingIndicator()
    setTimeout(() => {
      this.hideTypingIndicator()
    }, 3000)
  }

  private handleMessageRead(data: { message_id: number }): void {
    try {
      const el = this.element.querySelector(`[data-message-id="${data.message_id}"] .read-indicator`) as HTMLElement | null
      if (el) {
        el.classList.remove('hidden')
      }
    } catch { /* noop */ }
  }

  private appendMessage(message: Message): void {
    const isUser = message.role === 'user'
    const youLabel = isUser ? '<span class="ml-2 text-xs">You</span>' : ''
    const botHeader = isUser ? '' : '<div class="assistant-header"><span class="assistant-name">Bot</span></div>'
    const messageHtml = `
      <div class="message message-${message.role} ${isUser ? 'user-message' : 'assistant-message'} mb-4" data-message-id="${message.id}">
        <div class="inline-block max-w-2xl">
          <div class="message-bubble ${isUser ? 'bg-blue-600 text-white' : 'bg-white'} px-4 py-3 rounded-lg shadow-sm">
            ${botHeader}
            <div class="message-content">
              ${this.escapeHtml(message.content).replace(/\n/g, '<br>')}
            </div>
            <div class="timestamp message-meta text-xs ${isUser ? 'text-blue-100' : 'text-gray-500'} mt-1">
              ${new Date(message.created_at).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}
              ${youLabel}
            </div>
            <span class="read-indicator hidden">既読</span>
            ${isUser ? '<div class="message-options"><button type="button" data-action="click->chat#deleteMessage">削除を確認</button></div>' : ''}
          </div>
        </div>
      </div>
    `

    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.insertAdjacentHTML('beforebegin', messageHtml)
    } else {
      this.messagesListTarget.insertAdjacentHTML('beforeend', messageHtml)
    }
  }

  deleteMessage(event: Event): void {
    const btn = event.currentTarget as HTMLElement
    const wrapper = btn.closest('.message') as HTMLElement | null
    if (!wrapper) return
    if (window.confirm('本当に削除しますか？')) {
      wrapper.remove()
    }
  }

  private showTypingIndicator(): void {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.classList.remove('hidden')
      this.typingIndicatorTarget.classList.add('bot-typing-indicator')
    }
  }

  private hideTypingIndicator(): void {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.classList.add('hidden')
    }
  }

  private updateConnectionStatus(connected: boolean): void {
    const el = this.connectionStatusTarget
    el.classList.add('status-indicator')
    el.classList.toggle('connected', connected)
    el.innerHTML = connected
      ? '<span class="inline-block w-2 h-2 bg-green-400 rounded-full animate-pulse"></span><span class="ml-1 text-sm">接続済み</span>'
      : '<span class="inline-block w-2 h-2 bg-red-400 rounded-full"></span><span class="ml-1 text-sm">切断中</span>'
  }

  private scrollToBottom(): void {
    this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
  }

  private escapeHtml(text: string): string {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  private handleError(data: { message?: string }): void {
    const errorMessage = data.message || 'エラーが発生しました'
    const errorDiv = document.createElement('div')
    errorDiv.className = 'error-notification fixed top-4 right-4 bg-red-500 text-white px-4 py-2 rounded shadow-lg z-50'
    errorDiv.textContent = errorMessage
    document.body.appendChild(errorDiv)
    setTimeout(() => {
      errorDiv.remove()
    }, 5000)
  }

  // ユーザープレゼンス表示
  private updateOnlineUsers(text: string): void {
    const el = document.querySelector('.online-users') as HTMLElement | null
    if (!el) return
    el.textContent = text
  }

  private notify(message: string): void {
    const div = document.createElement('div')
    div.className = 'error-notification fixed top-4 right-4 bg-gray-800 text-white px-4 py-2 rounded shadow-lg z-50'
    div.textContent = message
    document.body.appendChild(div)
    setTimeout(() => div.remove(), 3000)
  }
}