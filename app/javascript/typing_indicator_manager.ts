// TypingIndicatorManager
// チャット画面でアシスタントメッセージがDOMに追加されたら、
// タイピングインジケーターを確実に非表示（必要なら削除）にするユーティリティ

function hideTypingIndicator(): void {
  try {
    const el = document.getElementById('typing-indicator') as HTMLElement | null
    if (!el) return
    el.classList.add('hidden')
    try { el.classList.remove('bot-typing-indicator') } catch { /* noop */ }
    el.style.display = 'none'
  } catch { /* noop */ }
}

function nodeListIncludesAssistantMessage(nodes: NodeList): boolean {
  try {
    for (const n of Array.from(nodes)) {
      if (!(n instanceof HTMLElement)) continue
      if (n.classList.contains('assistant-message')) return true
      // 子孫も確認
      if (n.querySelector && n.querySelector('.assistant-message')) return true
    }
  } catch { /* noop */ }
  return false
}

export function initTypingIndicatorManager(): void {
  try {
    const chatContainer = document.getElementById('chat-container')
    if (!chatContainer) return

    // 初期状態のクリーンアップ（念のため）
    hideTypingIndicator()

    // メッセージリストを監視し、assistant-message の追加を検知
    const list = chatContainer.querySelector('[data-chat-target="messagesList"]') as HTMLElement | null
    if (!list) return

    const observer = new MutationObserver((mutations) => {
      for (const m of mutations) {
        if (m.type === 'childList' && (m.addedNodes?.length || 0) > 0) {
          if (nodeListIncludesAssistantMessage(m.addedNodes)) {
            hideTypingIndicator()
          }
        }
      }
    })

    observer.observe(list, { childList: true, subtree: true })

    // 送信時の確実な表示（Stimulusが未初期化の場合のフォールバック）
    try {
      const form = document.getElementById('message-form') as HTMLFormElement | null
      if (form) {
        form.addEventListener('submit', () => {
          try {
            const el = document.getElementById('typing-indicator') as HTMLElement | null
            if (el) {
              el.classList.remove('hidden')
              el.classList.add('bot-typing-indicator')
              el.style.display = 'block'
            }
          } catch { /* noop */ }
        }, { capture: true })
      }
    } catch { /* noop */ }

    // 定期的な強制非表示は行わない（テストでの一時表示を阻害しない）
  } catch { /* noop */ }
}

// 自動初期化（DOMが読めた時点で）
try {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => initTypingIndicatorManager())
  } else {
    initTypingIndicatorManager()
  }
} catch { /* noop */ }


