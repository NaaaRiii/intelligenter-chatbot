import React, { useState, useEffect } from 'react';
import { History, X, MessageCircle, Calendar, ChevronRight } from 'lucide-react';
import SessionManager from '../services/sessionManager';

interface Message {
  id: number;
  content: string;
  role: 'user' | 'assistant' | 'system' | 'company';
  created_at: string;
}

interface Conversation {
  id: string;
  session_id: string;
  status: 'active' | 'inactive';
  created_at: string;
  updated_at: string;
  messages: Message[];
}

interface ChatHistoryProps {
  onResumeConversation?: (conversationId: string) => void;
}

const ChatHistory: React.FC<ChatHistoryProps> = ({ onResumeConversation }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // SessionManagerからユーザーIDを取得（全タブの会話を表示）
  const getUserId = () => {
    return SessionManager.getUserId();
  };

  // 会話履歴を取得
  const fetchConversations = async () => {
    setLoading(true);
    setError(null);
    
    try {
      const userId = getUserId();
      const headers: HeadersInit = {
        'Content-Type': 'application/json',
      };
      
      if (userId) {
        headers['X-User-Id'] = userId;
        // 互換性のため、セッションIDも送信
        headers['X-Session-Id'] = SessionManager.getSessionId();
      }

      const response = await fetch('http://localhost:3000/api/v1/conversations', {
        method: 'GET',
        headers,
        credentials: 'include'
      });

      if (!response.ok) {
        throw new Error('Failed to fetch conversations');
      }

      const data = await response.json();
      setConversations(data.conversations || []);
    } catch (err) {
      setError('履歴の取得に失敗しました');
      console.error('Error fetching conversations:', err);
    } finally {
      setLoading(false);
    }
  };

  // モーダルを開いた時に履歴を取得
  useEffect(() => {
    if (isOpen) {
      fetchConversations();
    }
  }, [isOpen]);

  // 会話を再開
  const handleResumeConversation = (conversationId: string) => {
    if (onResumeConversation) {
      onResumeConversation(conversationId);
    }
    setIsOpen(false);
  };

  // 日付フォーマット
  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('ja-JP', {
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  // 会話のプレビューテキストを取得
  const getPreviewText = (conversation: Conversation) => {
    if (conversation.messages.length === 0) {
      return 'メッセージはありません';
    }
    const firstUserMessage = conversation.messages.find(m => m.role === 'user');
    if (firstUserMessage) {
      return firstUserMessage.content.length > 50 
        ? firstUserMessage.content.substring(0, 50) + '...'
        : firstUserMessage.content;
    }
    return conversation.messages[0].content.substring(0, 50) + '...';
  };

  return (
    <>
      {/* チャット履歴ボタン */}
      <button
        onClick={() => setIsOpen(true)}
        className="flex items-center gap-2 px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
        aria-label="チャット履歴"
      >
        <History className="w-5 h-5" data-testid="history-icon" />
        <span>チャット履歴</span>
      </button>

      {/* モーダル */}
      {isOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-2xl max-h-[80vh] flex flex-col">
            {/* ヘッダー */}
            <div className="flex justify-between items-center p-6 border-b">
              <h2 className="text-xl font-semibold">過去のチャット</h2>
              <button
                onClick={() => setIsOpen(false)}
                className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
                aria-label="閉じる"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* コンテンツ */}
            <div className="flex-1 overflow-y-auto p-6">
              {loading && (
                <div className="text-center py-8 text-gray-500">
                  読み込み中...
                </div>
              )}

              {error && (
                <div className="text-center py-8 text-red-500">
                  {error}
                </div>
              )}

              {!loading && !error && conversations.length === 0 && (
                <div className="text-center py-8 text-gray-500">
                  チャット履歴はありません
                </div>
              )}

              {!loading && !error && conversations.length > 0 && (
                <div className="space-y-3">
                  {conversations.map((conversation) => (
                    <button
                      key={conversation.id}
                      onClick={() => handleResumeConversation(conversation.id)}
                      className="w-full text-left p-4 bg-gray-50 hover:bg-gray-100 rounded-lg transition-colors group"
                    >
                      <div className="flex items-start justify-between">
                        <div className="flex-1">
                          <div className="flex items-center gap-2 mb-2">
                            <MessageCircle className="w-4 h-4 text-gray-400" />
                            <span className="text-sm text-gray-600">
                              {conversation.messages.length} メッセージ
                            </span>
                            {conversation.status === 'active' && (
                              <span className="text-xs px-2 py-1 bg-green-100 text-green-700 rounded">
                                アクティブ
                              </span>
                            )}
                          </div>
                          <p className="text-gray-900 mb-2">
                            {getPreviewText(conversation)}
                          </p>
                          <div className="flex items-center gap-1 text-xs text-gray-500">
                            <Calendar className="w-3 h-3" />
                            <span>
                              {formatDate(conversation.updated_at)}
                            </span>
                          </div>
                        </div>
                        <ChevronRight className="w-5 h-5 text-gray-400 group-hover:text-gray-600 transition-colors" />
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </>
  );
};

export default ChatHistory;