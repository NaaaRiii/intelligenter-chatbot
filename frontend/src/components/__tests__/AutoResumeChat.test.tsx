import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import AutoResumeChat from '../AutoResumeChat';
import SessionManager from '../../services/sessionManager';

// モック
vi.mock('../../services/sessionManager');
vi.mock('../../services/actionCable');

const mockFetch = vi.fn();
global.fetch = mockFetch;

const mockOnConversationLoaded = vi.fn();

describe('AutoResumeChat', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.resetAllMocks();
    localStorage.clear();
    document.cookie = '';
    
    // デフォルトのモック設定
    vi.mocked(SessionManager.getSessionId).mockReturnValue('session-456');
    vi.mocked(SessionManager.hasValidSession).mockReturnValue(false);
    vi.mocked(SessionManager.getCurrentConversationId).mockReturnValue(null);
    vi.mocked(SessionManager.getLastActiveConversation).mockReturnValue(null);
    vi.mocked(SessionManager.setCurrentConversationId).mockImplementation(() => {});
    vi.mocked(SessionManager.setLastActiveConversation).mockImplementation(() => {});
    vi.mocked(SessionManager.clearCurrentConversationId).mockImplementation(() => {});
  });

  describe('自動復元の条件判定', () => {
    it('有効なセッションがある場合、自動的に会話を復元する', async () => {
      // セッション情報をモック
      vi.mocked(SessionManager.hasValidSession).mockReturnValue(true);
      vi.mocked(SessionManager.getSessionId).mockReturnValue('session-123');
      vi.mocked(SessionManager.getCurrentConversationId).mockReturnValue('conv-123');
      
      // API応答をモック
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          conversation: {
            id: 'conv-123',
            messages: [
              { id: 1, content: '前回の会話', role: 'user' },
              { id: 2, content: '前回の返答', role: 'assistant' }
            ]
          }
        })
      });

      render(<AutoResumeChat onConversationLoaded={mockOnConversationLoaded} />);

      await waitFor(() => {
        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/conversations/conv-123'),
          expect.any(Object)
        );
      });

      await waitFor(() => {
        expect(mockOnConversationLoaded).toHaveBeenCalledWith({
          conversationId: 'conv-123',
          messages: expect.arrayContaining([
            expect.objectContaining({ content: '前回の会話' })
          ])
        });
      });
    });

    it('セッションがない場合は新規会話を開始', () => {
      vi.mocked(SessionManager.hasValidSession).mockReturnValue(false);
      vi.mocked(SessionManager.getSessionId).mockReturnValue(null);

      render(<AutoResumeChat onConversationLoaded={mockOnConversationLoaded} />);

      expect(mockFetch).not.toHaveBeenCalled();
      expect(screen.queryByText('会話を復元中...')).not.toBeInTheDocument();
    });

    it('会話IDがない場合は復元しない', () => {
      vi.mocked(SessionManager.hasValidSession).mockReturnValue(false);
      vi.mocked(SessionManager.getSessionId).mockReturnValue('session-456');
      vi.mocked(SessionManager.getCurrentConversationId).mockReturnValue(null);

      render(<AutoResumeChat onConversationLoaded={mockOnConversationLoaded} />);

      expect(mockFetch).not.toHaveBeenCalled();
    });
  });

  describe('復元プロセス', () => {
    it('復元中はローディング表示を出す', async () => {
      vi.mocked(SessionManager.hasValidSession).mockReturnValue(true);
      vi.mocked(SessionManager.getCurrentConversationId).mockReturnValue('conv-789');

      // 遅延レスポンスをシミュレート
      mockFetch.mockImplementation(() => new Promise(() => {}));

      render(<AutoResumeChat onConversationLoaded={mockOnConversationLoaded} />);

      expect(screen.getByText('会話を復元中...')).toBeInTheDocument();
    });

    it('復元成功後はローディングを消す', async () => {
      vi.mocked(SessionManager.hasValidSession).mockReturnValue(true);
      vi.mocked(SessionManager.getCurrentConversationId).mockReturnValue('conv-success');

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          conversation: { id: 'conv-success', messages: [] }
        })
      });

      render(<AutoResumeChat onConversationLoaded={mockOnConversationLoaded} />);

      await waitFor(() => {
        expect(screen.queryByText('会話を復元中...')).not.toBeInTheDocument();
      });
    });

    it('復元失敗時はエラーメッセージを表示', async () => {
      vi.mocked(SessionManager.hasValidSession).mockReturnValue(true);
      vi.mocked(SessionManager.getCurrentConversationId).mockReturnValue('conv-error');

      mockFetch.mockRejectedValueOnce(new Error('Network error'));

      render(<AutoResumeChat onConversationLoaded={mockOnConversationLoaded} />);

      await waitFor(() => {
        expect(screen.getByText(/会話の復元に失敗しました/)).toBeInTheDocument();
      });
    });

    it('404エラーの場合は新規会話として扱う', async () => {
      vi.mocked(SessionManager.hasValidSession).mockReturnValue(true);
      vi.mocked(SessionManager.getCurrentConversationId).mockReturnValue('conv-404');

      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 404
      });

      render(<AutoResumeChat onConversationLoaded={mockOnConversationLoaded} />);

      await waitFor(() => {
        // 会話IDをクリア
        expect(SessionManager.clearCurrentConversationId).toHaveBeenCalled();
      });

      // エラーメッセージは表示しない
      expect(screen.queryByText(/会話の復元に失敗しました/)).not.toBeInTheDocument();
    });
  });

  describe('最終アクティブ会話の取得', () => {
    it('最後にアクティブだった会話を自動選択する', async () => {
      // hasValidSessionはfalseだが、getLastActiveConversationで会話情報を返す
      vi.mocked(SessionManager.hasValidSession).mockReturnValue(false);
      vi.mocked(SessionManager.getLastActiveConversation).mockReturnValue({
        conversationId: 'conv-last-active',
        timestamp: new Date().toISOString(),
        messageCount: 10
      });
      
      // setCurrentConversationIdが呼ばれた後、getCurrentConversationIdはその値を返すようにする
      vi.mocked(SessionManager.setCurrentConversationId).mockImplementation((id) => {
        vi.mocked(SessionManager.getCurrentConversationId).mockReturnValue(id);
      });

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          conversation: {
            id: 'conv-last-active',
            messages: Array(10).fill({ content: 'test', role: 'user' })
          }
        })
      });

      render(<AutoResumeChat onConversationLoaded={mockOnConversationLoaded} />);

      await waitFor(() => {
        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/conversations/conv-last-active'),
          expect.any(Object)
        );
      });
      
      await waitFor(() => {
        expect(mockOnConversationLoaded).toHaveBeenCalledWith({
          conversationId: 'conv-last-active',
          messages: expect.arrayContaining([
            expect.objectContaining({ content: 'test' })
          ])
        });
      });
    });

    it('30日以上前の会話は復元しない', () => {
      const oldDate = new Date();
      oldDate.setDate(oldDate.getDate() - 31);

      // hasValidSessionはfalse、古い会話情報を返す
      vi.mocked(SessionManager.hasValidSession).mockReturnValue(false);
      vi.mocked(SessionManager.getCurrentConversationId).mockReturnValue(null);
      vi.mocked(SessionManager.getLastActiveConversation).mockReturnValue({
        conversationId: 'conv-old',
        timestamp: oldDate.toISOString(),
        messageCount: 5
      });

      render(<AutoResumeChat onConversationLoaded={mockOnConversationLoaded} />);

      // 古い会話は取得しない
      expect(mockFetch).not.toHaveBeenCalled();
      // setCurrentConversationIdも呼ばれない
      expect(SessionManager.setCurrentConversationId).not.toHaveBeenCalled();
    });
  });

  describe('復元タイミング', () => {
    it('コンポーネントマウント時に1回だけ復元を試みる', async () => {
      vi.mocked(SessionManager.hasValidSession).mockReturnValue(true);
      vi.mocked(SessionManager.getCurrentConversationId).mockReturnValue('conv-once');

      mockFetch.mockResolvedValue({
        ok: true,
        json: async () => ({
          conversation: { id: 'conv-once', messages: [] }
        })
      });

      const { rerender } = render(
        <AutoResumeChat onConversationLoaded={mockOnConversationLoaded} />
      );

      await waitFor(() => {
        expect(mockFetch).toHaveBeenCalledTimes(1);
      });

      // 再レンダリングしても再度取得しない
      rerender(<AutoResumeChat onConversationLoaded={mockOnConversationLoaded} />);

      expect(mockFetch).toHaveBeenCalledTimes(1);
    });

    it('手動リトライボタンで再度復元を試みる', async () => {
      vi.mocked(SessionManager.hasValidSession).mockReturnValue(true);
      vi.mocked(SessionManager.getCurrentConversationId).mockReturnValue('conv-retry');

      // 最初は失敗
      mockFetch.mockRejectedValueOnce(new Error('Network error'));

      const { rerender } = render(
        <AutoResumeChat onConversationLoaded={mockOnConversationLoaded} />
      );

      await waitFor(() => {
        expect(screen.getByText(/会話の復元に失敗しました/)).toBeInTheDocument();
      });

      // リトライボタンが表示される
      const retryButton = screen.getByRole('button', { name: /再試行/ });
      expect(retryButton).toBeInTheDocument();

      // 次は成功
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          conversation: { id: 'conv-retry', messages: [] }
        })
      });

      retryButton.click();

      await waitFor(() => {
        expect(mockFetch).toHaveBeenCalledTimes(2);
      });
    });
  });
});