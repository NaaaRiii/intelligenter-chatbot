import React, { useState, useEffect } from 'react';
import CustomerTypeSelector from './CustomerTypeSelector';
import NewCustomerChat from './NewCustomerChat';
import ExistingCustomerChat from './ExistingCustomerChat';

const ChatWithSelector: React.FC = () => {
  const [customerType, setCustomerType] = useState<'new' | 'existing' | 'existing-chat' | null>(null);
  const [hasConversationId, setHasConversationId] = useState(false);

  useEffect(() => {
    // URLパラメータをチェック
    const urlParams = new URLSearchParams(window.location.search);
    const customerTypeParam = urlParams.get('customerType');
    
    // customerType=existingパラメータがある場合は既存顧客として直接チャット画面を表示
    if (customerTypeParam === 'existing') {
      setCustomerType('existing');
      return;
    }
    
    // URLハッシュに会話IDがある場合は直接チャット画面を表示
    const hashId = window.location.hash.replace('#', '');
    if (hashId && /^\d+$/.test(hashId)) {
      setHasConversationId(true);
      setCustomerType('new'); // NewCustomerChatを使用（会話履歴表示機能があるため）
    }
    
    // URLパスに'/chat/new'がある場合は新規顧客として直接チャット画面を表示
    if (window.location.pathname === '/chat/new') {
      setCustomerType('new');
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

  // 既存顧客の場合はExistingCustomerChatを表示
  return <ExistingCustomerChat />;
};

export default ChatWithSelector;