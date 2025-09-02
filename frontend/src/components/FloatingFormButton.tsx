import React, { useState } from 'react';
import { MessageSquare, X, ChevronUp } from 'lucide-react';

interface FloatingFormButtonProps {
  onFormToggle: () => void;
  isFormVisible: boolean;
}

const FloatingFormButton: React.FC<FloatingFormButtonProps> = ({ onFormToggle, isFormVisible }) => {
  const [isHovered, setIsHovered] = useState(false);

  return (
    <div style={{
      position: 'fixed',
      bottom: '120px',
      right: '50px',
      zIndex: 1000
    }}>
      {/* フローティングボタン */}
      <button
        onClick={onFormToggle}
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
        style={{
          width: '56px',
          height: '56px',
          borderRadius: '50%',
          backgroundColor: isFormVisible ? '#ef4444' : '#2563eb',
          color: 'white',
          border: 'none',
          cursor: 'pointer',
          boxShadow: '0 4px 12px rgba(0, 0, 0, 0.15)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          transform: isHovered ? 'scale(1.1)' : 'scale(1)',
          transition: 'all 0.3s ease',
          position: 'relative'
        }}
        title={isFormVisible ? 'フォームを閉じる' : 'チャットにお問い合わせフォームを表示'}
      >
        {isFormVisible ? <X size={24} /> : <MessageSquare size={24} />}
        
        {/* パルスアニメーション（フォームが非表示の時のみ） */}
        {!isFormVisible && (
          <div style={{
            position: 'absolute',
            top: '-4px',
            left: '-4px',
            right: '-4px',
            bottom: '-4px',
            borderRadius: '50%',
            backgroundColor: '#2563eb',
            opacity: 0.3,
            animation: 'pulse 2s infinite'
          }} />
        )}
      </button>

      {/* ツールチップ */}
      {isHovered && !isFormVisible && (
        <div style={{
          position: 'absolute',
          bottom: '70px',
          right: '0',
          backgroundColor: '#1f2937',
          color: 'white',
          padding: '8px 12px',
          borderRadius: '8px',
          fontSize: '14px',
          whiteSpace: 'nowrap',
          boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)',
          animation: 'fadeInUp 0.3s ease'
        }}>
          チャットにフォーム表示
          <div style={{
            position: 'absolute',
            top: '100%',
            right: '20px',
            width: '0',
            height: '0',
            borderLeft: '6px solid transparent',
            borderRight: '6px solid transparent',
            borderTop: '6px solid #1f2937'
          }} />
        </div>
      )}

      <style>{`
        @keyframes pulse {
          0%, 100% {
            transform: scale(1);
            opacity: 0.3;
          }
          50% {
            transform: scale(1.1);
            opacity: 0.1;
          }
        }
        @keyframes fadeInUp {
          from {
            opacity: 0;
            transform: translateY(10px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
      `}</style>
    </div>
  );
};

export default FloatingFormButton;