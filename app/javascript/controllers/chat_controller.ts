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

  // ターゲット要素の型定義
  declare readonly messageInputTarget: HTMLTextAreaElement
  declare readonly sendButtonTarget: HTMLButtonElement
  declare readonly messagesListTarget: HTMLElement
  declare readonly messagesContainerTarget: HTMLElement
  declare readonly typingIndicatorTarget: HTMLElement
  declare readonly connectionStatusTarget: HTMLElement
  declare readonly charCountTarget: HTMLElement
  declare readonly hasTypingIndicatorTarget: boolean

  // 値の型定義
  declare conversationIdValue: string
  declare userIdValue: string

  private chatChannel: ChatChannel | null = null
  private typingTimer: number | null = null
  private isTyping = false

  connect(): void {
    console.log('Chat controller connected')
    this.initializeWebSocket()
    this.scrollToBottom()
    this.updateCharCount()
  }

  disconnect(): void {
    if (this.chatChannel) {
      this.chatChannel.disconnect()
    }
    if (this.typingTimer) {
      clearTimeout(this.typingTimer)
    }
  }

  // WebSocket接続を初期化
  private initializeWebSocket(): void {
    if (!this.conversationIdValue) {
      console.error('Conversation ID is required')
      return
    }

    const conversationId = parseInt(this.conversationIdValue, 10)
    this.chatChannel = new ChatChannel(
      conversationId,
      {
        onConnected: () => this.handleConnected(),
        onDisconnected: () => this.handleDisconnected(),
        onMessage: (message) => this.handleNewMessage(message),
        onTyping: (data) => this.handleTypingNotification(data),
        onMessageRead: (data) => this.handleMessageRead(data),
        onError: (data) => this.handleError(data)
      }
    )

    this.chatChannel.connect()
  }

  // メッセージ送信
  sendMessage(event: Event): void {
    event.preventDefault()

    const content = this.messageInputTarget.value.trim()
    if (!content) return

    // UIを更新
    this.messageInputTarget.value = ''
    this.updateCharCount()
    this.sendButtonTarget.disabled = true

    // WebSocket経由で送信
    if (this.chatChannel) {
      this.chatChannel.sendMessage(content)
    }

    // 送信後にスクロール
    setTimeout(() => this.scrollToBottom(), 100)
  }

  // キーボードイベント処理
  handleKeydown(event: KeyboardEvent): void {
    // Shift + Enter で改行、Enter のみで送信
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      this.sendMessage(event)
    }
  }

  // タイピング通知を送信
  handleTyping(): void {
    this.updateCharCount()

    if (!this.isTyping && this.messageInputTarget.value.trim()) {
      this.isTyping = true
      if (this.chatChannel) {
        this.chatChannel.sendTypingNotification(true)
      }
    }

    // タイピング停止タイマーをリセット
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

  // 文字数カウント更新
  private updateCharCount(): void {
    const count = this.messageInputTarget.value.length
    this.charCountTarget.textContent = `${count} 文字`
  }

  // WebSocket接続成功
  private handleConnected(): void {
    console.log('WebSocket connected')
    this.updateConnectionStatus(true)
    this.sendButtonTarget.disabled = false
  }

  // WebSocket接続切断
  private handleDisconnected(): void {
    console.log('WebSocket disconnected')
    this.updateConnectionStatus(false)
    this.sendButtonTarget.disabled = true
  }

  // 新しいメッセージを受信
  private handleNewMessage(message: Message): void {
    this.appendMessage(message)
    this.scrollToBottom()
    this.sendButtonTarget.disabled = false
  }

  // タイピング通知を受信
  private handleTypingNotification(_data: any): void {
    this.showTypingIndicator()
    setTimeout(() => {
      this.hideTypingIndicator()
    }, 3000)
  }

  // 既読通知を受信
  private handleMessageRead(data: any): void {
    try {
      const el = this.element.querySelector(`[data-message-id="${data.message_id}"] .read-indicator`) as HTMLElement | null
      if (el) {
        el.classList.remove('hidden')
      }
    } catch (e) {
      // noop
    }
  }

  // メッセージをDOMに追加
  private appendMessage(message: Message): void {
    const isUser = message.role === 'user'
    const youLabel = isUser ? '<span class="ml-2 text-xs">You</span>' : ''
    const messageHtml = `
      <div class="message message-${message.role} ${isUser ? 'user-message' : 'assistant-message'} mb-4" data-message-id="${message.id}">
        <div class="inline-block max-w-2xl">
          <div class="message-bubble ${isUser ? 'bg-blue-600 text-white' : 'bg-white'} px-4 py-3 rounded-lg shadow-sm">
            <div class="message-content">
              ${this.escapeHtml(message.content).replace(/\n/g, '<br>')}
            </div>
            <div class="timestamp message-meta text-xs ${isUser ? 'text-blue-100' : 'text-gray-500'} mt-1">
              ${new Date(message.created_at).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}
              ${youLabel}
            </div>
            <span class="read-indicator hidden">既読</span>
            ${isUser ? '<div class="message-options"><button type="button" data-action="click->chat#deleteMessage">削除</button></div>' : ''}
          </div>
        </div>
      </div>
    `

    // タイピングインジケーターの前に挿入
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.insertAdjacentHTML('beforebegin', messageHtml)
    } else {
      this.messagesListTarget.insertAdjacentHTML('beforeend', messageHtml)
    }
  }

  deleteMessage(event: Event): void {
    const btn = event.currentTarget as HTMLElement
    const wrapper = btn.closest('.message') as HTMLElement | null
    if (wrapper) wrapper.remove()
  }

  // タイピングインジケーターを表示
  private showTypingIndicator(): void {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.classList.remove('hidden')
      this.typingIndicatorTarget.classList.add('bot-typing-indicator')
    }
  }

  // タイピングインジケーターを非表示
  private hideTypingIndicator(): void {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.classList.add('hidden')
    }
  }

  // 接続状態を更新
  private updateConnectionStatus(connected: boolean): void {
    if (connected) {
      this.connectionStatusTarget.innerHTML = `
        <span class="inline-block w-2 h-2 bg-green-400 rounded-full animate-pulse"></span>
        <span class="ml-1 text-sm">接続済み</span>
      `
    } else {
      this.connectionStatusTarget.innerHTML = `
        <span class="inline-block w-2 h-2 bg-red-400 rounded-full"></span>
        <span class="ml-1 text-sm">切断中</span>
      `
    }
  }

  // 最下部にスクロール
  private scrollToBottom(): void {
    this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
  }

  // HTMLエスケープ
  private escapeHtml(text: string): string {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  // エラーハンドリング
  private handleError(data: any): void {
    console.error('Chat error:', data)
    const errorMessage = data.message || 'エラーが発生しました'
    
    // エラーメッセージを表示
    const errorDiv = document.createElement('div')
    errorDiv.className = 'fixed top-4 right-4 bg-red-500 text-white px-4 py-2 rounded shadow-lg z-50'
    errorDiv.textContent = errorMessage
    document.body.appendChild(errorDiv)
    
    setTimeout(() => {
      errorDiv.remove()
    }, 5000)
  }
}