import React, { useState, useEffect } from 'react';
import { Send, MessageCircle, User, Mail, Building, Phone } from 'lucide-react';
import CategorySelector from './CategorySelector';
import { generateAIResponse } from './companyKnowledge';
import actionCableService from './services/actionCable';
import ChatHistory from './components/ChatHistory';
import FloatingFormButton from './components/FloatingFormButton';
import FloatingForm from './components/FloatingForm';
// import AutoResumeChat from './components/AutoResumeChat';
import sessionManager from './services/sessionManager';

interface Message {
  id: number;
  text: string;
  sender: 'user' | 'bot' | 'company';
  timestamp: Date;
  category?: string;
  role?: 'user' | 'assistant' | 'system' | 'company';
  isWaiting?: boolean;  // 待機中フラグ
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
  const [conversationId, setConversationId] = useState<string | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [hasResumed, setHasResumed] = useState(false);
  const [isFloatingFormVisible, setIsFloatingFormVisible] = useState(false);
  const [showInlineForm, setShowInlineForm] = useState(false);

  // 会話を再開する
  const handleResumeConversation = async (resumeConversationId: string) => {
    try {
      // APIから会話の詳細を取得
      const response = await fetch(`http://localhost:3000/api/v1/conversations/${resumeConversationId}`, {
        credentials: 'include'
      });
      
      if (!response.ok) {
        throw new Error('Failed to fetch conversation');
      }
      
      const data = await response.json();
      const conversation = data.conversation;
      
      // メッセージを復元
      const restoredMessages = conversation.messages.map((msg: any) => ({
        id: msg.id,
        text: msg.content,
        sender: msg.role === 'company' ? 'company' : msg.role === 'assistant' ? 'bot' : 'user',
        timestamp: new Date(msg.created_at),
        role: msg.role
      }));
      
      setMessages(restoredMessages);
      setConversationId(resumeConversationId);
      
      // ActionCableに再接続
      actionCableService.unsubscribe();
      actionCableService.subscribeToConversation(resumeConversationId, {
        onConnected: () => {
          setIsConnected(true);
          console.log('Resumed conversation:', resumeConversationId);
        },
        onDisconnected: () => {
          setIsConnected(false);
        },
        onReceived: (data) => {
          if (data.message) {
            const newMessage: Message = {
              id: data.message.id || Date.now(),
              text: data.message.content,
              sender: data.message.role === 'company' ? 'company' : data.message.role === 'assistant' ? 'bot' : 'user',
              timestamp: new Date(data.message.created_at || Date.now()),
              role: data.message.role
            };
            setMessages(prev => {
              const exists = prev.some(m => m.id === newMessage.id);
              if (exists) return prev;
              return [...prev, newMessage];
            });
          }
        }
      });
      
      // 会話を再開（APIでステータス更新）
      await fetch(`http://localhost:3000/api/v1/conversations/${resumeConversationId}/resume`, {
        method: 'POST',
        credentials: 'include'
      });
      
    } catch (error) {
      console.error('Error resuming conversation:', error);
      alert('会話の再開に失敗しました');
    }
  };

