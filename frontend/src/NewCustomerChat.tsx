import React, { useState, useEffect } from 'react';
import { Send, MessageCircle, User, Mail, Building, Phone } from 'lucide-react';
import CategorySelector from './CategorySelector';
import { generateAIResponse } from './companyKnowledge';

interface Message {
  id: number;
  text: string;
  sender: 'user' | 'bot';
  timestamp: Date;
  category?: string;
}

const NewCustomerChat: React.FC = () => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const [showCategorySelector, setShowCategorySelector] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [showContactForm, setShowContactForm] = useState(false);
  const [messageCount, setMessageCount] = useState(0);
  const [contactForm, setContactForm] = useState({
    name: '',
    company: '',
    email: '',
    phone: '',
    message: ''
  });
  const [formErrors, setFormErrors] = useState({
    name: '',
    company: '',
    email: '',
    message: ''
  });

  const categoryNames: { [key: string]: string } = {
    service: 'サービス概要・能力範囲',
    tech: '技術・システム関連',
    marketing: 'マーケティング戦略',
    project: 'プロジェクト進行・体制',
    cost: '費用・契約',
    case: '実績・事例',
    consultation: '初回相談・問い合わせ'
  };

  const categoryResponses: { [key: string]: string[] } = {
    service: [
      'サービス概要についてご質問ですね。弊社はマーケティング戦略の立案からシステム開発まで、ワンストップでご提供しております。',
      '【サービス概要】\n・マーケティング戦略立案：市場分析、競合分析、ターゲット設定\n・システム開発：Webアプリ、モバイルアプリ、業務システム\n・デジタルマーケティング：SEO対策、広告運用、SNS運用\n\n【能力範囲】\n・企画から実装、運用まで一貫したサポート\n・AIを活用した効率的なソリューション\n・業界特化型のカスタマイズ対応',
      'お客様の現在の課題や、どのようなサービスをお探しでしょうか？具体的にお聞かせいただければ、最適なプランをご提案させていただきます。'
    ],
    tech: [
      '技術・システムについてのご質問ですね。弊社は最新技術を活用したシステム開発を得意としています。',
      '【対応技術】\n・フロントエンド：React, Vue.js, Next.js\n・バックエンド：Ruby on Rails, Node.js, Python\n・クラウド：AWS, Google Cloud, Azure\n・AI/ML：ChatGPT API, Claude API, 機械学習モデル構築\n\n【開発実績】\n・ECサイト構築\n・業務効率化システム\n・AIチャットボット',
      'どのようなシステムの開発をご検討されていますか？既存システムとの連携など、具体的な要件をお聞かせください。'
    ],
    marketing: [
      'マーケティング戦略についてご興味をお持ちいただきありがとうございます。',
      '【マーケティングサービス】\n・デジタルマーケティング戦略立案\n・SEO対策・コンテンツマーケティング\n・リスティング広告・SNS広告運用\n・MA/CRMツール導入支援\n\n【分析・改善】\n・アクセス解析・CVR改善\n・A/Bテスト実施\n・KPI設定と効果測定',
      'どのような商品・サービスのマーケティングをお考えですか？ターゲット層や現在の課題をお聞かせください。'
    ],
    project: [
      'プロジェクトの進め方についてご説明いたします。',
      '【プロジェクト進行】\n1. ヒアリング・要件定義（1-2週間）\n2. 提案・見積もり（1週間）\n3. 設計・デザイン（2-4週間）\n4. 開発・実装（1-3ヶ月）\n5. テスト・納品（2週間）\n\n【体制】\n・専任PM配置\n・週次進捗報告\n・チャットツールでの随時連絡',
      'プロジェクトの規模感や希望納期はございますか？お客様のご要望に合わせて体制を組ませていただきます。'
    ],
    cost: [
      '費用・契約についてご質問ですね。',
      '【料金体系】\n・初期開発費：要件により個別見積もり\n・月額保守費：初期費用の10-15%程度\n・スポット対応：時間単価制\n\n【契約形態】\n・請負契約\n・準委任契約（SES）\n・月額サブスクリプション\n\n【お支払い】\n・分割払い対応可\n・着手金30%、納品時70%',
      'ご予算の規模感はお決まりでしょうか？まずは無料でお見積もりをさせていただきますので、ご要望をお聞かせください。'
    ],
    case: [
      '実績・事例についてご興味をお持ちいただきありがとうございます。',
      '【導入事例】\n・小売業A社：ECサイト構築でCVR200%向上\n・製造業B社：業務システムで作業時間50%削減\n・サービス業C社：AIチャットボットで問い合わせ対応80%自動化\n\n【対応業界】\n・小売・EC\n・製造・物流\n・金融・不動産\n・医療・ヘルスケア',
      'どちらの業界の事例にご興味がございますか？類似事例の詳細をご案内させていただきます。'
    ],
    consultation: [
      '初回相談についてご案内いたします。',
      '【無料相談の内容】\n・課題のヒアリング（30-60分）\n・解決策のご提案\n・概算見積もりのご提示\n・今後の進め方のご相談\n\n【相談方法】\n・オンライン面談（Zoom, Teams等）\n・訪問面談（首都圏エリア）\n・メール・チャットでの相談',
      'まずはお気軽にご相談ください。いつ頃のご相談をご希望でしょうか？オンライン・対面どちらをご希望ですか？'
    ]
  };

  // 初回アクセス時の段階的表示
  useEffect(() => {
    // 0.5秒後にボットの挨拶メッセージを表示
    setTimeout(() => {
      const welcomeMessage: Message = {
        id: 1,
        text: 'こんにちは！お問い合わせありがとうございます。どのようなご用件でしょうか？',
        sender: 'bot',
        timestamp: new Date()
      };
      setMessages([welcomeMessage]);
      setIsLoading(false);
      
      // さらに0.2秒後にカテゴリー選択を表示
      setTimeout(() => {
        setShowCategorySelector(true);
      }, 200);
    }, 500);
  }, []);

  const handleCategorySelect = (category: string) => {
    setSelectedCategory(category);
    setShowCategorySelector(false);
    
    // カテゴリー選択のメッセージを追加
    const userMessage: Message = {
      id: messages.length + 1,
      text: `「${categoryNames[category]}」について聞きたい`,
      sender: 'user',
      timestamp: new Date(),
      category
    };
    
    setMessages(prev => [...prev, userMessage]);
    
    // ボットの応答を段階的に追加
    const responses = categoryResponses[category];
    let messageId = messages.length + 2;
    
    // 最初の応答（1秒後）
    setIsLoading(true);
    setTimeout(() => {
      const firstMessage: Message = {
        id: messageId++,
        text: responses[0],
        sender: 'bot',
        timestamp: new Date()
      };
      setMessages(prev => [...prev, firstMessage]);
      setIsLoading(false);
      
      // 詳細説明（さらに1.5秒後）
      setIsLoading(true);
      setTimeout(() => {
        const detailMessage: Message = {
          id: messageId++,
          text: responses[1],
          sender: 'bot',
          timestamp: new Date()
        };
        setMessages(prev => [...prev, detailMessage]);
        setIsLoading(false);
        
        // 質問（さらに1秒後）
        setIsLoading(true);
        setTimeout(() => {
          const questionMessage: Message = {
            id: messageId++,
            text: responses[2],
            sender: 'bot',
            timestamp: new Date()
          };
          setMessages(prev => [...prev, questionMessage]);
          setIsLoading(false);
        }, 1000);
      }, 1500);
    }, 1000);
  };

  const handleSendMessage = () => {
    if (!inputMessage.trim()) return;

    const userMessage: Message = {
      id: messages.length + 1,
      text: inputMessage,
      sender: 'user',
      timestamp: new Date()
    };

    setMessages(prev => [...prev, userMessage]);
    setInputMessage('');
    setIsLoading(true);

    // AI応答を生成
    setTimeout(() => {
      // 知識ベースを使用してAI応答を生成
      const response = selectedCategory 
        ? generateAIResponse(inputMessage, selectedCategory, messageCount)
        : { message: 'ご質問ありがとうございます。詳しくお答えさせていただきます。', showForm: false };
      
      const botMessage: Message = {
        id: messages.length + 2,
        text: response.message,
        sender: 'bot',
        timestamp: new Date()
      };
      setMessages(prev => [...prev, botMessage]);
      setIsLoading(false);
      setMessageCount(prev => prev + 1);
      
      // 依頼フォームを表示するか判定
      if (response.showForm) {
        setTimeout(() => {
          setShowContactForm(true);
        }, 500);
      }
    }, 1500);
  };

  const handleContactSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    // バリデーション
    const errors = {
      name: '',
      company: '',
      email: '',
      message: ''
    };
    
    if (!contactForm.name.trim()) {
      errors.name = 'お名前を入力してください';
    }
    if (!contactForm.company.trim()) {
      errors.company = '会社名を入力してください';
    }
    if (!contactForm.email.trim()) {
      errors.email = 'メールアドレスを入力してください';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contactForm.email)) {
      errors.email = '正しいメールアドレスを入力してください';
    }
    if (!contactForm.message.trim()) {
      errors.message = 'ご相談内容を入力してください';
    }
    
    // エラーがある場合は処理を中断
    if (errors.name || errors.company || errors.email || errors.message) {
      setFormErrors(errors);
      return;
    }
    
    // エラーをクリア
    setFormErrors({ name: '', company: '', email: '', message: '' });
    
    // フォームを非表示
    setShowContactForm(false);
    
    // 送信完了メッセージを表示
    const thankYouMessage: Message = {
      id: messages.length + 1,
      text: `ご依頼ありがとうございます。

【受付完了】
お名前：${contactForm.name}様
会社名：${contactForm.company}
メール：${contactForm.email}

2営業日以内に、ご指定のメールアドレス宛に
担当者よりご連絡させていただきます。

今後ともDataPro Solutionsをよろしくお願いいたします。`,
      sender: 'bot',
      timestamp: new Date()
    };
    setMessages(prev => [...prev, thankYouMessage]);
    
    // フォームをリセット
    setContactForm({
      name: '',
      company: '',
      email: '',
      phone: '',
      message: ''
    });
  };

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      height: '100vh',
      backgroundColor: '#f9fafb'
    }}>
      {/* ヘッダー */}
      <div style={{
        backgroundColor: 'white',
        borderBottom: '1px solid #e5e7eb',
        padding: '1rem',
        boxShadow: '0 1px 3px rgba(0, 0, 0, 0.1)'
      }}>
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '0.75rem',
          maxWidth: '48rem',
          margin: '0 auto'
        }}>
          <MessageCircle size={24} color="#2563eb" />
          <div>
            <h2 style={{
              fontSize: '1.125rem',
              fontWeight: '600',
              color: '#1f2937',
              margin: 0
            }}>
              カスタマーサポート
            </h2>
            <p style={{
              fontSize: '0.75rem',
              color: '#6b7280',
              margin: 0
            }}>
              マーケティング×システムのプロ集団がサポートします
            </p>
          </div>
        </div>
      </div>

      {/* メッセージエリア */}
      <div style={{
        flex: 1,
        overflowY: 'auto',
        padding: '1rem'
      }}>
        <div style={{
          maxWidth: '48rem',
          margin: '0 auto'
        }}>
          {/* メッセージ表示 */}
          {messages.map(message => (
            <div
              key={message.id}
              style={{
                display: 'flex',
                justifyContent: message.sender === 'user' ? 'flex-end' : 'flex-start',
                marginBottom: '1rem'
              }}
            >
              <div style={{
                maxWidth: '70%',
                padding: '0.75rem 1rem',
                borderRadius: '0.75rem',
                backgroundColor: message.sender === 'user' ? '#2563eb' : 'white',
                color: message.sender === 'user' ? 'white' : '#1f2937',
                boxShadow: '0 1px 3px rgba(0, 0, 0, 0.1)'
              }}>
                {message.category && message.sender === 'user' && (
                  <div style={{
                    fontSize: '0.75rem',
                    opacity: 0.8,
                    marginBottom: '0.25rem'
                  }}>
                    📁 カテゴリー選択
                  </div>
                )}
                <div style={{ whiteSpace: 'pre-wrap' }}>{message.text}</div>
                <div style={{
                  fontSize: '0.75rem',
                  opacity: 0.7,
                  marginTop: '0.25rem'
                }}>
                  {message.timestamp.toLocaleTimeString('ja-JP', {
                    hour: '2-digit',
                    minute: '2-digit'
                  })}
                </div>
              </div>
            </div>
          ))}

          {/* ローディング表示 */}
          {isLoading && (
            <div style={{
              display: 'flex',
              justifyContent: 'flex-start',
              marginBottom: '1rem'
            }}>
              <div style={{
                padding: '0.75rem 1rem',
                borderRadius: '0.75rem',
                backgroundColor: 'white',
                boxShadow: '0 1px 3px rgba(0, 0, 0, 0.1)'
              }}>
                <div style={{ display: 'flex', gap: '0.25rem' }}>
                  <span style={{ animation: 'bounce 1.4s infinite ease-in-out' }}>●</span>
                  <span style={{ animation: 'bounce 1.4s infinite ease-in-out 0.2s' }}>●</span>
                  <span style={{ animation: 'bounce 1.4s infinite ease-in-out 0.4s' }}>●</span>
                </div>
              </div>
            </div>
          )}

          {/* カテゴリー選択 */}
          {showCategorySelector && !selectedCategory && (
            <div style={{ 
              animation: 'fadeIn 0.3s ease-in',
              opacity: 1
            }}>
              <CategorySelector onSelect={handleCategorySelect} />
            </div>
          )}
          
          {/* 依頼フォーム */}
          {showContactForm && (
            <div style={{
              animation: 'fadeIn 0.3s ease-in',
              backgroundColor: 'white',
              borderRadius: '0.75rem',
              padding: '1.5rem',
              marginTop: '1rem',
              boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
            }}>
              <h3 style={{ 
                fontSize: '1.1rem', 
                fontWeight: 'bold',
                marginBottom: '0.5rem',
                color: '#1f2937'
              }}>
                無料診断のお申し込み
              </h3>
              <p style={{
                fontSize: '0.75rem',
                color: '#ef4444',
                marginBottom: '1rem'
              }}>
                <span style={{ color: '#ef4444' }}>*</span> は必須入力項目です
              </p>
              <form onSubmit={handleContactSubmit}>
                <div style={{ marginBottom: '1rem' }}>
                  <label style={{ 
                    display: 'flex', 
                    alignItems: 'center',
                    gap: '0.5rem',
                    fontSize: '0.875rem',
                    fontWeight: '500',
                    color: '#374151',
                    marginBottom: '0.25rem'
                  }}>
                    <User size={16} />
                    お名前 <span style={{ color: '#ef4444' }}>*</span>
                  </label>
                  <input
                    type="text"
                    required
                    value={contactForm.name}
                    onChange={(e) => setContactForm({...contactForm, name: e.target.value})}
                    style={{
                      width: '100%',
                      padding: '0.5rem',
                      border: '1px solid #d1d5db',
                      borderRadius: '0.375rem',
                      fontSize: '0.875rem'
                    }}
                    placeholder="山田 太郎"
                  />
                  {formErrors.name && (
                    <span style={{
                      fontSize: '0.75rem',
                      color: '#ef4444',
                      marginTop: '0.25rem',
                      display: 'block'
                    }}>
                      {formErrors.name}
                    </span>
                  )}
                </div>
                
                <div style={{ marginBottom: '1rem' }}>
                  <label style={{ 
                    display: 'flex', 
                    alignItems: 'center',
                    gap: '0.5rem',
                    fontSize: '0.875rem',
                    fontWeight: '500',
                    color: '#374151',
                    marginBottom: '0.25rem'
                  }}>
                    <Building size={16} />
                    会社名 <span style={{ color: '#ef4444' }}>*</span>
                  </label>
                  <input
                    type="text"
                    required
                    value={contactForm.company}
                    onChange={(e) => setContactForm({...contactForm, company: e.target.value})}
                    style={{
                      width: '100%',
                      padding: '0.5rem',
                      border: '1px solid #d1d5db',
                      borderRadius: '0.375rem',
                      fontSize: '0.875rem'
                    }}
                    placeholder="株式会社サンプル"
                  />
                  {formErrors.company && (
                    <span style={{
                      fontSize: '0.75rem',
                      color: '#ef4444',
                      marginTop: '0.25rem',
                      display: 'block'
                    }}>
                      {formErrors.company}
                    </span>
                  )}
                </div>
                
                <div style={{ marginBottom: '1rem' }}>
                  <label style={{ 
                    display: 'flex', 
                    alignItems: 'center',
                    gap: '0.5rem',
                    fontSize: '0.875rem',
                    fontWeight: '500',
                    color: '#374151',
                    marginBottom: '0.25rem'
                  }}>
                    <Mail size={16} />
                    メールアドレス <span style={{ color: '#ef4444' }}>*</span>
                  </label>
                  <input
                    type="email"
                    required
                    value={contactForm.email}
                    onChange={(e) => setContactForm({...contactForm, email: e.target.value})}
                    style={{
                      width: '100%',
                      padding: '0.5rem',
                      border: '1px solid #d1d5db',
                      borderRadius: '0.375rem',
                      fontSize: '0.875rem'
                    }}
                    placeholder="sample@example.com"
                  />
                  {formErrors.email && (
                    <span style={{
                      fontSize: '0.75rem',
                      color: '#ef4444',
                      marginTop: '0.25rem',
                      display: 'block'
                    }}>
                      {formErrors.email}
                    </span>
                  )}
                </div>
                
                <div style={{ marginBottom: '1rem' }}>
                  <label style={{ 
                    display: 'flex', 
                    alignItems: 'center',
                    gap: '0.5rem',
                    fontSize: '0.875rem',
                    fontWeight: '500',
                    color: '#374151',
                    marginBottom: '0.25rem'
                  }}>
                    <Phone size={16} />
                    電話番号
                  </label>
                  <input
                    type="tel"
                    value={contactForm.phone}
                    onChange={(e) => setContactForm({...contactForm, phone: e.target.value})}
                    style={{
                      width: '100%',
                      padding: '0.5rem',
                      border: '1px solid #d1d5db',
                      borderRadius: '0.375rem',
                      fontSize: '0.875rem'
                    }}
                    placeholder="03-1234-5678"
                  />
                </div>
                
                <div style={{ marginBottom: '1rem' }}>
                  <label style={{ 
                    fontSize: '0.875rem',
                    fontWeight: '500',
                    color: '#374151',
                    marginBottom: '0.25rem',
                    display: 'block'
                  }}>
                    ご相談内容 <span style={{ color: '#ef4444' }}>*</span>
                  </label>
                  <textarea
                    required
                    value={contactForm.message}
                    onChange={(e) => setContactForm({...contactForm, message: e.target.value})}
                    style={{
                      width: '100%',
                      padding: '0.5rem',
                      border: '1px solid #d1d5db',
                      borderRadius: '0.375rem',
                      fontSize: '0.875rem',
                      minHeight: '80px',
                      resize: 'vertical'
                    }}
                    placeholder="具体的なご相談内容をお聞かせください"
                  />
                  {formErrors.message && (
                    <span style={{
                      fontSize: '0.75rem',
                      color: '#ef4444',
                      marginTop: '0.25rem',
                      display: 'block'
                    }}>
                      {formErrors.message}
                    </span>
                  )}
                </div>
                
                <button
                  type="submit"
                  style={{
                    width: '100%',
                    padding: '0.75rem',
                    backgroundColor: '#2563eb',
                    color: 'white',
                    border: 'none',
                    borderRadius: '0.375rem',
                    fontSize: '0.875rem',
                    fontWeight: '500',
                    cursor: 'pointer',
                    transition: 'background-color 0.2s'
                  }}
                  onMouseOver={(e) => e.currentTarget.style.backgroundColor = '#1d4ed8'}
                  onMouseOut={(e) => e.currentTarget.style.backgroundColor = '#2563eb'}
                >
                  無料診断を申し込む
                </button>
              </form>
            </div>
          )}
        </div>
      </div>

      {/* 入力エリア */}
      <div style={{
        backgroundColor: 'white',
        borderTop: '1px solid #e5e7eb',
        padding: '1rem'
      }}>
        <div style={{
          maxWidth: '48rem',
          margin: '0 auto',
          display: 'flex',
          gap: '0.75rem'
        }}>
          <input
            type="text"
            value={inputMessage}
            onChange={(e) => setInputMessage(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
            placeholder={selectedCategory ? "メッセージを入力..." : "まずはカテゴリーをお選びください"}
            disabled={!selectedCategory}
            style={{
              flex: 1,
              padding: '0.75rem',
              borderRadius: '0.5rem',
              border: '1px solid #e5e7eb',
              fontSize: '0.875rem',
              outline: 'none',
              opacity: selectedCategory ? 1 : 0.5
            }}
          />
          <button
            onClick={handleSendMessage}
            disabled={!inputMessage.trim() || !selectedCategory}
            style={{
              padding: '0.75rem 1.5rem',
              backgroundColor: inputMessage.trim() && selectedCategory ? '#2563eb' : '#e5e7eb',
              color: inputMessage.trim() && selectedCategory ? 'white' : '#9ca3af',
              borderRadius: '0.5rem',
              border: 'none',
              cursor: inputMessage.trim() && selectedCategory ? 'pointer' : 'not-allowed',
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
              transition: 'all 0.2s'
            }}
          >
            <Send size={18} />
            送信
          </button>
        </div>
      </div>

      <style>{`
        @keyframes bounce {
          0%, 60%, 100% {
            transform: translateY(0);
          }
          30% {
            transform: translateY(-10px);
          }
        }
        @keyframes fadeIn {
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

export default NewCustomerChat;