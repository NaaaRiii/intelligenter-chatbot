import React, { useState, useEffect } from 'react';
import CustomerTypeSelector from './CustomerTypeSelector';
import Chatbot from './Chatbot';
import NewCustomerChat from './NewCustomerChat';

const ChatWithSelector: React.FC = () => {
  const [customerType, setCustomerType] = useState<'new' | 'existing' | null>(null);
  const [hasConversationId, setHasConversationId] = useState(false);

  useEffect(() => {
    // URLハッシュに会話IDがある場合は直接チャット画面を表示
    const hashId = window.location.hash.replace('#', '');
    if (hashId && /^\d+$/.test(hashId)) {
      setHasConversationId(true);
      setCustomerType('new'); // NewCustomerChatを使用（会話履歴表示機能があるため）
    }
  }, []);

  const handleCustomerTypeSelect = (type: 'new' | 'existing') => {
    setCustomerType(type);
  };

  // URLに会話IDがない場合のみ、顧客タイプ選択画面を表示
  if (!customerType && !hasConversationId) {
    return <CustomerTypeSelector onSelect={handleCustomerTypeSelect} />;
  }

  // 新規顧客の場合はNewCustomerChatを表示
  if (customerType === 'new') {
    return <NewCustomerChat />;
  }

  // 既存顧客の場合は通常のChatbot画面を表示
  return (
    <div style={{ position: 'relative' }}>
      {/* 顧客タイプ表示バー */}
      <div style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        backgroundColor: '#dcfce7',
        padding: '0.5rem',
        textAlign: 'center',
        borderBottom: '1px solid',
        borderColor: '#86efac',
        zIndex: 100
      }}>
        <span style={{
          fontSize: '0.875rem',
          fontWeight: '500',
          color: '#166534'
        }}>
          ✅ 既存のお客様
        </span>
      </div>
      
      {/* チャット画面（上部にマージンを追加） */}
      <div style={{ paddingTop: '2.5rem' }}>
        <Chatbot />
      </div>
    </div>
  );
};

export default ChatWithSelector;