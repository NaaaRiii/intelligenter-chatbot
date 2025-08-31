interface LastActiveConversation {
  conversationId: string;
  timestamp: string;
  messageCount: number;
}

class SessionManager {
  private static instance: SessionManager;
  private userId: string | null = null;
  private tabSessionId: string | null = null;

  private constructor() {}

  static getInstance(): SessionManager {
    if (!SessionManager.instance) {
      SessionManager.instance = new SessionManager();
    }
    return SessionManager.instance;
  }

  /**
   * ユーザーIDを取得（なければ生成）
   * 全タブで共有、30日間保持
   */
  getUserId(): string {
    // メモリにキャッシュがあればそれを返す
    if (this.userId) {
      return this.userId;
    }

    // Cookieから取得
    const existingId = this.getCookie('user_id');
    if (existingId && existingId.trim() !== '') {
      this.userId = existingId;
      return existingId;
    }

    // 新規生成
    this.userId = this.generateUUID();
    this.setCookie('user_id', this.userId, 30); // 30日間有効
    return this.userId;
  }

  /**
   * タブセッションIDを取得（なければ生成）
   * タブごとに独立、タブを閉じると削除
   */
  getTabSessionId(): string {
    // メモリにキャッシュがあればそれを返す
    if (this.tabSessionId) {
      return this.tabSessionId;
    }

    // sessionStorageから取得
    const existingId = sessionStorage.getItem('tab_session_id');
    if (existingId && existingId.trim() !== '') {
      this.tabSessionId = existingId;
      return existingId;
    }

    // 新規生成
    this.tabSessionId = this.generateUUID();
    sessionStorage.setItem('tab_session_id', this.tabSessionId);
    return this.tabSessionId;
  }

  /**
   * セッションIDを取得（互換性のため残す）
   * タブセッションIDを返す
   */
  getSessionId(): string {
    return this.getTabSessionId();
  }

  /**
   * 現在の会話IDを取得
   */
  getCurrentConversationId(): string | null {
    return localStorage.getItem('current_conversation_id');
  }

  /**
   * 現在の会話IDを設定
   */
  setCurrentConversationId(conversationId: string): void {
    localStorage.setItem('current_conversation_id', conversationId);
    
    // 最終アクティブ情報も更新
    this.setLastActiveConversation({
      conversationId,
      timestamp: new Date().toISOString(),
      messageCount: 0 // 実際のメッセージ数は呼び出し側で設定
    });
  }

  /**
   * 現在の会話IDをクリア
   */
  clearCurrentConversationId(): void {
    localStorage.removeItem('current_conversation_id');
  }

  /**
   * 最後のアクティブな会話情報を取得
   */
  getLastActiveConversation(): LastActiveConversation | null {
    const stored = localStorage.getItem('last_active_conversation');
    if (!stored) return null;

    try {
      const data = JSON.parse(stored) as LastActiveConversation;
      
      // 30日以上古い場合は無効
      const timestamp = new Date(data.timestamp);
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      
      if (timestamp < thirtyDaysAgo) {
        localStorage.removeItem('last_active_conversation');
        return null;
      }
      
      return data;
    } catch {
      return null;
    }
  }

  /**
   * 最後のアクティブな会話情報を設定
   */
  setLastActiveConversation(data: LastActiveConversation): void {
    localStorage.setItem('last_active_conversation', JSON.stringify(data));
  }

  /**
   * セッション情報をクリア（セッションID以外）
   */
  clearSession(): void {
    this.clearCurrentConversationId();
    localStorage.removeItem('last_active_conversation');
    // セッションIDは維持（ユーザー識別のため）
  }

  /**
   * 有効なセッションかチェック
   */
  hasValidSession(): boolean {
    const sessionId = this.getCookie('session_id');
    const conversationId = this.getCurrentConversationId();
    return !!(sessionId && conversationId);
  }

  /**
   * Cookieを設定
   */
  setCookie(name: string, value: string, days: number): void {
    const maxAge = days * 24 * 60 * 60; // 秒数に変換
    document.cookie = `${name}=${value}; path=/; max-age=${maxAge}; SameSite=Lax`;
  }

  /**
   * Cookieを取得
   */
  getCookie(name: string): string | null {
    const nameEQ = name + "=";
    const cookies = document.cookie.split(';');
    
    for (let cookie of cookies) {
      cookie = cookie.trim();
      if (cookie.indexOf(nameEQ) === 0) {
        return cookie.substring(nameEQ.length);
      }
    }
    
    return null;
  }

  /**
   * Cookieを削除
   */
  deleteCookie(name: string): void {
    document.cookie = `${name}=; path=/; max-age=0`;
  }

  /**
   * UUID生成
   */
  private generateUUID(): string {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }
}

// シングルトンインスタンスをエクスポート
export default SessionManager.getInstance();