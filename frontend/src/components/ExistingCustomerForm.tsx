import React, { useState } from 'react';
import { X, User, Send, Star, Settings, BarChart3, Building, Mail } from 'lucide-react';

interface ExistingCustomerFormProps {
  isVisible: boolean;
  onClose: () => void;
  onSubmit: (formData: FormData, formType: 'support' | 'upgrade' | 'feedback') => void;
  isInline?: boolean;
}

interface FormData {
  customerName: string;
  company: string;
  email: string;
  message: string;
  priority: 'low' | 'medium' | 'high';
  category: string;
}

const ExistingCustomerForm: React.FC<ExistingCustomerFormProps> = ({ 
  isVisible, 
  onClose, 
  onSubmit, 
  isInline = false
}) => {
  const [step, setStep] = useState<'form'>('form');
  const [formType, setFormType] = useState<'support' | 'upgrade' | 'feedback' | null>('support');
  const [formData, setFormData] = useState<FormData>({
    customerName: '',
    company: '',
    email: '',
    message: '',
    priority: 'medium',
    category: 'support'
  });
  const [formErrors, setFormErrors] = useState<Record<string, string>>({});

  const formTypes = {
    support: {
      title: 'サポート依頼',
      description: '技術的な問題やご質問にお答えします',
      icon: Settings,
      color: '#2563eb'
    },
    upgrade: {
      title: 'アップグレード相談',
      description: '上位プランの機能をご検討の方',
      icon: BarChart3,
      color: '#16a34a'
    },
    feedback: {
      title: 'フィードバック',
      description: 'ご意見・ご要望をお聞かせください',
      icon: Star,
      color: '#ea580c'
    }
  };

  // カテゴリ定義は未使用のため削除

  const priorityLevels = {
    low: { label: '低', color: '#10b981', description: '急ぎではない' },
    medium: { label: '中', color: '#f59e0b', description: '通常対応' },
    high: { label: '高', color: '#ef4444', description: '至急対応希望' }
  };

  // フォームタイプ選択/戻るは未使用のため削除

  const validateForm = () => {
    const errors: Record<string, string> = {};
    
    if (!formData.customerName.trim()) errors.customerName = 'お名前を入力してください';
    if (!formData.company.trim()) errors.company = '会社名を入力してください';
    if (!formData.email.trim()) errors.email = 'メールアドレスを入力してください';
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      errors.email = '正しいメールアドレスを入力してください';
    }
    if (!formData.message.trim()) errors.message = 'お問い合わせ内容を入力してください';

    setFormErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (validateForm() && formType) {
      onSubmit(formData, formType);
      onClose();
      // フォームリセット
      setFormData({
        customerName: '',
        company: '',
        email: '',
        message: '',
        priority: 'medium',
        category: 'support'
      });
      setStep('form');
      setFormType('support');
    }
  };

  if (!isVisible) return null;

  const containerStyle = isInline ? {
    width: '100%',
    backgroundColor: 'transparent',
    borderRadius: 0,
    boxShadow: 'none',
    animation: 'none',
    maxHeight: 'none',
    overflow: 'visible'
  } : {
    position: 'fixed' as const,
    bottom: '90px',
    right: '20px',
    width: '400px',
    maxWidth: 'calc(100vw - 40px)',
    backgroundColor: 'white',
    borderRadius: '12px',
    boxShadow: '0 10px 25px rgba(0, 0, 0, 0.15)',
    zIndex: 999,
    animation: 'slideUp 0.3s ease',
    maxHeight: '70vh',
    overflow: 'auto' as const
  };

  return (
    <div style={containerStyle}>
      {/* ヘッダー */}
      <div style={{
        padding: isInline ? '20px' : '20px',
        borderBottom: isInline ? 'none' : '1px solid #e5e7eb',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between'
      }}>
        <h3 style={{
          margin: 0,
          fontSize: '18px',
          fontWeight: '600',
          color: '#1f2937'
        }}>
          サポート依頼
        </h3>
        <button
          onClick={onClose}
          style={{
            background: 'none',
            border: 'none',
            cursor: 'pointer',
            color: '#6b7280',
            padding: '4px'
          }}
        >
          <X size={20} />
        </button>
      </div>

      {/* コンテンツ */}
      <div style={{ padding: '16px' }}>
        {/* フォーム入力 */}
        {step === 'form' && formType && (
          <div>
            <p style={{ 
              margin: '0 0 16px 0', 
              color: '#6b7280', 
              fontSize: '12px',
              textAlign: 'left'
            }}>
              <span style={{ color: '#ef4444' }}>*</span> は必須項目です
            </p>

            <form onSubmit={handleSubmit}>
              {/* お名前 */}
              <div style={{ marginBottom: '12px' }}>
                <label style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                  fontSize: '12px',
                  fontWeight: '500',
                  color: '#374151',
                  marginBottom: '4px'
                }}>
                  <User size={14} />
                  お名前 <span style={{ color: '#ef4444' }}>*</span>
                </label>
                <input
                  type="text"
                  value={formData.customerName}
                  onChange={(e) => setFormData(prev => ({ ...prev, customerName: e.target.value }))}
                  placeholder="山田 太郎"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #d1d5db',
                    borderRadius: '6px',
                    fontSize: '14px',
                    boxSizing: 'border-box'
                  }}
                />
                {formErrors.customerName && (
                  <span style={{ fontSize: '11px', color: '#ef4444', marginTop: '2px', display: 'block' }}>
                    {formErrors.customerName}
                  </span>
                )}
              </div>

              {/* 会社名 */}
              <div style={{ marginBottom: '12px' }}>
                <label style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                  fontSize: '12px',
                  fontWeight: '500',
                  color: '#374151',
                  marginBottom: '4px'
                }}>
                  <Building size={14} />
                  会社名 <span style={{ color: '#ef4444' }}>*</span>
                </label>
                <input
                  type="text"
                  value={formData.company}
                  onChange={(e) => setFormData(prev => ({ ...prev, company: e.target.value }))}
                  placeholder="株式会社サンプル"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #d1d5db',
                    borderRadius: '6px',
                    fontSize: '14px',
                    boxSizing: 'border-box'
                  }}
                />
                {formErrors.company && (
                  <span style={{ fontSize: '11px', color: '#ef4444', marginTop: '2px', display: 'block' }}>
                    {formErrors.company}
                  </span>
                )}
              </div>

              {/* メールアドレス */}
              <div style={{ marginBottom: '12px' }}>
                <label style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                  fontSize: '12px',
                  fontWeight: '500',
                  color: '#374151',
                  marginBottom: '4px'
                }}>
                  <Mail size={14} />
                  メールアドレス <span style={{ color: '#ef4444' }}>*</span>
                </label>
                <input
                  type="email"
                  value={formData.email}
                  onChange={(e) => setFormData(prev => ({ ...prev, email: e.target.value }))}
                  placeholder="sample@example.com"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #d1d5db',
                    borderRadius: '6px',
                    fontSize: '14px',
                    boxSizing: 'border-box'
                  }}
                />
                {formErrors.email && (
                  <span style={{ fontSize: '11px', color: '#ef4444', marginTop: '2px', display: 'block' }}>
                    {formErrors.email}
                  </span>
                )}
              </div>

              {/* 優先度 */}
              <div style={{ marginBottom: '12px' }}>
                <label style={{
                  fontSize: '12px',
                  fontWeight: '500',
                  color: '#374151',
                  marginBottom: '8px',
                  display: 'block'
                }}>
                  緊急度
                </label>
                <div style={{ display: 'flex', gap: '8px' }}>
                  {(Object.keys(priorityLevels) as Array<keyof typeof priorityLevels>).map((level) => {
                    const config = priorityLevels[level];
                    const isSelected = formData.priority === level;
                    return (
                      <button
                        key={level}
                        type="button"
                        onClick={() => setFormData(prev => ({ ...prev, priority: level }))}
                        style={{
                          flex: 1,
                          padding: '8px 12px',
                          border: isSelected ? `2px solid ${config.color}` : '1px solid #d1d5db',
                          borderRadius: '6px',
                          backgroundColor: isSelected ? `${config.color}10` : 'white',
                          color: isSelected ? config.color : '#6b7280',
                          fontSize: '12px',
                          fontWeight: '500',
                          cursor: 'pointer',
                          textAlign: 'center',
                          transition: 'all 0.2s ease'
                        }}
                      >
                        <div>{config.label}</div>
                        <div style={{ fontSize: '10px', marginTop: '2px' }}>
                          {config.description}
                        </div>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* お問い合わせ内容 */}
              <div style={{ marginBottom: '16px' }}>
                <label style={{
                  fontSize: '12px',
                  fontWeight: '500',
                  color: '#374151',
                  marginBottom: '4px',
                  display: 'block'
                }}>
                  お問い合わせ内容 <span style={{ color: '#ef4444' }}>*</span>
                </label>
                <textarea
                  value={formData.message}
                  onChange={(e) => setFormData(prev => ({ ...prev, message: e.target.value }))}
                  placeholder={
                    formType === 'support' ? '発生している問題の詳細をお聞かせください' :
                    formType === 'upgrade' ? 'どのような機能をご希望でしょうか' :
                    'ご意見やご要望をお聞かせください'
                  }
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #d1d5db',
                    borderRadius: '6px',
                    fontSize: '14px',
                    minHeight: '80px',
                    resize: 'vertical',
                    boxSizing: 'border-box'
                  }}
                />
                {formErrors.message && (
                  <span style={{ fontSize: '11px', color: '#ef4444', marginTop: '2px', display: 'block' }}>
                    {formErrors.message}
                  </span>
                )}
              </div>

              <button
                type="submit"
                style={{
                  width: '100%',
                  padding: '12px',
                  backgroundColor: formTypes[formType].color,
                  color: 'white',
                  border: 'none',
                  borderRadius: '6px',
                  fontSize: '14px',
                  fontWeight: '500',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '6px'
                }}
              >
                <Send size={16} />
                送信する
              </button>
            </form>
          </div>
        )}
      </div>

      <style>{`
        @keyframes slideUp {
          from {
            opacity: 0;
            transform: translateY(20px);
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

export default ExistingCustomerForm;