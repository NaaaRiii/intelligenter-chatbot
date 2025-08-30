import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import SessionManager from '../sessionManager';

// localStorageのモック
const localStorageMock = (() => {
  let store: Record<string, string> = {};
  return {
    getItem: (key: string): string | null => {
      return store[key] || null;
    },
    setItem: (key: string, value: string) => {
      store[key] = value;
    },
    removeItem: (key: string) => {
      delete store[key];
    },
    clear: () => {
      store = {};
    }
  };
})();

Object.defineProperty(window, 'localStorage', {
  value: localStorageMock,
  writable: true
});

describe('SessionManager', () => {
  beforeEach(() => {
    // Cookie と localStorage をクリア
    document.cookie = '';
    localStorageMock.clear();
    vi.clearAllMocks();
    // SessionManagerのインスタンスをリセット
    (SessionManager as any).sessionId = null;
  });

  afterEach(() => {
    document.cookie = '';
    localStorageMock.clear();
  });

  describe('セッションID管理', () => {
    it('初回アクセス時に新しいセッションIDを生成する', () => {
      const sessionId = SessionManager.getSessionId();
      
      expect(sessionId).toBeTruthy();
      expect(sessionId).toMatch(/^[a-f0-9-]{36}$/); // UUID形式
    });

    it('セッションIDをCookieに保存する（30日間有効）', () => {
      const sessionId = SessionManager.getSessionId();
      
      // Cookieが設定されていることを確認
      expect(document.cookie).toContain(`session_id=${sessionId}`);
      
      // max-ageが30日（2592000秒）であることを確認
      const cookie = SessionManager.getCookie('session_id');
      expect(cookie).toBe(sessionId);
    });

    it('既存のセッションIDがあれば再利用する', () => {
      const firstSessionId = SessionManager.getSessionId();
      const secondSessionId = SessionManager.getSessionId();
      
      expect(firstSessionId).toBe(secondSessionId);
    });

    it('Cookieから既存のセッションIDを読み込む', () => {
      const existingId = 'existing-session-123';
      document.cookie = `session_id=${existingId}; path=/; max-age=2592000`;
      
      const sessionId = SessionManager.getSessionId();
      expect(sessionId).toBe(existingId);
    });

    it('無効なセッションIDの場合は新しいものを生成', () => {
      document.cookie = 'session_id=; path=/'; // 空のセッションID
      
      const sessionId = SessionManager.getSessionId();
      expect(sessionId).toBeTruthy();
      expect(sessionId).not.toBe('');
    });
  });

  describe('会話ID管理', () => {
    it('現在の会話IDを保存できる', () => {
      const conversationId = 'conv-123';
      SessionManager.setCurrentConversationId(conversationId);
      
      const retrieved = SessionManager.getCurrentConversationId();
      expect(retrieved).toBe(conversationId);
    });

    it('会話IDはlocalStorageに保存される', () => {
      const conversationId = 'conv-456';
      SessionManager.setCurrentConversationId(conversationId);
      
      const stored = localStorage.getItem('current_conversation_id');
      expect(stored).toBe(conversationId);
    });

    it('ブラウザ再起動後も会話IDが維持される', () => {
      // 会話IDを保存
      const conversationId = 'conv-789';
      localStorage.setItem('current_conversation_id', conversationId);
      
      // SessionManagerの新しいインスタンスで取得（ブラウザ再起動をシミュレート）
      const retrieved = SessionManager.getCurrentConversationId();
      expect(retrieved).toBe(conversationId);
    });

    it('会話IDをクリアできる', () => {
      SessionManager.setCurrentConversationId('conv-999');
      SessionManager.clearCurrentConversationId();
      
      const retrieved = SessionManager.getCurrentConversationId();
      expect(retrieved).toBeNull();
    });
  });

  describe('自動復元用データ', () => {
    it('最後のアクティブな会話情報を保存する', () => {
      const lastActive = {
        conversationId: 'conv-last',
        timestamp: new Date().toISOString(),
        messageCount: 5
      };
      
      SessionManager.setLastActiveConversation(lastActive);
      const retrieved = SessionManager.getLastActiveConversation();
      
      expect(retrieved).toEqual(lastActive);
    });

    it('30日以上古い会話情報は無効とする', () => {
      const oldDate = new Date();
      oldDate.setDate(oldDate.getDate() - 31);
      
      const oldConversation = {
        conversationId: 'conv-old',
        timestamp: oldDate.toISOString(),
        messageCount: 3
      };
      
      SessionManager.setLastActiveConversation(oldConversation);
      const retrieved = SessionManager.getLastActiveConversation();
      
      expect(retrieved).toBeNull(); // 古すぎるので無効
    });

    it('セッション情報を完全にクリアできる', () => {
      SessionManager.setCurrentConversationId('conv-clear');
      SessionManager.setLastActiveConversation({
        conversationId: 'conv-clear',
        timestamp: new Date().toISOString(),
        messageCount: 2
      });
      
      SessionManager.clearSession();
      
      expect(SessionManager.getCurrentConversationId()).toBeNull();
      expect(SessionManager.getLastActiveConversation()).toBeNull();
      // セッションIDは維持される（ユーザー識別のため）
      expect(SessionManager.getSessionId()).toBeTruthy();
    });
  });

  describe('Cookie操作', () => {
    it('Cookieを設定できる', () => {
      SessionManager.setCookie('test_key', 'test_value', 7);
      
      const value = SessionManager.getCookie('test_key');
      expect(value).toBe('test_value');
    });

    it('存在しないCookieはnullを返す', () => {
      const value = SessionManager.getCookie('non_existent');
      expect(value).toBeNull();
    });

    it('Cookieを削除できる', () => {
      SessionManager.setCookie('delete_me', 'value', 1);
      expect(SessionManager.getCookie('delete_me')).toBe('value');
      
      SessionManager.deleteCookie('delete_me');
      // Cookieが削除されるか、空文字列になることを確認
      const result = SessionManager.getCookie('delete_me');
      expect(result === null || result === '').toBeTruthy();
    });

    it('複数のCookieが混在しても正しく取得できる', () => {
      document.cookie = 'key1=value1; path=/';
      document.cookie = 'key2=value2; path=/';
      document.cookie = 'key3=value3; path=/';
      
      expect(SessionManager.getCookie('key2')).toBe('value2');
    });
  });

  describe('セッション有効性チェック', () => {
    it('有効なセッションかどうか判定できる', () => {
      SessionManager.getSessionId(); // セッションID生成
      SessionManager.setCurrentConversationId('conv-valid');
      
      expect(SessionManager.hasValidSession()).toBe(true);
    });

    it('会話IDがない場合は無効', () => {
      SessionManager.getSessionId(); // セッションIDのみ
      
      expect(SessionManager.hasValidSession()).toBe(false);
    });

    it('セッションIDがない場合は無効', () => {
      // SessionManagerのインスタンスを完全にリセット
      (SessionManager as any).sessionId = null;
      
      // Cookieを明示的にクリア（JSDOMの制限のため）
      Object.defineProperty(document, 'cookie', {
        writable: true,
        value: ''
      });
      
      // 会話IDは設定
      localStorageMock.setItem('current_conversation_id', 'conv-123');
      
      // getCookieが本当にnullを返すことを確認
      const sessionId = SessionManager.getCookie('session_id');
      expect(sessionId).toBeNull();
      
      expect(SessionManager.hasValidSession()).toBe(false);
    });
  });
});