  const categoryNames: { [key: string]: string } = {
    service: 'サービス概要・能力範囲',
    tech: '技術・システム関連',
    marketing: 'マーケティング戦略',
    project: 'プロジェクト進行・体制',
    cost: '費用・契約',
    case: '実績・事例',
    consultation: '初回相談・問い合わせ',
    faq: 'よくある質問（FAQ）'
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

  // 自動復元のハンドラ（現在は使用していない）
  // const handleConversationLoaded = (data: { conversationId: string; messages: any[] }) => {
  //   console.log('Conversation resumed:', data.conversationId);
  //   
  //   // 復元したメッセージを設定
  //   const restoredMessages = data.messages.map((msg: any) => ({
  //     id: msg.id,
  //     text: msg.content,
  //     sender: msg.role === 'company' ? 'company' : msg.role === 'assistant' ? 'bot' : 'user',
  //     timestamp: new Date(msg.created_at || Date.now()),
  //     role: msg.role
  //   }));
  //   
  //   setMessages(restoredMessages);
  //   setConversationId(data.conversationId);
  //   setHasResumed(true);
  //   setIsLoading(false);
  //   setShowCategorySelector(false); // 復元時はカテゴリ選択を表示しない
  //   
  //   // sessionManagerを更新
  //   sessionManager.setCurrentConversationId(data.conversationId);
  // };

  // 初回アクセス時の段階的表示とActionCable接続
  useEffect(() => {
    const initializeChat = async () => {
      // セッションIDを取得
      const userId = sessionManager.getUserId();
      const tabSessionId = sessionManager.getTabSessionId();
      console.log('Initializing chat with userId:', userId, 'tabSessionId:', tabSessionId);
      
      // URLからconversationIdを取得（パスまたはハッシュから）
      const pathId = window.location.pathname.split('/').pop();
      const hashId = window.location.hash.replace('#', '');
      let convId: string | null = null;
      let hasExistingConversation = false;
      
      // URLハッシュに数値IDがある場合はそれを優先使用
      if (hashId && /^\d+$/.test(hashId)) {
        // 指定された会話を取得
        try {
          const response = await fetch(`http://localhost:3000/api/v1/conversations/${hashId}`, {
            headers: {
              'Content-Type': 'application/json',
              'X-User-Id': userId,
              'X-Session-Id': tabSessionId
            },
            credentials: 'include'
          });
          
          if (response.ok) {
            const data = await response.json();
            const conversation = data.conversation;
            
            if (conversation) {
              convId = String(conversation.id);
              hasExistingConversation = true;
              
              // sessionStorageに保存してこのタブの会話として設定
              sessionStorage.setItem('current_conversation_id', convId);
              
              // 既存のメッセージを復元
              if (conversation.messages && conversation.messages.length > 0) {
                const restoredMessages = conversation.messages.map((msg: any) => ({
                  id: msg.id,
                  text: msg.content,
                  sender: msg.role === 'company' ? 'company' : msg.role === 'assistant' ? 'bot' : 'user',
                  timestamp: new Date(msg.created_at || Date.now()),
                  role: msg.role
                }));
                setMessages(restoredMessages);
                setHasResumed(true);
              }
            }
          }
        } catch (error) {
          console.error('Error fetching conversation from hash:', error);
        }
      }
      // URLパスに数値IDがある場合はそれを使用
      else if (pathId && pathId !== 'chat' && /^\d+$/.test(pathId)) {
        convId = pathId;
        hasExistingConversation = true;
      } else {
        // タブごとの会話IDをsessionStorageから取得
        const storedConvId = sessionStorage.getItem('current_conversation_id');
        
        if (storedConvId) {
          // 既存の会話を復元
          try {
            const response = await fetch(`http://localhost:3000/api/v1/conversations/${storedConvId}`, {
              headers: {
                'Content-Type': 'application/json',
                'X-User-Id': userId,
                'X-Session-Id': tabSessionId
              },
              credentials: 'include'
            });
            
            if (response.ok) {
              const data = await response.json();
              const conversation = data.conversation;
              
              if (conversation && conversation.status === 'active') {
                convId = String(conversation.id);
                hasExistingConversation = true;
                
                // 既存のメッセージを復元
                if (conversation.messages && conversation.messages.length > 0) {
                  const restoredMessages = conversation.messages.map((msg: any) => ({
                    id: msg.id,
                    text: msg.content,
                    sender: msg.role === 'company' ? 'company' : msg.role === 'assistant' ? 'bot' : 'user',
                    timestamp: new Date(msg.created_at || Date.now()),
                    role: msg.role
                  }));
                  setMessages(restoredMessages);
                  setHasResumed(true);
                }
              }
            } else if (response.status === 404) {
              // 会話が見つからない場合はsessionStorageをクリア
              sessionStorage.removeItem('current_conversation_id');
            }
          } catch (error) {
            console.error('Error fetching conversation:', error);
            sessionStorage.removeItem('current_conversation_id');
          }
        }
        // storedConvIdがない場合は新しい会話を開始（convId = null）
      }
      
      // 会話IDがない場合は暂定的に空のIDを使用（フォーム送信時に作成）
      if (!convId) {
        convId = null; // ActionCableは接続しない
      }
      
      setConversationId(convId);
      setIsLoading(false);
      
      // 会話がある場合のみActionCableに接続
      if (convId) {
        // ActionCableに接続
        const subscription = actionCableService.subscribeToConversation(convId, {
          onConnected: () => {
            console.log('WebSocket connected');
            setIsConnected(true);
          },
          onDisconnected: () => {
            console.log('WebSocket disconnected');
            setIsConnected(false);
          },
          onReceived: (data) => {
            if (data.message) {
              const newMessage: Message = {
                id: data.message.id || Date.now(),
                text: data.message.content,
                sender: data.message.role === 'company' ? 'company' : data.message.role === 'assistant' ? 'bot' : 'user',
                timestamp: new Date(data.message.created_at || Date.now()),
                role: data.message.role
              };
              
              // 企業からの返信を受信した場合
              if (data.message.role === 'company') {
                // 自動返信タイマーをキャンセル
                if ((window as any).autoReplyTimer) {
                  clearTimeout((window as any).autoReplyTimer);
                  (window as any).autoReplyTimer = null;
                }
                
                // 待機中メッセージを削除
                setMessages(prev => {
                  const filtered = prev.filter(m => !m.isWaiting);
                  // 重複を避ける
                  const exists = filtered.some(m => m.id === newMessage.id);
                  if (exists) return filtered;
                  return [...filtered, newMessage];
                });
              } else {
                setMessages(prev => {
                  // 重複を避ける（IDまたは同じ内容・時刻のメッセージ）
                  const exists = prev.some(m => 
                    m.id === newMessage.id || 
                    (m.text === newMessage.text && 
                     Math.abs(m.timestamp.getTime() - newMessage.timestamp.getTime()) < 1000)
                  );
                  if (exists) return prev;
                  return [...prev, newMessage];
                });
              }
            }
          }
        });
      }

      // 会話が復元されなかった場合はウェルカムメッセージを表示
      if (!hasExistingConversation) {
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
      } else {
        setIsLoading(false);
      }
    };
    
    initializeChat();

    // クリーンアップ
    return () => {
      actionCableService.unsubscribe();
    };
  }, []);

  // ActionCable経由でメッセージを送信
  const sendMessageToCable = (content: string, role: 'user' | 'assistant' | 'company' = 'user') => {
    if (isConnected) {
      actionCableService.sendMessage({
        content,
        role,
        metadata: {
          category: selectedCategory,
          conversationId
        }
      });
    }
  };

  const handleCategorySelect = (category: string) => {
    // FAQカテゴリーが選択された場合はFAQページへ遷移
    if (category === 'faq') {
      window.location.href = '/faq';
      return;
    }
    
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
    if (!selectedCategory && !conversationId) return;

    const messageCopy = inputMessage;
    setInputMessage('');

    // メッセージオブジェクトを作成
    const userMessage: Message = {
      id: Date.now(),
      text: messageCopy,
      sender: 'user',
      timestamp: new Date()
    };

    // ActionCable経由でメッセージを送信（接続されている場合）
    if (isConnected && conversationId) {
      // 一時的にローカルに追加（楽観的更新）
      setMessages(prev => [...prev, userMessage]);
      // ActionCable経由で送信
      sendMessageToCable(messageCopy, 'user');
      setIsLoading(false);
    }
    // カテゴリー選択後の初期段階（会話IDがまだない）
    else if (selectedCategory && !conversationId) {
      setMessages(prev => [...prev, userMessage]);
      
      setIsLoading(true);
      // AI応答を生成（ローカル）
      setTimeout(() => {
        const response = generateAIResponse(messageCopy, selectedCategory, messageCount);
        
        const botMessage: Message = {
          id: Date.now() + 1,
          text: response.message,
          sender: 'bot',
          timestamp: new Date()
        };
        setMessages(prev => [...prev, botMessage]);
        setIsLoading(false);
        setMessageCount(prev => prev + 1);
        
        // アシスタントメッセージも送信
        if (isConnected) {
          sendMessageToCable(response.message, 'assistant');
        }
      }, 1500);
    }
  };

  const handleContactSubmit = async (e: React.FormEvent) => {
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
    
    // 内容確認中メッセージの送信
    const confirmMessage: Message = {
      id: messages.length + 1,
      text: '内容をご確認いたします...',
      sender: 'bot',
      timestamp: new Date(),
      isWaiting: true  // 待機状態のフラグ
    };
    setMessages(prev => [...prev, confirmMessage]);
    
    try {
      let realConversationId: number;
      
      // 既存の会話IDが設定されているか確認
      if (conversationId && conversationId !== 'null') {
        // 既存の会話を使用
        realConversationId = parseInt(conversationId);
      } else {
        // 新しい会話を作成（session_idは毎回新しく生成）
        const newSessionId = `${sessionManager.getTabSessionId()}-${Date.now()}`;
        const createResponse = await fetch('http://localhost:3000/api/v1/conversations', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-User-Id': sessionManager.getUserId(),
            'X-Session-Id': sessionManager.getTabSessionId()
          },
          credentials: 'include',
          body: JSON.stringify({
            conversation: {
              session_id: newSessionId,  // ユニークなsession_idを使用
              status: 'active',
              metadata: {
                category: selectedCategory || '',
                company: contactForm.company,
                contactName: contactForm.name,
                email: contactForm.email,
                phone: contactForm.phone,
                customerType: 'new'  // 新規顧客として明示的に設定
              }
            }
          })
        });
        
        const responseData = await createResponse.json();
        
        if (!createResponse.ok) {
          console.error('Conversation creation error:', responseData);
          throw new Error(responseData.error || 'Failed to create conversation');
        }
        
        const { conversation } = responseData;
        realConversationId = conversation.id; // データベースの実際のID
      }
      
      // 既に接続されている場合は、既存の接続を使用してメッセージを送信
      if (isConnected && conversationId === String(realConversationId)) {
        // 既存の接続でメッセージを送信
        const formMessage = `会社名: ${contactForm.company}
お名前: ${contactForm.name}
メールアドレス: ${contactForm.email}
電話番号: ${contactForm.phone || ''}
お問い合わせカテゴリ: ${categoryNames[selectedCategory] || 'その他'}
お問い合わせ内容: ${contactForm.message}`;
        
        actionCableService.sendMessage({
          content: formMessage,
          role: 'user',
          metadata: {
            category: selectedCategory,
            conversationId: realConversationId
          }
        });
      } else {
        // 新しい会話IDでActionCableに再接続
        actionCableService.unsubscribe();
        actionCableService.subscribeToConversation(String(realConversationId), {
          onConnected: () => {
            console.log(`Connected to conversation ${realConversationId}`);
            setIsConnected(true);
            
            // フォームデータを含むメッセージを送信
            const formMessage = `会社名: ${contactForm.company}
お名前: ${contactForm.name}
メールアドレス: ${contactForm.email}
電話番号: ${contactForm.phone || ''}
お問い合わせカテゴリ: ${categoryNames[selectedCategory] || 'その他'}
お問い合わせ内容: ${contactForm.message}`;
            
            actionCableService.sendMessage({
              content: formMessage,
              role: 'user',
              metadata: {
                category: selectedCategory,
                conversationId: realConversationId
              }
            });
          },
          onDisconnected: () => {
            console.log('WebSocket disconnected');
            setIsConnected(false);
          },
          onReceived: (data) => {
            if (data.message) {
              const newMessage: Message = {
                id: data.message.id || Date.now(),
                text: data.message.content,
                sender: data.message.role === 'company' ? 'company' : data.message.role === 'assistant' ? 'bot' : 'user',
                timestamp: new Date(data.message.created_at || Date.now()),
                role: data.message.role
              };
              
              // 企業からの返信を受信した場合
              if (data.message.role === 'company') {
                // 自動返信タイマーをキャンセル
                if ((window as any).autoReplyTimer) {
                  clearTimeout((window as any).autoReplyTimer);
                  (window as any).autoReplyTimer = null;
                }
                
                // 待機中メッセージを削除
                setMessages(prev => {
                  const filtered = prev.filter(m => !m.isWaiting);
                  // 重複を避ける
                  const exists = filtered.some(m => m.id === newMessage.id);
                  if (exists) return filtered;
                  return [...filtered, newMessage];
                });
              } else {
                setMessages(prev => {
                  // 重複を避ける（IDまたは同じ内容・時刻のメッセージ）
                  const exists = prev.some(m => 
                    m.id === newMessage.id || 
                    (m.text === newMessage.text && 
                     Math.abs(m.timestamp.getTime() - newMessage.timestamp.getTime()) < 1000)
                  );
                  if (exists) return prev;
                  return [...prev, newMessage];
                });
              }
            }
          }
        });
      }
      
      // 会話IDを更新
      setConversationId(String(realConversationId));
      
      // タブごとのsessionStorageに保存
      sessionStorage.setItem('current_conversation_id', String(realConversationId));
      
      // 90秒後に自動返信（企業側から返信がない場合）
      const autoReplyTimer = setTimeout(() => {
        const autoReplyMessage: Message = {
          id: Date.now(),
          text: `お問い合わせありがとうございます。
以下の内容で承りました。
【お客様情報】
お名前: ${contactForm.name}
会社名: ${contactForm.company}
メールアドレス: ${contactForm.email}
電話番号: ${contactForm.phone || 'なし'}
ご相談内容: ${contactForm.message}
2営業日以内に担当者よりご連絡させていただきます。`,
          sender: 'company',
          timestamp: new Date()
        };
        
        setMessages(prev => {
          // 待機中メッセージを削除して自動返信を追加
          const filtered = prev.filter(m => !m.isWaiting);
          return [...filtered, autoReplyMessage];
        });
        
        // ActionCableで自動返信を送信（既に接続されている）
        actionCableService.sendMessage({
          content: autoReplyMessage.text,
          role: 'company',
          metadata: {
            conversationId: realConversationId
          }
        });
      }, 90000); // 90秒
      
      // タイマーIDを保存（企業から返信があったらキャンセルする用）
      (window as any).autoReplyTimer = autoReplyTimer;
      
    } catch (error) {
      console.error('Error creating conversation:', error);
      // エラー時はローカルストレージに保存（フォールバック）
      const chatId = `chat-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
      
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
    }
    
    // フォームをリセット
    setContactForm({
      name: '',
      company: '',
      email: '',
      phone: '',
      message: ''
    });
  };

  // フローティングフォームのハンドラー
  const handleFloatingFormToggle = () => {
    if (showInlineForm) {
      // フォームが表示されている場合は閉じる
      setShowInlineForm(false);
    } else {
      // フローティングフォームではなく、チャット内にフォームを表示
      setIsFloatingFormVisible(false);
      setShowInlineForm(true);
    }
  };

  // インラインフォーム送信ハンドラー
  const handleInlineFormSubmit = async (formData: any, formType: 'diagnosis' | 'support') => {
    // フォームを非表示にする
    setShowInlineForm(false);
    
    // 以下は既存のフローティングフォーム送信処理と同じ
    await handleFloatingFormSubmit(formData, formType);
  };

  const handleFloatingFormSubmit = async (formData: any, formType: 'diagnosis' | 'support') => {
    // フォーム送信時にチャットに統合
    const formTitle = formType === 'diagnosis' ? '無料診断のお申し込み' : 'サポートのお問い合わせ';
    
    // チャットにフォーム内容を表示するメッセージを作成
    const formMessage = `【${formTitle}】
カテゴリー: ${categoryNames[formData.category as keyof typeof categoryNames] || 'その他'}
会社名: ${formData.company}
お名前: ${formData.name}
メールアドレス: ${formData.email}
電話番号: ${formData.phone || 'なし'}
ご相談内容: ${formData.message}`;

    const userMessage: Message = {
      id: Date.now(),
      text: formMessage,
      sender: 'user',
      timestamp: new Date()
    };

    setMessages(prev => [...prev, userMessage]);

    // 既存のフォーム送信処理を流用
    const updatedContactForm = {
      name: formData.name,
      company: formData.company,
      email: formData.email,
      phone: formData.phone || '',
      message: formData.message
    };

    const updatedSelectedCategory = formData.category;
    
    // setContactForm(updatedContactForm);
    // setSelectedCategory(updatedSelectedCategory);

    // 確認メッセージ
    const confirmMessage: Message = {
      id: Date.now() + 1,
      text: '内容をご確認いたします...',
      sender: 'bot',
      timestamp: new Date(),
      isWaiting: true
    };
    setMessages(prev => [...prev, confirmMessage]);

    try {
      let realConversationId: number;
      
      // 既存の会話IDが設定されているか確認
      if (conversationId && conversationId !== 'null') {
        realConversationId = parseInt(conversationId);
      } else {
        // 新しい会話を作成
        const newSessionId = `${sessionManager.getTabSessionId()}-${Date.now()}`;
        const createResponse = await fetch('http://localhost:3000/api/v1/conversations', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-User-Id': sessionManager.getUserId(),
            'X-Session-Id': sessionManager.getTabSessionId()
          },
          credentials: 'include',
          body: JSON.stringify({
            conversation: {
              session_id: newSessionId,
              status: 'active',
              metadata: {
                category: updatedSelectedCategory || '',
                company: updatedContactForm.company,
                contactName: updatedContactForm.name,
                email: updatedContactForm.email,
                phone: updatedContactForm.phone,
                customerType: 'new',
                formType: formType
              }
            }
          })
        });
        
        const responseData = await createResponse.json();
        
        if (!createResponse.ok) {
          console.error('Conversation creation error:', responseData);
          throw new Error(responseData.error || 'Failed to create conversation');
        }
        
        const { conversation } = responseData;
        realConversationId = conversation.id;
      }
      
      // ActionCable接続と設定（既存ロジックを流用）
      if (!isConnected || conversationId !== String(realConversationId)) {
        actionCableService.unsubscribe();
        actionCableService.subscribeToConversation(String(realConversationId), {
          onConnected: () => {
            console.log(`Connected to conversation ${realConversationId}`);
            setIsConnected(true);
            
            // フォームデータを含むメッセージを送信
            actionCableService.sendMessage({
              content: formMessage,
              role: 'user',
              metadata: {
                category: updatedSelectedCategory,
                conversationId: realConversationId,
                formType: formType
              }
            });
          },
          onDisconnected: () => {
            setIsConnected(false);
          },
          onReceived: (data) => {
            if (data.message) {
              const newMessage: Message = {
                id: data.message.id || Date.now(),
                text: data.message.content,
                sender: data.message.role === 'company' ? 'company' : data.message.role === 'assistant' ? 'bot' : 'user',
                timestamp: new Date(data.message.created_at || Date.now()),
                role: data.message.role
              };
              
              if (data.message.role === 'company') {
                if ((window as any).autoReplyTimer) {
                  clearTimeout((window as any).autoReplyTimer);
                  (window as any).autoReplyTimer = null;
                }
                
                setMessages(prev => {
                  const filtered = prev.filter(m => !m.isWaiting);
                  const exists = filtered.some(m => m.id === newMessage.id);
                  if (exists) return filtered;
                  return [...filtered, newMessage];
                });
              } else {
                setMessages(prev => {
                  const exists = prev.some(m => 
                    m.id === newMessage.id || 
                    (m.text === newMessage.text && 
                     Math.abs(m.timestamp.getTime() - newMessage.timestamp.getTime()) < 1000)
                  );
                  if (exists) return prev;
                  return [...prev, newMessage];
                });
              }
            }
          }
        });
      } else if (isConnected) {
        // 既存の接続でメッセージを送信
        actionCableService.sendMessage({
          content: formMessage,
          role: 'user',
          metadata: {
            category: updatedSelectedCategory,
            conversationId: realConversationId,
            formType: formType
          }
        });
      }
      
      // 会話IDを更新
      setConversationId(String(realConversationId));
      sessionStorage.setItem('current_conversation_id', String(realConversationId));
      
      // 90秒後の自動返信設定
      const autoReplyTimer = setTimeout(() => {
        const autoReplyMessage: Message = {
          id: Date.now(),
          text: `【${formTitle}】のお申し込みありがとうございます。
以下の内容で承りました。

【お客様情報】
お名前: ${updatedContactForm.name}
会社名: ${updatedContactForm.company}
メールアドレス: ${updatedContactForm.email}
電話番号: ${updatedContactForm.phone || 'なし'}
ご相談内容: ${updatedContactForm.message}

2営業日以内に担当者よりご連絡させていただきます。`,
          sender: 'company',
          timestamp: new Date()
        };
        
        setMessages(prev => {
          const filtered = prev.filter(m => !m.isWaiting);
          return [...filtered, autoReplyMessage];
        });
        
        actionCableService.sendMessage({
          content: autoReplyMessage.text,
          role: 'company',
          metadata: {
            conversationId: realConversationId
          }
        });
      }, 90000);
      
      (window as any).autoReplyTimer = autoReplyTimer;
      
    } catch (error) {
      console.error('Error creating conversation from floating form:', error);
      // エラー時は待機メッセージを削除してエラーメッセージを表示
      setMessages(prev => {
        const filtered = prev.filter(m => !m.isWaiting);
        const errorMessage: Message = {
          id: Date.now(),
          text: 'お問い合わせの送信中にエラーが発生しました。恐れ入りますが、しばらく時間をおいて再度お試しください。',
          sender: 'bot',
          timestamp: new Date()
        };
        return [...filtered, errorMessage];
      });
    }
  };

  return (
    // <AutoResumeChat onConversationLoaded={handleConversationLoaded}>
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
          justifyContent: 'space-between',
          maxWidth: '48rem',
          margin: '0 auto'
        }}>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '0.75rem'
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
          {/* チャット履歴ボタン */}
          <ChatHistory onResumeConversation={handleResumeConversation} />
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
                <div style={{ whiteSpace: 'pre-wrap' }}>
                  {message.text}
                  {message.isWaiting && (
                    <span style={{ marginLeft: '0.5rem' }}>
                      <span className="animate-pulse">●●●</span>
                    </span>
                  )}
                </div>
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
          
          {/* インラインフローティングフォーム */}
          {showInlineForm && (
            <div style={{
              animation: 'fadeIn 0.3s ease-in',
              backgroundColor: 'white',
              borderRadius: '0.75rem',
              padding: '1.5rem',
              marginTop: '1rem',
              boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)',
            }}>
              <FloatingForm
                isVisible={true}
                onClose={() => setShowInlineForm(false)}
                onSubmit={handleInlineFormSubmit}
                selectedCategory={selectedCategory}
                isInline={true}
              />
            </div>
          )}

          {/* 依頼フォーム */}
          {/* {showContactForm && (
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
          )} */}
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
            placeholder={conversationId ? "メッセージを入力..." : (selectedCategory ? "メッセージを入力..." : "まずはカテゴリーをお選びください")}
            disabled={!selectedCategory && !conversationId}
            style={{
              flex: 1,
              padding: '0.75rem',
              borderRadius: '0.5rem',
              border: '1px solid #e5e7eb',
              fontSize: '0.875rem',
              outline: 'none',
              opacity: (selectedCategory || conversationId) ? 1 : 0.5
            }}
          />
          <button
            onClick={handleSendMessage}
            disabled={!inputMessage.trim() || (!selectedCategory && !conversationId)}
            style={{
              padding: '0.75rem 1.5rem',
              backgroundColor: inputMessage.trim() && (selectedCategory || conversationId) ? '#2563eb' : '#e5e7eb',
              color: inputMessage.trim() && (selectedCategory || conversationId) ? 'white' : '#9ca3af',
              borderRadius: '0.5rem',
              border: 'none',
              cursor: inputMessage.trim() && (selectedCategory || conversationId) ? 'pointer' : 'not-allowed',
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

      {/* フローティングフォーム機能 */}
      <FloatingFormButton 
        onFormToggle={handleFloatingFormToggle}
        isFormVisible={showInlineForm}
      />
      
      {/* フローティングフォーム（非表示） - インラインフォームを使用するため */}
      {false && (
        <FloatingForm
          isVisible={isFloatingFormVisible}
          onClose={() => setIsFloatingFormVisible(false)}
          onSubmit={handleFloatingFormSubmit}
          selectedCategory={selectedCategory}
        />
      )}
      </div>
    // </AutoResumeChat>
  );
};

export default NewCustomerChat;