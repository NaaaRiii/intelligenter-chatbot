import React from 'react';

function Chatbot() {
  const [message, setMessage] = React.useState('');
  const [isSubmitted, setIsSubmitted] = React.useState(false);
  const [isLoading, setIsLoading] = React.useState(false);
  const [customerType, setCustomerType] = React.useState<'new' | 'existing' | null>(null);
  const [showCustomerTypeModal, setShowCustomerTypeModal] = React.useState(true);

  const handleSubmit = async () => {
    if (!message.trim()) return;

    setIsLoading(true);
    
    // 送信処理のシミュレーション
    setTimeout(() => {
      setIsSubmitted(true);
      setIsLoading(false);
      setMessage('');
    }, 1000);
  };

  const resetForm = () => {
    setIsSubmitted(false);
    setMessage('');
  };

  const handleCustomerTypeSelect = (type: 'new' | 'existing') => {
    setCustomerType(type);
    setShowCustomerTypeModal(false);
  };

  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#f9fafb', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '1rem' }}>
      {/* 顧客タイプ選択画面（チャット画面の前に表示） */}
      {showCustomerTypeModal ? (
        <div style={{
          backgroundColor: 'white',
          borderRadius: '1rem',
          padding: '2rem',
          maxWidth: '28rem',
          width: '90%',
          boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1)'
        }}>
          <h2 style={{
            fontSize: '1.5rem',
            fontWeight: 'bold',
            marginBottom: '1rem',
            color: '#1f2937'
          }}>
            お問い合わせありがとうございます
          </h2>
          <p style={{
            color: '#6b7280',
            marginBottom: '2rem',
            lineHeight: '1.6'
          }}>
            適切なサポートをご提供するため、ご利用状況をお聞かせください。
          </p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <button
              onClick={() => handleCustomerTypeSelect('new')}
              style={{
                padding: '1rem',
                backgroundColor: '#f3f4f6',
                borderRadius: '0.5rem',
                border: '2px solid transparent',
                cursor: 'pointer',
                textAlign: 'left',
                transition: 'all 0.2s'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.borderColor = '#2563eb';
                e.currentTarget.style.backgroundColor = '#eff6ff';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.borderColor = 'transparent';
                e.currentTarget.style.backgroundColor = '#f3f4f6';
              }}
            >
              <div style={{ fontWeight: '600', marginBottom: '0.25rem', color: '#1f2937' }}>
                初めてのお問い合わせ
              </div>
              <div style={{ fontSize: '0.875rem', color: '#6b7280' }}>
                サービスについて詳しく知りたい方
              </div>
            </button>
            <button
              onClick={() => handleCustomerTypeSelect('existing')}
              style={{
                padding: '1rem',
                backgroundColor: '#f3f4f6',
                borderRadius: '0.5rem',
                border: '2px solid transparent',
                cursor: 'pointer',
                textAlign: 'left',
                transition: 'all 0.2s'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.borderColor = '#2563eb';
                e.currentTarget.style.backgroundColor = '#eff6ff';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.borderColor = 'transparent';
                e.currentTarget.style.backgroundColor = '#f3f4f6';
              }}
            >
              <div style={{ fontWeight: '600', marginBottom: '0.25rem', color: '#1f2937' }}>
                既にご契約・お取引がある
              </div>
              <div style={{ fontSize: '0.875rem', color: '#6b7280' }}>
                ご契約中のサービスについてのお問い合わせ
              </div>
            </button>
          </div>
        </div>
      ) : (
        <div style={{ width: '100%', maxWidth: '42rem', backgroundColor: 'white', borderRadius: '1rem', boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.1)', overflow: 'hidden' }}>
        {/* ヘッダー */}
        <div style={{ background: 'linear-gradient(to right, #2563eb, #1d4ed8)', color: 'white', padding: '1.5rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div>
              <h1 style={{ fontSize: '1.5rem', fontWeight: 'bold', margin: 0 }}>お問い合わせサポート</h1>
              <p style={{ margin: '0.25rem 0 0 0', opacity: 0.9 }}>マーケティング×システムのプロ集団がサポートします</p>
            </div>
            {customerType && !showCustomerTypeModal && (
              <div style={{
                backgroundColor: 'rgba(255, 255, 255, 0.2)',
                padding: '0.5rem 1rem',
                borderRadius: '0.5rem',
                fontSize: '0.875rem',
                fontWeight: '500'
              }}>
                {customerType === 'new' ? '新規お客様' : '既存のお客様'}
              </div>
            )}
          </div>
        </div>

        <div style={{ padding: '2rem' }}>
          {!isSubmitted ? (
            <>
              {/* よくあるお問い合わせボタン */}
              <div style={{ marginBottom: '2rem' }}>
                <button
                  onClick={() => console.log('FAQページへ遷移')}
                  style={{ 
                    width: '100%', 
                    backgroundColor: '#f3f4f6', 
                    color: '#374151', 
                    fontWeight: '500', 
                    padding: '1rem 1.5rem', 
                    borderRadius: '0.5rem', 
                    border: '1px solid #e5e7eb',
                    cursor: 'pointer',
                    transition: 'background-color 0.2s'
                  }}
                  onMouseOver={(e) => e.currentTarget.style.backgroundColor = '#e5e7eb'}
                  onMouseOut={(e) => e.currentTarget.style.backgroundColor = '#f3f4f6'}
                >
                  よくあるお問い合わせ
                </button>
              </div>

              {/* 見出し */}
              <div style={{ marginBottom: '1.5rem' }}>
                <h2 style={{ fontSize: '1.25rem', fontWeight: '600', color: '#1f2937', margin: '0 0 0.5rem 0' }}>
                  ご用件をお伺いします
                </h2>
                <p style={{ color: '#6b7280', margin: 0 }}>
                  お困りのことやご相談内容を詳しくお聞かせください。専門スタッフが対応いたします。
                </p>
              </div>

              {/* 入力フォーム */}
              <div>
                <div>
                  <textarea
                    value={message}
                    onChange={(e) => setMessage(e.target.value)}
                    placeholder="こちらにご用件をご入力ください..."
                    style={{
                      width: '100%',
                      padding: '1rem',
                      border: '1px solid #d1d5db',
                      borderRadius: '0.5rem',
                      resize: 'none',
                      height: '8rem',
                      fontSize: '1rem',
                      fontFamily: 'inherit',
                      boxSizing: 'border-box'
                    }}
                  />
                  
                  {/* お問い合わせボタン */}
                  <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '1rem' }}>
                    <button
                      onClick={handleSubmit}
                      disabled={isLoading || !message.trim()}
                      style={{
                        backgroundColor: '#2563eb',
                        color: 'white',
                        fontWeight: '500',
                        padding: '0.75rem 2rem',
                        borderRadius: '0.5rem',
                        border: 'none',
                        cursor: message.trim() && !isLoading ? 'pointer' : 'not-allowed',
                        opacity: message.trim() && !isLoading ? 1 : 0.5,
                        display: 'flex',
                        alignItems: 'center',
                        gap: '0.5rem',
                        fontSize: '1rem'
                      }}
                    >
                      {isLoading ? '送信中...' : 'お問い合わせ'}
                    </button>
                  </div>
                </div>
              </div>
            </>
          ) : (
            /* 送信完了メッセージ */
            <div style={{ textAlign: 'center', padding: '2rem' }}>
              <div style={{ 
                width: '4rem', 
                height: '4rem', 
                backgroundColor: '#d1fae5', 
                borderRadius: '50%', 
                display: 'flex', 
                alignItems: 'center', 
                justifyContent: 'center', 
                margin: '0 auto 1.5rem' 
              }}>
                <svg style={{ width: '2rem', height: '2rem', color: '#10b981' }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
              </div>
              
              <h3 style={{ fontSize: '1.5rem', fontWeight: '600', color: '#1f2937', margin: '0 0 1rem 0' }}>
                お問い合わせを受け付けました
              </h3>
              
              <p style={{ color: '#6b7280', marginBottom: '2rem', lineHeight: '1.75' }}>
                ご回答にお時間を頂戴いたします。<br />
                通常1営業日以内にご連絡いたします。<br />
                ご了承ください。
              </p>
              
              <button
                onClick={resetForm}
                style={{
                  backgroundColor: '#2563eb',
                  color: 'white',
                  fontWeight: '500',
                  padding: '0.75rem 2rem',
                  borderRadius: '0.5rem',
                  border: 'none',
                  cursor: 'pointer',
                  fontSize: '1rem'
                }}
              >
                新しいお問い合わせ
              </button>
            </div>
          )}
        </div>

        {/* フッター */}
        <div style={{ backgroundColor: '#f9fafb', padding: '1rem 2rem', borderTop: '1px solid #e5e7eb' }}>
          <p style={{ fontSize: '0.875rem', color: '#6b7280', textAlign: 'center', margin: 0 }}>
            お急ぎの場合は、お電話（03-XXXX-XXXX）でもお受けしております
          </p>
        </div>
      </div>
      )}
    </div>
  );
}

export default Chatbot;