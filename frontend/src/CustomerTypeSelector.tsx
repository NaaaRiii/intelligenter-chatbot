import React from 'react';
import { MessageCircle, UserPlus, Building2 } from 'lucide-react';

interface CustomerTypeSelectorProps {
  onSelect: (type: 'new' | 'existing') => void;
}

const CustomerTypeSelector: React.FC<CustomerTypeSelectorProps> = ({ onSelect }) => {
  return (
    <div style={{ 
      minHeight: '100vh', 
      backgroundColor: '#f9fafb', 
      display: 'flex', 
      alignItems: 'center', 
      justifyContent: 'center', 
      padding: '1rem' 
    }}>
      <div style={{ 
        width: '100%', 
        maxWidth: '32rem', 
        backgroundColor: 'white', 
        borderRadius: '1rem', 
        boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.1)', 
        overflow: 'hidden' 
      }}>
        {/* ヘッダー */}
        <div style={{ 
          background: 'linear-gradient(to right, #2563eb, #1d4ed8)', 
          color: 'white', 
          padding: '2rem',
          textAlign: 'center'
        }}>
          <div style={{ display: 'flex', justifyContent: 'center', marginBottom: '1rem' }}>
            <MessageCircle size={48} />
          </div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 'bold', margin: '0 0 0.5rem 0' }}>
            お問い合わせサポート
          </h1>
          <p style={{ margin: 0, opacity: 0.9 }}>
            マーケティング×システムのプロ集団がサポートします
          </p>
        </div>

        {/* 選択エリア */}
        <div style={{ padding: '2rem' }}>
          <div style={{ marginBottom: '2rem', textAlign: 'center' }}>
            <h2 style={{ 
              fontSize: '1.25rem', 
              fontWeight: '600', 
              color: '#1f2937', 
              margin: '0 0 0.75rem 0' 
            }}>
              お問い合わせありがとうございます
            </h2>
            <p style={{ 
              color: '#6b7280', 
              margin: 0,
              lineHeight: 1.6
            }}>
              適切なサポートをご提供するため、<br />
              ご利用状況をお聞かせください
            </p>
          </div>

          {/* 選択ボタン */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            {/* 新規のお客様 */}
            <button
              onClick={() => onSelect('new')}
              style={{
                display: 'flex',
                alignItems: 'center',
                padding: '1.5rem',
                backgroundColor: 'white',
                border: '2px solid #e5e7eb',
                borderRadius: '0.75rem',
                cursor: 'pointer',
                transition: 'all 0.2s',
                textAlign: 'left'
              }}
              onMouseOver={(e) => {
                e.currentTarget.style.borderColor = '#2563eb';
                e.currentTarget.style.backgroundColor = '#eff6ff';
              }}
              onMouseOut={(e) => {
                e.currentTarget.style.borderColor = '#e5e7eb';
                e.currentTarget.style.backgroundColor = 'white';
              }}
            >
              <div style={{
                width: '3rem',
                height: '3rem',
                backgroundColor: '#dbeafe',
                borderRadius: '0.5rem',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                marginRight: '1rem',
                flexShrink: 0
              }}>
                <UserPlus size={24} color="#2563eb" />
              </div>
              <div>
                <div style={{
                  fontSize: '1.125rem',
                  fontWeight: '600',
                  color: '#1f2937',
                  marginBottom: '0.25rem'
                }}>
                  初めてのお問い合わせ
                </div>
                <div style={{
                  fontSize: '0.875rem',
                  color: '#6b7280'
                }}>
                  サービスについて詳しくご説明いたします
                </div>
              </div>
            </button>

            {/* 既存のお客様 */}
            <button
              onClick={() => onSelect('existing')}
              style={{
                display: 'flex',
                alignItems: 'center',
                padding: '1.5rem',
                backgroundColor: 'white',
                border: '2px solid #e5e7eb',
                borderRadius: '0.75rem',
                cursor: 'pointer',
                transition: 'all 0.2s',
                textAlign: 'left'
              }}
              onMouseOver={(e) => {
                e.currentTarget.style.borderColor = '#2563eb';
                e.currentTarget.style.backgroundColor = '#eff6ff';
              }}
              onMouseOut={(e) => {
                e.currentTarget.style.borderColor = '#e5e7eb';
                e.currentTarget.style.backgroundColor = 'white';
              }}
            >
              <div style={{
                width: '3rem',
                height: '3rem',
                backgroundColor: '#dcfce7',
                borderRadius: '0.5rem',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                marginRight: '1rem',
                flexShrink: 0
              }}>
                <Building2 size={24} color="#16a34a" />
              </div>
              <div>
                <div style={{
                  fontSize: '1.125rem',
                  fontWeight: '600',
                  color: '#1f2937',
                  marginBottom: '0.25rem'
                }}>
                  既にご契約・お取引がある
                </div>
                <div style={{
                  fontSize: '0.875rem',
                  color: '#6b7280'
                }}>
                  ご契約内容に基づいたサポートをいたします
                </div>
              </div>
            </button>
          </div>
        </div>

        {/* フッター */}
        <div style={{ 
          backgroundColor: '#f9fafb', 
          padding: '1rem 2rem', 
          borderTop: '1px solid #e5e7eb' 
        }}>
          <p style={{ 
            fontSize: '0.75rem', 
            color: '#9ca3af', 
            textAlign: 'center', 
            margin: 0 
          }}>
            営業時間: 平日 9:00-18:00 | お急ぎの場合はお電話でも承ります
          </p>
        </div>
      </div>
    </div>
  );
};

export default CustomerTypeSelector;