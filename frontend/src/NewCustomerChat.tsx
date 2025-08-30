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
      'サービス概要・能力範囲についてご案内します。',
      '【サービス概要】\nマーケティング戦略立案からシステム開発まで、デジタル領域をワンストップでサポートします。\n\n【主な事例】\n\n🏢 **事例1: 商社A社様**\n課題：営業効率化とリード獲得\n結果：MAツール導入で月間リード数10倍、商談化率150%向上\n\n🛒 **事例2: EC事業者B社様**\n課題：カート放棄率の改善\n結果：UI/UX改善とAIレコメンドでCVR 200%向上\n\n🏭 **事例3: 製造業C社様**\n課題：在庫管理の最適化\n結果：リアルタイムシステム構築で在庫回転率30%改善',
      'お客様の課題をお聞かせください。最適なソリューションをご提案いたします。'
    ],
    tech: [
      '技術・システム関連についてご案内します。',
      '【技術・システム】\n最新技術を活用したクラウドネイティブな開発を得意としています。\n\n【主な事例】\n\n💻 **事例1: 金融D社様**\n課題：レガシーシステムのモダナイゼーション\n結果：クラウド移行で運用コスト50%削減、処理速度3倍\n\n🤖 **事例2: サービス業E社様**\n課題：問い合わせ対応の自動化\n結果：AIチャットボットで対応工数80%削減\n\n📦 **事例3: 物流F社様**\n課題：配送管理の効率化\n結果：リアルタイム追跡システムで配送ミス60%減',
      'どのようなシステム課題をお持ちでしょうか？技術的なソリューションをご提案します。'
    ],
    marketing: [
      'マーケティング戦略についてご案内します。',
      '【マーケティング戦略】\nAIを活用したデータドリブンマーケティングで成果を最大化します。\n\n【主な事例】\n\n📈 **事例1: 不動産G社様**\n課題：リード獲得コスト高騰\n結果：CDP導入でROI 320%向上、コスト40%削減\n\n🎯 **事例2: サービスH社様**\n課題：ブランド認知度の低さ\n結果：コンテンツマーケティングでリード数500%増\n\n💳 **事例3: 小売I社様**\n課題：広告費用対効果\n結果：AI最適化でCPA 50%改善',
      'どのようなマーケティング課題をお持ちでしょうか？最適な戦略をご提案します。'
    ],
    project: [
      'プロジェクト進行・体制についてご案内します。',
      '【プロジェクト進行・体制】\nアジャイル開発で柔軟かつ迅速にプロジェクトを推進します。\n\n【主な事例】\n\n⏱️ **事例1: IT企業J社様**\n課題：開発スピードの向上\n結果：アジャイル導入で納期50%短縮\n\n🔄 **事例2: サービスK社様**\n課題：仕様変更への対応\n結果：スプリント開発で柔軟に対応、顧客満足度120%\n\n👥 **事例3: 製造L社様**\n課題：コミュニケーション不足\n結果：専任PMと週次MTGでプロジェクト成功率100%',
      'ご希望の納期や体制についてお聞かせください。最適なプランをご提案します。'
    ],
    cost: [
      '費用・契約についてご案内します。',
      '【費用・契約】\n柔軟な料金体系でご予算に合わせたプランをご提案します。\n\n【主な事例】\n\n💰 **事例1: スタートアップM社様**\n課題：限られた予算\n結果：段階的導入で初期費用70%削減\n\n📄 **事例2: 中小企業N社様**\n課題：契約の柔軟性\n結果：月額サブスクでキャッシュフロー改善\n\n🎁 **事例3: 大企業O社様**\n課題：コストパフォーマンス\n結果：成果報酬型でROI 400%達成',
      'ご予算規模やご希望の契約形態をお聞かせください。最適なプランをご提案します。'
    ],
    case: [
      '実績・事例についてご案内します。',
      '【実績・事例】\n幅広い業界での成功事例がございます。\n\n【主な事例】\n\n🏬 **事例1: 小売P社様（年商100億円）**\n課題：ECサイトの売上伸び悩み\n結果：UI/UX改善でCVR 200%向上、月塆3億円達成\n\n🏭 **事例2: 製造Q社様（従業員500名）**\n課題：生産管理の非効率\n結果：システム化で作業時間50%削減、年間5000万円コスト削減\n\n🏦 **事例3: 金融R社様（上場企業）**\n課題：顧客対応の負荷\n結果：AIチャットボットで対応80%自動化、CSスコア130%向上',
      'どのような業界・規模の事例をご覧になりたいですか？詳細をご案内します。'
    ],
    consultation: [
      '初回相談・問い合わせについてご案内します。',
      '【初回相談・問い合わせ】\n無料相談でお客様の課題をお伺いし、最適なソリューションをご提案します。\n\n【主な事例】\n\n📣 **事例1: ベンチャーS社様**\n相談内容：ビジネスモデルの壁打ち\n結果：無料相談から1年後にIPO達成\n\n☕ **事例2: 中堅企業T社様**\n相談内容：DX推進の方向性\n結果：段階的導入で全社デジタル化成功\n\n🤝 **事例3: 大企業U社様**\n相談内容：新事業立ち上げ\n結果：6ヶ月で黒字化、年堵10億円事業に成長',
      'まずはお気軽にご相談ください。ご希望の日時や方法をお聞かせください。'
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

  // 企業からの返信を定期的にチェック
  useEffect(() => {
    // 現在のURLからチャットIDを取得（実際の実装では適切に取得）
    const chatId = window.location.pathname.split('/').pop() || `chat-${Date.now()}`;
    
    const checkForReplies = () => {
      const allMessages = JSON.parse(localStorage.getItem('chatMessages') || '[]');
      const relevantMessages = allMessages.filter((msg: any) => msg.chatId === chatId);
      
      // 企業からの返信を追加
      relevantMessages.forEach((reply: any) => {
        // すでに表示されているメッセージはスキップ
        const exists = messages.some(m => 
          m.text === reply.message && 
          m.timestamp.toISOString() === reply.timestamp
        );
        
        if (!exists) {
          const companyMessage: Message = {
            id: messages.length + 1000 + Math.random(), // ユニークなID
            text: reply.message,
            sender: 'bot',
            timestamp: new Date(reply.timestamp)
          };
          setMessages(prev => [...prev, companyMessage]);
        }
      });
    };
    
    // 初回チェック
    checkForReplies();
    
    // 3秒ごとにチェック
    const interval = setInterval(checkForReplies, 3000);
    
    return () => clearInterval(interval);
  }, [messages]);

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
          
          // フォームを表示（質問の0.5秒後）
          setTimeout(() => {
            setShowContactForm(true);
          }, 500);
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
    
    // 現在のチャットIDを取得または生成
    const chatId = window.location.pathname.split('/').pop() || `chat-${Date.now()}`;
    
    // 問い合わせデータをローカルストレージに保存（実際はAPIに送信）
    const pendingChat = {
      id: chatId,
      companyName: contactForm.company,
      contactName: contactForm.name,
      email: contactForm.email,
      phone: contactForm.phone,
      message: contactForm.message,
      category: selectedCategory || '',
      timestamp: new Date().toLocaleString('ja-JP'),
      responseType: null,
      status: 'pending',
      customerType: 'new'
    };
    
    // ローカルストレージに保存
    const existingChats = JSON.parse(localStorage.getItem('pendingChats') || '[]');
    existingChats.push(pendingChat);
    localStorage.setItem('pendingChats', JSON.stringify(existingChats));
    
    // フォームを非表示
    setShowContactForm(false);
    
    // サンクスメッセージの送信
    const formMessage: Message = {
      id: messages.length + 1,
      text: `お問い合わせありがとうございます。
以下の内容で承りました。

【お客様情報】
お名前: ${contactForm.name}
会社名: ${contactForm.company}
メールアドレス: ${contactForm.email}
電話番号: ${contactForm.phone || 'なし'}
ご相談内容: ${contactForm.message}

担当者より2営業日以内にご連絡させていただきます。`,
      sender: 'bot',
      timestamp: new Date()
    };
    setMessages(prev => [...prev, formMessage]);
    
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