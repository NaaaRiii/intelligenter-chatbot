import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import ChatHistory from '../ChatHistory';

// APIモック
const mockFetch = vi.fn();
global.fetch = mockFetch;

const mockConversations = [
  {
    id: 'conv-1',
    session_id: 'session-1',
    status: 'active',
    created_at: '2025-08-30T10:00:00Z',
    updated_at: '2025-08-30T10:30:00Z',
    messages: [
      {
        id: 1,
        content: 'こんにちは',
        role: 'user',
        created_at: '2025-08-30T10:00:00Z'
      },
      {
        id: 2,
        content: 'お問い合わせありがとうございます',
        role: 'assistant',
        created_at: '2025-08-30T10:01:00Z'
      }
    ]
  },
  {
    id: 'conv-2',
    session_id: 'session-2',
    status: 'inactive',
    created_at: '2025-08-29T14:00:00Z',
    updated_at: '2025-08-29T14:45:00Z',
    messages: [
      {
        id: 3,
        content: '料金について教えてください',
        role: 'user',
        created_at: '2025-08-29T14:00:00Z'
      }
    ]
  }
];

describe('ChatHistory', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
  });

  describe('履歴ボタン', () => {
    it('チャット履歴ボタンが表示される', () => {
      render(<ChatHistory />);
      const button = screen.getByRole('button', { name: /チャット履歴/i });
      expect(button).toBeInTheDocument();
    });

    it('ボタンにアイコンが表示される', () => {
      render(<ChatHistory />);
      const icon = screen.getByTestId('history-icon');
      expect(icon).toBeInTheDocument();
    });

    it('ボタンクリックで履歴一覧が開く', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ conversations: mockConversations })
      });

      render(<ChatHistory />);
      const button = screen.getByRole('button', { name: /チャット履歴/i });
      
      fireEvent.click(button);
      
      await waitFor(() => {
        expect(screen.getByText('過去のチャット')).toBeInTheDocument();
      });
    });
  });

  describe('会話一覧表示', () => {
    it('過去の会話一覧が表示される', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ conversations: mockConversations })
      });

      render(<ChatHistory />);
      const button = screen.getByRole('button', { name: /チャット履歴/i });
      fireEvent.click(button);

      await waitFor(() => {
        // 各会話の最初のメッセージが表示される
        expect(screen.getByText('こんにちは')).toBeInTheDocument();
        expect(screen.getByText('料金について教えてください')).toBeInTheDocument();
      });
    });

    it('会話の日時が表示される', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ conversations: mockConversations })
      });

      render(<ChatHistory />);
      const button = screen.getByRole('button', { name: /チャット履歴/i });
      fireEvent.click(button);

      await waitFor(() => {
        // 日付フォーマットが表示されることを確認（複数あるので最初のものを確認）
        const dateElements = screen.getAllByText(/2025/);
        expect(dateElements.length).toBeGreaterThan(0);
      });
    });

    it('会話がない場合はメッセージが表示される', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ conversations: [] })
      });

      render(<ChatHistory />);
      const button = screen.getByRole('button', { name: /チャット履歴/i });
      fireEvent.click(button);

      await waitFor(() => {
        expect(screen.getByText('チャット履歴はありません')).toBeInTheDocument();
      });
    });

    it('読み込み中の表示', async () => {
      mockFetch.mockImplementation(() => new Promise(() => {})); // 永遠にpending

      render(<ChatHistory />);
      const button = screen.getByRole('button', { name: /チャット履歴/i });
      fireEvent.click(button);

      expect(screen.getByText('読み込み中...')).toBeInTheDocument();
    });

    it('エラー時の表示', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'));

      render(<ChatHistory />);
      const button = screen.getByRole('button', { name: /チャット履歴/i });
      fireEvent.click(button);

      await waitFor(() => {
        expect(screen.getByText('履歴の取得に失敗しました')).toBeInTheDocument();
      });
    });
  });

  describe('会話の再開', () => {
    it('会話をクリックすると再開される', async () => {
      const onResumeConversation = vi.fn();
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ conversations: mockConversations })
      });

      render(<ChatHistory onResumeConversation={onResumeConversation} />);
      const button = screen.getByRole('button', { name: /チャット履歴/i });
      fireEvent.click(button);

      await waitFor(() => {
        const conversation = screen.getByText('こんにちは').closest('button');
        fireEvent.click(conversation!);
      });

      expect(onResumeConversation).toHaveBeenCalledWith('conv-1');
    });

    it('会話再開後に履歴モーダルが閉じる', async () => {
      const onResumeConversation = vi.fn();
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ conversations: mockConversations })
      });

      render(<ChatHistory onResumeConversation={onResumeConversation} />);
      const button = screen.getByRole('button', { name: /チャット履歴/i });
      fireEvent.click(button);

      await waitFor(() => {
        const conversation = screen.getByText('こんにちは').closest('button');
        fireEvent.click(conversation!);
      });

      await waitFor(() => {
        expect(screen.queryByText('過去のチャット')).not.toBeInTheDocument();
      });
    });
  });

  describe('API連携', () => {
    it('正しいAPIエンドポイントを呼び出す', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ conversations: [] })
      });

      render(<ChatHistory />);
      const button = screen.getByRole('button', { name: /チャット履歴/i });
      fireEvent.click(button);

      await waitFor(() => {
        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/conversations'),
          expect.objectContaining({
            method: 'GET',
            headers: expect.objectContaining({
              'Content-Type': 'application/json'
            })
          })
        );
      });
    });

    it('セッションIDがヘッダーに含まれる', async () => {
      const sessionId = 'test-session-123';
      document.cookie = `session_id=${sessionId}`;

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ conversations: [] })
      });

      render(<ChatHistory />);
      const button = screen.getByRole('button', { name: /チャット履歴/i });
      fireEvent.click(button);

      await waitFor(() => {
        expect(mockFetch).toHaveBeenCalledWith(
          expect.any(String),
          expect.objectContaining({
            headers: expect.objectContaining({
              'X-Session-Id': sessionId
            })
          })
        );
      });
    });
  });
});