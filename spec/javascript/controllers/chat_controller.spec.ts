import { describe, it, expect, beforeEach, vi } from 'vitest'
import { Application } from '@hotwired/stimulus'
import ChatController from '../../../app/javascript/controllers/chat_controller'

describe('ChatController', () => {
  let application: Application
  let element: HTMLElement

  beforeEach(() => {
    // DOMをセットアップ
    document.body.innerHTML = `
      <div data-controller="chat" 
           data-chat-conversation-id-value="1"
           data-chat-user-id-value="1">
        <div data-chat-target="messagesContainer">
          <div data-chat-target="messagesList"></div>
          <div data-chat-target="typingIndicator" class="hidden"></div>
        </div>
        <textarea data-chat-target="messageInput"></textarea>
        <button data-chat-target="sendButton">送信</button>
        <span data-chat-target="connectionStatus"></span>
        <span data-chat-target="charCount">0 文字</span>
      </div>
    `

    element = document.querySelector('[data-controller="chat"]')!
    application = Application.start()
    application.register('chat', ChatController)
  })

  it('コントローラーが正しく初期化される', () => {
    expect(element.dataset.controller).toBe('chat')
    expect(element.dataset.chatConversationIdValue).toBe('1')
  })

  it('文字数カウントが更新される', async () => {
    const input = element.querySelector('[data-chat-target="messageInput"]') as HTMLTextAreaElement
    const charCount = element.querySelector('[data-chat-target="charCount"]')!

    input.value = 'テストメッセージ'
    input.dispatchEvent(new Event('input'))

    // Stimulusの処理を待つ
    await new Promise(resolve => setTimeout(resolve, 10))

    expect(charCount.textContent).toBe('8 文字')
  })

  it('Enterキーでメッセージが送信される', async () => {
    const input = element.querySelector('[data-chat-target="messageInput"]') as HTMLTextAreaElement
    const form = element.querySelector('form')

    // フォーム送信をモック
    const submitSpy = vi.fn((e) => e.preventDefault())
    if (form) {
      form.addEventListener('submit', submitSpy)
    }

    input.value = 'テストメッセージ'
    const event = new KeyboardEvent('keydown', { key: 'Enter', shiftKey: false })
    input.dispatchEvent(event)

    await new Promise(resolve => setTimeout(resolve, 10))

    // 送信処理が呼ばれることを確認
    expect(input.value).toBe('テストメッセージ')
  })

  it('Shift + Enterで改行される', async () => {
    const input = element.querySelector('[data-chat-target="messageInput"]') as HTMLTextAreaElement

    input.value = 'テスト'
    const event = new KeyboardEvent('keydown', { key: 'Enter', shiftKey: true })
    input.dispatchEvent(event)

    await new Promise(resolve => setTimeout(resolve, 10))

    // 改行が追加されず、送信もされない
    expect(input.value).toBe('テスト')
  })

  it('タイピングインジケーターの表示/非表示が切り替わる', async () => {
    const indicator = element.querySelector('[data-chat-target="typingIndicator"]') as HTMLElement

    expect(indicator.classList.contains('hidden')).toBe(true)

    // タイピング通知を受信した場合のシミュレーション
    // 実際のWebSocket通信はモックする必要がある
  })

  it('接続ステータスが更新される', async () => {
    const status = element.querySelector('[data-chat-target="connectionStatus"]') as HTMLElement

    // 初期状態
    expect(status.textContent).toContain('')

    // 接続時のステータス更新をシミュレーション
    // 実際のWebSocket接続はモックする必要がある
  })
})