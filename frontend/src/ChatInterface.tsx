import React, { useState, useEffect, useRef } from 'react';

interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
}

interface ChatInterfaceProps {
  customerType: 'new' | 'existing';
  category: string | null;
  initialHistory?: any;
}

const ChatInterface: React.FC<ChatInterfaceProps> = ({ customerType, category: initialCategory, initialHistory }) => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [conversationId, setConversationId] = useState<number | null>(null);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [isInitialized, setIsInitialized] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState<string | null>(initialCategory);
  const [showCategories, setShowCategories] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const ws = useRef<WebSocket | null>(null);

  // カテゴリーリストの定義
  const existingCategories = [
    { value: 'cdp', label: 'CDP運用', emoji: '📊', description: 'データ統合・セグメント設定' },
    { value: 'ma_crm', label: 'MA/CRM最適化', emoji: '📧', description: 'シナリオ設計・スコアリング' },
    { value: 'advertising', label: 'Web広告運用', emoji: '📢', description: 'Google/Facebook広告の改善' },
    { value: 'analytics', label: 'データ分析', emoji: '📈', description: 'ダッシュボード・レポート' },
    { value: 'development', label: 'システム開発', emoji: '⚙️', description: 'API連携・機能追加' },
    { value: 'ecommerce', label: 'ECサイト運営', emoji: '🛒', description: 'Shopify・決済システム' },
    { value: 'ai_ml', label: 'AI・機械学習', emoji: '🤖', description: '予測モデル・チャットボット' },
    { value: 'organization', label: '組織・体制', emoji: '👥', description: '研修・KPI設定' },
    { value: 'cost', label: 'コスト最適化', emoji: '💰', description: '運用費・契約見直し' },
    { value: 'competition', label: '競合対策', emoji: '🎯', description: '市場戦略・ブランディング' },
  ];

  const newCategories = [
    { value: 'service', label: 'サービス概要・能力範囲', emoji: '🏢', description: 'マーケティング戦略とシステム構築の統合サポート' },
    { value: 'tech', label: '技術・システム関連', emoji: '💻', description: 'どんなシステム開発が得意？既存システムとの連携は？' },
    { value: 'marketing', label: 'マーケティング戦略', emoji: '📈', description: '業界別のマーケティング事例は？SEO・広告運用も対応？' },
    { value: 'project', label: 'プロジェクト進行・体制', emoji: '👥', description: 'プロジェクトの進め方は？担当チームの構成は？' },
    { value: 'pricing', label: '費用・契約', emoji: '💵', description: '料金体系・見積もり依頼、契約期間について' },
    { value: 'cases', label: '実績・事例', emoji: '🏆', description: '同業界での導入事例は？ROI・成果事例を知りたい' },
    { value: 'consultation', label: '初回相談・問い合わせ', emoji: '💬', description: 'まず何から相談すれば良い？提案資料の作成は可能？' },
    { value: 'faq', label: 'よくある質問（FAQ）', emoji: '❓', description: '料金プランや契約条件を確認' },
  ];

  const categories = customerType === 'existing' ? existingCategories : newCategories;

  useEffect(() => {
    // 初回メッセージを追加
    const initialMessage = 'こんにちは！お問い合わせありがとうございます。どのようなご用件でしょうか？';
    
    const msgs = [{
      id: '1',
      role: 'assistant' as const,
      content: initialMessage,
      timestamp: new Date()
    }];

    // カテゴリー選択メッセージを追加
    if (!initialCategory) {
      msgs.push({
        id: '2',
        role: 'assistant' as const,
        content: 'お問い合わせありがとうございます。以下のカテゴリーの中からお選びください。',
        timestamp: new Date()
      });
      setShowCategories(true);
    }

    setMessages(msgs);

    // 履歴がある場合は追加
    if (initialHistory?.messages) {
      const historyMessages = initialHistory.messages.map((msg: any, index: number) => ({
        id: `history-${index}`,
        role: msg.role,
        content: msg.content,
        timestamp: new Date(msg.created_at)
      }));
      setMessages(prev => [...prev, ...historyMessages]);
      setConversationId(initialHistory.id);
      setName(initialHistory.name || '');
      setEmail(initialHistory.email || '');
      setIsInitialized(true);
    }
  }, [customerType, initialHistory]);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const connectWebSocket = () => {
    if (!conversationId) return;

    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//localhost:3000/cable`;
    
    ws.current = new WebSocket(wsUrl);

    ws.current.onopen = () => {
      console.log('WebSocket Connected');
      // ActionCableのサブスクリプション
      ws.current?.send(JSON.stringify({
        command: 'subscribe',
        identifier: JSON.stringify({
          channel: 'ConversationChannel',
          conversation_id: conversationId
        })
      }));
    };

    ws.current.onmessage = (event) => {
      const data = JSON.parse(event.data);
      
      if (data.type === 'ping') return;
      
      if (data.message?.content) {
        const newMessage: Message = {
          id: Date.now().toString(),
          role: data.message.role,
          content: data.message.content,
          timestamp: new Date()
        };
        
        setMessages(prev => [...prev, newMessage]);
        setIsLoading(false);
      }
    };

    ws.current.onerror = (error) => {
      console.error('WebSocket Error:', error);
      setIsLoading(false);
    };

    ws.current.onclose = () => {
      console.log('WebSocket Disconnected');
    };
  };

  const createConversation = async () => {
    try {
      const response = await fetch('http://localhost:3000/api/v1/conversations', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          conversation: {
            metadata: {
              customerType: customerType,
              category: selectedCategory,
              name: name,
              email: email
            }
          }
        })
      });

      const data = await response.json();
      
      if (data.id) {
        setConversationId(data.id);
        return data.id;
      }
    } catch (error) {
      console.error('Error creating conversation:', error);
    }
    return null;
  };

  const handleCategorySelect = (category: string) => {
    setSelectedCategory(category);
    setShowCategories(false);
    
    const categoryLabel = categories.find(c => c.value === category)?.label || category;
    const userMessage: Message = {
      id: Date.now().toString(),
      role: 'user',
      content: `「${categoryLabel}」について相談したいです。`,
      timestamp: new Date()
    };
    setMessages(prev => [...prev, userMessage]);
    
    setTimeout(() => {
      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: `${categoryLabel}についてのご相談ですね。具体的にどのようなことでお困りでしょうか？詳しくお聞かせください。`,
        timestamp: new Date()
      };
      setMessages(prev => [...prev, assistantMessage]);
    }, 1000);
  };

  const sendMessage = async () => {
    if (!inputMessage.trim()) return;
    if (!selectedCategory && !showCategories) return;

    let currentConversationId = conversationId;

    // 初回メッセージの場合は会話を作成
    if (!currentConversationId && !isInitialized) {
      currentConversationId = await createConversation();
      if (!currentConversationId) {
        console.error('Failed to create conversation');
        return;
      }
      setIsInitialized(true);
    }

    // ユーザーメッセージを追加
    const userMessage: Message = {
      id: Date.now().toString(),
      role: 'user',
      content: inputMessage,
      timestamp: new Date()
    };
    setMessages(prev => [...prev, userMessage]);
    setInputMessage('');
    setIsLoading(true);

    // WebSocketが未接続の場合は接続
    if (!ws.current || ws.current.readyState !== WebSocket.OPEN) {
      connectWebSocket();
    }

    // APIでメッセージを送信
    try {
      await fetch(`http://localhost:3000/api/v1/conversations/${currentConversationId}/messages`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            content: inputMessage,
            role: 'user'
          }
        })
      });
    } catch (error) {
      console.error('Error sending message:', error);
      setIsLoading(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  // カテゴリーのラベルを取得
  const getCategoryLabel = () => {
    const categoryLabels: Record<string, string> = {
      // 新規顧客
      marketing: 'マーケティング戦略',
      tech: '技術・システム相談',
      service: 'サービス内容',
      project: 'プロジェクト進行',
      pricing: '費用・契約',
      cases: '実績・事例',
      consultation: '初回相談',
      // 既存顧客
      cdp: 'CDP運用',
      ma_crm: 'MA/CRM最適化',
      advertising: 'Web広告運用',
      analytics: 'データ分析',
      development: 'システム開発',
      ecommerce: 'ECサイト運営',
      ai_ml: 'AI・機械学習',
      organization: '組織・体制',
      cost: 'コスト最適化',
      competition: '競合対策',
    };
    return categoryLabels[selectedCategory || ''] || selectedCategory;
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh', backgroundColor: '#f9fafb' }}>
      {/* ヘッダー */}
      <div style={{ 
        backgroundColor: '#2563eb',
        color: 'white',
        padding: '1rem',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
      }}>
        <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 'bold', margin: 0 }}>
            {customerType === 'existing' ? '運用サポート' : 'カスタマーサポート'}
          </h1>
          {selectedCategory && (
            <p style={{ fontSize: '0.9rem', opacity: 0.9, marginTop: '0.25rem' }}>
              {getCategoryLabel()}
            </p>
          )}
        </div>
      </div>

      {/* チャットエリア */}
      <div style={{ 
        flex: 1, 
        overflowY: 'auto', 
        padding: '1.5rem',
        maxWidth: '900px',
        width: '100%',
        margin: '0 auto'
      }}>
        {/* 名前とメールの入力（初回のみ） */}
        {!isInitialized && (
          <div style={{ 
            backgroundColor: 'white',
            padding: '1.5rem',
            borderRadius: '0.5rem',
            marginBottom: '1rem',
            boxShadow: '0 1px 3px rgba(0,0,0,0.1)'
          }}>
            <div style={{ marginBottom: '1rem' }}>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '500' }}>
                お名前
              </label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="山田太郎"
                style={{
                  width: '100%',
                  padding: '0.5rem',
                  border: '1px solid #e5e7eb',
                  borderRadius: '0.375rem',
                  fontSize: '1rem'
                }}
              />
            </div>
            <div>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '500' }}>
                メールアドレス
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="yamada@example.com"
                style={{
                  width: '100%',
                  padding: '0.5rem',
                  border: '1px solid #e5e7eb',
                  borderRadius: '0.375rem',
                  fontSize: '1rem'
                }}
              />
            </div>
          </div>
        )}

        {/* メッセージ表示エリア */}
        {messages.map((message) => (
          <div
            key={message.id}
            style={{
              marginBottom: '1rem',
              display: 'flex',
              justifyContent: message.role === 'user' ? 'flex-end' : 'flex-start'
            }}
          >
            <div
              style={{
                maxWidth: '70%',
                padding: '0.75rem 1rem',
                borderRadius: '0.75rem',
                backgroundColor: message.role === 'user' ? '#2563eb' : 'white',
                color: message.role === 'user' ? 'white' : '#1f2937',
                boxShadow: '0 1px 2px rgba(0,0,0,0.1)'
              }}
            >
              <p style={{ margin: 0, whiteSpace: 'pre-wrap' }}>{message.content}</p>
              <p style={{ 
                fontSize: '0.75rem', 
                opacity: 0.7, 
                marginTop: '0.25rem',
                margin: '0.25rem 0 0 0'
              }}>
                {message.timestamp.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}
              </p>
            </div>
          </div>
        ))}

        {/* カテゴリー選択ボタン */}
        {showCategories && !selectedCategory && (
          <div style={{
            marginTop: '1rem',
            marginBottom: '1rem'
          }}>
            <div style={{
              backgroundColor: '#f9fafb',
              borderRadius: '0.75rem',
              padding: '1.5rem',
              textAlign: 'center'
            }}>
              <h3 style={{ 
                fontSize: '1.1rem', 
                fontWeight: '600', 
                marginBottom: '0.5rem',
                color: '#1f2937'
              }}>
                お問い合わせありがとうございます
              </h3>
              <p style={{ 
                fontSize: '0.9rem', 
                color: '#6b7280',
                marginBottom: '1.5rem' 
              }}>
                以下のカテゴリーの中からお選びください
              </p>
              <div style={{
                display: 'grid',
                gridTemplateColumns: window.innerWidth > 768 ? 'repeat(2, 1fr)' : '1fr',
                gap: '0.75rem',
                maxWidth: '800px',
                margin: '0 auto'
              }}>
                {categories.map((cat) => (
                  <button
                    key={cat.value}
                    onClick={() => handleCategorySelect(cat.value)}
                    style={{
                      padding: '1rem',
                      border: '1px solid #e5e7eb',
                      borderRadius: '0.75rem',
                      backgroundColor: 'white',
                      cursor: 'pointer',
                      textAlign: 'left',
                      transition: 'all 0.2s',
                      display: 'flex',
                      alignItems: 'flex-start',
                      gap: '0.75rem'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.backgroundColor = '#f9fafb';
                      e.currentTarget.style.borderColor = '#3b82f6';
                      e.currentTarget.style.transform = 'translateY(-2px)';
                      e.currentTarget.style.boxShadow = '0 4px 6px rgba(0,0,0,0.1)';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.backgroundColor = 'white';
                      e.currentTarget.style.borderColor = '#e5e7eb';
                      e.currentTarget.style.transform = 'translateY(0)';
                      e.currentTarget.style.boxShadow = 'none';
                    }}
                  >
                    <div style={{
                      fontSize: '1.5rem',
                      width: '40px',
                      height: '40px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      backgroundColor: '#eff6ff',
                      borderRadius: '0.5rem',
                      flexShrink: 0
                    }}>
                      {(cat as any).emoji || '📌'}
                    </div>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontWeight: '600', fontSize: '0.95rem', marginBottom: '0.25rem', color: '#1f2937' }}>
                        {cat.label}
                      </div>
                      <div style={{ fontSize: '0.8rem', color: '#6b7280', lineHeight: '1.3' }}>
                        例: {cat.description}
                      </div>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* ローディング表示 */}
        {isLoading && (
          <div style={{ display: 'flex', justifyContent: 'flex-start', marginBottom: '1rem' }}>
            <div style={{ 
              backgroundColor: 'white',
              padding: '0.75rem 1rem',
              borderRadius: '0.75rem',
              boxShadow: '0 1px 2px rgba(0,0,0,0.1)'
            }}>
              <div style={{ display: 'flex', gap: '0.25rem' }}>
                <span style={{ animation: 'bounce 1.4s infinite ease-in-out' }}>●</span>
                <span style={{ animation: 'bounce 1.4s infinite ease-in-out 0.2s' }}>●</span>
                <span style={{ animation: 'bounce 1.4s infinite ease-in-out 0.4s' }}>●</span>
              </div>
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* 入力エリア */}
      <div style={{ 
        borderTop: '1px solid #e5e7eb',
        backgroundColor: 'white',
        padding: '1rem'
      }}>
        <div style={{ maxWidth: '900px', margin: '0 auto', display: 'flex', gap: '0.5rem' }}>
          <textarea
            value={inputMessage}
            onChange={(e) => setInputMessage(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder={isInitialized ? "メッセージを入力..." : "お名前とメールアドレスを入力してから、メッセージを送信してください"}
            disabled={!isInitialized && (!name || !email)}
            rows={3}
            style={{
              flex: 1,
              padding: '0.75rem',
              border: '1px solid #e5e7eb',
              borderRadius: '0.5rem',
              resize: 'none',
              fontSize: '1rem',
              fontFamily: 'inherit'
            }}
          />
          <button
            onClick={sendMessage}
            disabled={!inputMessage.trim() || isLoading || (!isInitialized && (!name || !email))}
            style={{
              padding: '0 1.5rem',
              backgroundColor: (!inputMessage.trim() || isLoading || (!isInitialized && (!name || !email))) ? '#9ca3af' : '#2563eb',
              color: 'white',
              border: 'none',
              borderRadius: '0.5rem',
              fontWeight: '500',
              cursor: (!inputMessage.trim() || isLoading || (!isInitialized && (!name || !email))) ? 'not-allowed' : 'pointer',
              fontSize: '1rem'
            }}
          >
            送信
          </button>
        </div>
      </div>

      <style>{`
        @keyframes bounce {
          0%, 60%, 100% { transform: translateY(0); }
          30% { transform: translateY(-10px); }
        }
      `}</style>
    </div>
  );
};

export default ChatInterface;