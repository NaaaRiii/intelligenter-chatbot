import React from 'react';

interface ExistingCategorySelectorProps {
  onSelectCategory: (category: string) => void;
}

const ExistingCategorySelector: React.FC<ExistingCategorySelectorProps> = ({ onSelectCategory }) => {
  const categories = [
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
    { value: 'faq', label: 'よくある質問', emoji: '❓', description: 'FAQ・ヘルプセンター' },
  ];

  return (
    <div style={{
      backgroundColor: 'white',
      borderRadius: '0.75rem',
      padding: '1.5rem',
      marginTop: '1rem',
      boxShadow: '0 1px 3px rgba(0, 0, 0, 0.1)'
    }}>
      <h3 style={{ 
        fontSize: '1.1rem', 
        fontWeight: '600', 
        marginBottom: '0.5rem',
        textAlign: 'center',
        color: '#1f2937'
      }}>
        お問い合わせありがとうございます
      </h3>
      <p style={{ 
        fontSize: '0.9rem', 
        color: '#6b7280',
        marginBottom: '1.5rem',
        textAlign: 'center'
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
            onClick={() => onSelectCategory(cat.value)}
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
              e.currentTarget.style.borderColor = '#10b981';
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
              backgroundColor: '#d1fae5',
              borderRadius: '0.5rem',
              flexShrink: 0
            }}>
              {cat.emoji}
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
  );
};

export default ExistingCategorySelector;