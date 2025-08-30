import React, { useState } from 'react';
import CustomerTypeSelector from './CustomerTypeSelector';
import Chatbot from './Chatbot';

const ChatWithSelector: React.FC = () => {
  const [customerType, setCustomerType] = useState<'new' | 'existing' | null>(null);

  const handleCustomerTypeSelect = (type: 'new' | 'existing') => {
    setCustomerType(type);
  };

  // 顧客タイプが選択されていない場合は選択画面を表示
  if (!customerType) {
    return <CustomerTypeSelector onSelect={handleCustomerTypeSelect} />;
  }

  // 顧客タイプが選択されたらチャット画面を表示
  return (
    <div style={{ position: 'relative' }}>
      {/* 顧客タイプ表示バー */}
      <div style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        backgroundColor: customerType === 'new' ? '#dbeafe' : '#dcfce7',
        padding: '0.5rem',
        textAlign: 'center',
        borderBottom: '1px solid',
        borderColor: customerType === 'new' ? '#93c5fd' : '#86efac',
        zIndex: 100
      }}>
        <span style={{
          fontSize: '0.875rem',
          fontWeight: '500',
          color: customerType === 'new' ? '#1e40af' : '#166534'
        }}>
          {customerType === 'new' ? '🆕 新規のお客様' : '✅ 既存のお客様'}
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