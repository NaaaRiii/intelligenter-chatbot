import React, { useEffect, useState } from 'react';
import { RefreshCw, AlertCircle } from 'lucide-react';
import sessionManager from '../services/sessionManager';

interface Message {
  id: number;
  content: string;
  role: 'user' | 'assistant' | 'system' | 'company';
  created_at?: string;
}

interface ConversationData {
  conversationId: string;
  messages: Message[];
}

interface AutoResumeChatProps {
  onConversationLoaded?: (data: ConversationData) => void;
  children?: React.ReactNode;
}

const AutoResumeChat: React.FC<AutoResumeChatProps> = ({ 
  onConversationLoaded,
  children 
}) => {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hasAttempted, setHasAttempted] = useState(false);

  const attemptResumeConversation = async () => {
    // 既に試行済みの場合はスキップ（無限ループ防止）
    if (hasAttempted && !error) {
      return;
    }

    // 有効なセッションがあるかチェック
    if (!sessionManager.hasValidSession()) {
      // 最後のアクティブな会話をチェック
      const lastActive = sessionManager.getLastActiveConversation();
      if (!lastActive) {
        setHasAttempted(true);
        return;
      }

      // 30日以内の会話なら復元を試みる
      const timestamp = new Date(lastActive.timestamp);
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      
      if (timestamp < thirtyDaysAgo) {
        setHasAttempted(true);
        return;
      }

      sessionManager.setCurrentConversationId(lastActive.conversationId);
    }

    const conversationId = sessionManager.getCurrentConversationId();
    if (!conversationId) {
      setHasAttempted(true);
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const sessionId = sessionManager.getSessionId();
      const response = await fetch(
        `http://localhost:3000/api/v1/conversations/${conversationId}`,
        {
          method: 'GET',
          headers: {
            'Content-Type': 'application/json',
            'X-Session-Id': sessionId
          },
          credentials: 'include'
        }
      );

      if (response.status === 404) {
        // 会話が見つからない場合はセッションをクリア
        sessionManager.clearCurrentConversationId();
        setHasAttempted(true);
        return;
      }

      if (!response.ok) {
        throw new Error('会話の復元に失敗しました');
      }

      const data = await response.json();
      const conversation = data.conversation;

      // 会話データをコールバックで親コンポーネントに渡す
      if (onConversationLoaded) {
        onConversationLoaded({
          conversationId: conversation.id,
          messages: conversation.messages || []
        });
      }

      // 最終アクティブ情報を更新
      sessionManager.setLastActiveConversation({
        conversationId: conversation.id,
        timestamp: new Date().toISOString(),
        messageCount: conversation.messages?.length || 0
      });

      setHasAttempted(true);
    } catch (err) {
      console.error('Failed to resume conversation:', err);
      setError('会話の復元に失敗しました');
      setHasAttempted(true);
    } finally {
      setIsLoading(false);
    }
  };

  // コンポーネントマウント時に自動復元を試みる
  useEffect(() => {
    attemptResumeConversation();
  }, []); // 空の依存配列で1回だけ実行

  const handleRetry = () => {
    setError(null);
    setHasAttempted(false);
    attemptResumeConversation();
  };

  // ローディング表示
  if (isLoading) {
    return (
      <div className="flex items-center justify-center p-4">
        <div className="flex items-center gap-3 text-gray-600">
          <RefreshCw className="w-5 h-5 animate-spin" />
          <span>会話を復元中...</span>
        </div>
      </div>
    );
  }

  // エラー表示
  if (error) {
    return (
      <div className="p-4">
        <div className="flex items-center gap-3 text-red-600 mb-3">
          <AlertCircle className="w-5 h-5" />
          <span>{error}</span>
        </div>
        <button
          onClick={handleRetry}
          className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
        >
          <RefreshCw className="w-4 h-4" />
          再試行
        </button>
      </div>
    );
  }

  // 子コンポーネントを表示
  return <>{children}</>;
};

export default AutoResumeChat;