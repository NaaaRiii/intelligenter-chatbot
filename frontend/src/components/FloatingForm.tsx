import React, { useState } from 'react';
import { X, User, Building, Mail, Phone, MessageCircle, Send } from 'lucide-react';

interface FloatingFormProps {
  isVisible: boolean;
  onClose: () => void;
  onSubmit: (formData: FormData, formType: 'diagnosis' | 'support') => void;
  selectedCategory: string | null;
  isInline?: boolean; // インライン表示かどうか
}

interface FormData {
  name: string;
  company: string;
  email: string;
  phone: string;
  message: string;
  category: string;
}

const FloatingForm: React.FC<FloatingFormProps> = ({ 
  isVisible, 
  onClose, 
  onSubmit, 
  selectedCategory,
  isInline = false
}) => {
  const [step, setStep] = useState<'category' | 'form_type' | 'form'>('form');
  const [selectedFormCategory, setSelectedFormCategory] = useState<string | null>('consultation');
  const [formType, setFormType] = useState<'diagnosis' | 'support' | null>('diagnosis');
  const [formData, setFormData] = useState<FormData>({
    name: '',
    company: '',
    email: '',
    phone: '',
    message: '',
    category: 'consultation'
  });
  const [formErrors, setFormErrors] = useState<Record<string, string>>({});

  const categories = {
    service: 'サービス概要・能力範囲',
    tech: '技術・システム関連',
    marketing: 'マーケティング戦略',
    project: 'プロジェクト進行・体制',
    cost: '費用・契約',
    case: '実績・事例',
    consultation: '初回相談・問い合わせ'
  };

  const handleCategorySelect = (category: string) => {
    setSelectedFormCategory(category);
    setFormData(prev => ({ ...prev, category }));
    setStep('form_type');
  };

  const handleFormTypeSelect = (type: 'diagnosis' | 'support') => {
    setFormType(type);
    // デフォルトカテゴリーを設定
    if (!selectedFormCategory) {
      setSelectedFormCategory('consultation');
      setFormData(prev => ({ ...prev, category: 'consultation' }));
    }
    setStep('form');
  };

  const handleBackToCategory = () => {
    setStep('category');
    setSelectedFormCategory(null);
    setFormType(null);
  };

  const handleBackToFormType = () => {
    setStep('form_type');
    setFormType(null);
  };

  const validateForm = () => {
    const errors: Record<string, string> = {};
    
    if (!formData.name.trim()) errors.name = 'お名前を入力してください';
    if (!formData.company.trim()) errors.company = '会社名を入力してください';
    if (!formData.email.trim()) errors.email = 'メールアドレスを入力してください';
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      errors.email = '正しいメールアドレスを入力してください';
    }
    if (!formData.message.trim()) errors.message = 'ご相談内容を入力してください';

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
        name: '',
        company: '',
        email: '',
        phone: '',
        message: '',
        category: 'consultation'
      });
      setStep('form');
      setSelectedFormCategory('consultation');
      setFormType('diagnosis');
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
        padding: isInline ? '0 0 16px 0' : '16px',
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
          無料診断のお申し込み
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
        {step === 'form' && (
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
                  value={formData.name}
                  onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
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
                {formErrors.name && (
                  <span style={{ fontSize: '11px', color: '#ef4444', marginTop: '2px', display: 'block' }}>
                    {formErrors.name}
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

              {/* 電話番号 */}
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
                  <Phone size={14} />
                  電話番号
                </label>
                <input
                  type="tel"
                  value={formData.phone}
                  onChange={(e) => setFormData(prev => ({ ...prev, phone: e.target.value }))}
                  placeholder="03-1234-5678"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #d1d5db',
                    borderRadius: '6px',
                    fontSize: '14px',
                    boxSizing: 'border-box'
                  }}
                />
              </div>

              {/* ご相談内容 */}
              <div style={{ marginBottom: '16px' }}>
                <label style={{
                  fontSize: '12px',
                  fontWeight: '500',
                  color: '#374151',
                  marginBottom: '4px',
                  display: 'block'
                }}>
                  ご相談内容 <span style={{ color: '#ef4444' }}>*</span>
                </label>
                <textarea
                  value={formData.message}
                  onChange={(e) => setFormData(prev => ({ ...prev, message: e.target.value }))}
                  placeholder="具体的なご相談内容をお聞かせください"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #d1d5db',
                    borderRadius: '6px',
                    fontSize: '14px',
                    minHeight: '60px',
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
                  padding: '10px',
                  backgroundColor: '#2563eb',
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
                無料診断を申し込む
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

export default FloatingForm;