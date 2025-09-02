import React, { useState, useEffect, useRef } from 'react';
import { Send, MessageCircle } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import CategorySelector from './ExistingCategorySelector';
import { generateExistingCustomerResponse } from './existingCustomerKnowledge';
import actionCableService from './services/actionCable';
import ChatHistory from './components/ChatHistory';
import ExistingCustomerFormButton from './components/ExistingCustomerFormButton';
import ExistingCustomerForm from './components/ExistingCustomerForm';
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

const ExistingCustomerChat: React.FC = () => {
  const navigate = useNavigate();
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const [showCategorySelector, setShowCategorySelector] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [showContactForm, setShowContactForm] = useState(false);
  // const [messageCount, setMessageCount] = useState(0);
  // 旧インラインフォームの状態（未使用のため削除）
  // 旧フォームのバリデーション状態（未使用のため無効化）
  // const [formErrors, setFormErrors] = useState({
  //   name: '',
  //   company: '',
  //   email: '',
  //   message: ''
  // });
  const [conversationId, setConversationId] = useState<string | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  // const [hasResumed, setHasResumed] = useState(false);
  const bottomRef = useRef<HTMLDivElement | null>(null);
  const scrollToBottom = () => bottomRef.current?.scrollIntoView({ behavior: 'smooth' });

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
    'cdp': 'CDP運用',
    'ma_crm': 'MA/CRM最適化',
    'advertising': 'Web広告運用',
    'analytics': 'データ分析',
    'development': 'システム開発',
    'ecommerce': 'ECサイト運営',
    'ai_ml': 'AI・機械学習',
    'organization': '組織・体制',
    'cost': 'コスト最適化',
    'competition': '競合対策'
  };

  const categoryResponses: { [key: string]: string[] } = {
    cdp: [
      'CDP運用についてご案内します。',
      '【CDP運用】\nデータ統合からセグメント設定、外部ツール連携まで包括的にサポートします。\n\n【主な事例】\n\n📊 **事例1: 小売A社様**\n課題：顧客データの分散管理\n結果：CDP導入で360度顧客把握、売上20%向上\n\n🎯 **事例2: EC事業者B社様**\n課題：パーソナライゼーション精度\n結果：リアルタイムセグメント化でCVR 150%改善\n\n🔗 **事例3: サービス業C社様**\n課題：マーケティングツールの連携不足\n結果：統合基盤構築でROAS 200%向上',
      'データ統合やセグメント設定など、どのようなCDP課題がございますか？'
    ],
    
    ma_crm: [
      'MA/CRM最適化についてご案内します。',
      '【MA/CRM最適化】\nシナリオ設計からスコアリング、ワークフロー自動化まで成果に直結する運用をサポートします。\n\n【主な事例】\n\n⚡ **事例1: BtoB企業D社様**\n課題：リードナーチャリングの効率化\n結果：MAシナリオ最適化で商談化率300%向上\n\n🏆 **事例2: 不動産E社様**\n課題：営業フォロー漏れ\n結果：CRM自動化で成約率40%改善\n\n📈 **事例3: IT企業F社様**\n課題：スコアリング精度\n結果：AIスコアリング導入でMQL品質180%向上',
      'シナリオ設計やスコアリングなど、どの部分でお困りでしょうか？'
    ],
    
    advertising: [
      'Web広告運用についてご案内します。',
      '【Web広告運用】\nGoogle広告、Facebook広告を中心に、データドリブンな運用で広告効果を最大化します。\n\n【主な事例】\n\n💰 **事例1: EC事業者G社様**\n課題：広告費用対効果の悪化\n結果：AI最適化でROAS 250%改善、CPA 50%削減\n\n📱 **事例2: アプリ開発H社様**\n課題：新規ユーザー獲得コスト\n結果：クリエイティブA/Bテストでインストール数300%増\n\n🌐 **事例3: サービス業I社様**\n課題：ブランド認知拡大\n結果：動画広告でリーチ500%向上、問い合わせ倍増',
      'Google広告、Facebook広告など、どのような広告改善をお求めですか？'
    ],
    
    analytics: [
      'データ分析についてご案内します。',
      '【データ分析】\nダッシュボード構築からレポート自動化、ROI分析まで意思決定を支援します。\n\n【主な事例】\n\n📊 **事例1: 製造業J社様**\n課題：売上分析の属人化\n結果：BIツール導入で分析工数80%削減\n\n💹 **事例2: 小売K社様**\n課題：在庫回転率の可視化\n結果：リアルタイムダッシュボードで利益率15%改善\n\n🔍 **事例3: サービス業L社様**\n課題：顧客行動の理解不足\n結果：行動分析でサービス改善、満足度120%向上',
      'ダッシュボード、レポート、ROI計算など、どのような分析でお困りでしょうか？'
    ],
    
    development: [
      'システム開発についてご案内します。',
      '【システム開発】\nAPI連携から機能追加、パフォーマンス改善まで、技術的課題を包括的に解決します。\n\n【主な事例】\n\n🚀 **事例1: フィンテックM社様**\n課題：決済システムの高速化\n結果：アーキテクチャ改善で処理速度10倍向上\n\n🔗 **事例2: ECプラットフォームN社様**\n課題：外部API連携の複雑化\n結果：マイクロサービス化で開発効率200%改善\n\n⚙️ **事例3: SaaS事業者O社様**\n課題：スケーラビリティ不足\n結果：クラウドネイティブ化で同時利用者数1000%拡張',
      'API連携、機能追加、パフォーマンス改善など、どのような開発が必要でしょうか？'
    ],
    
    ecommerce: [
      'ECサイト運営についてご案内します。',
      '【ECサイト運営】\nShopify運用から決済システム、UI/UX改善まで、売上向上を総合的にサポートします。\n\n【主な事例】\n\n🛒 **事例1: ファッションP社様**\n課題：カート放棄率の高さ\n結果：UI/UX改善でCVR 180%向上、月商3000万円達成\n\n💳 **事例2: 食品Q社様**\n課題：決済離脱率\n結果：ワンクリック決済導入で完了率90%改善\n\n📱 **事例3: 雑貨R社様**\n課題：モバイル対応不足\n結果：レスポンシブ化でスマホ売上300%増',
      'Shopify、決済システム、UI/UX改善など、どの部分を強化したいですか？'
    ],
    
    ai_ml: [
      'AI・機械学習についてご案内します。',
      '【AI・機械学習】\n予測モデルからチャットボット、パーソナライゼーションまで、AIで業務効率と顧客体験を向上します。\n\n【主な事例】\n\n🤖 **事例1: 保険S社様**\n課題：問い合わせ対応の負荷\n結果：AIチャットボットで対応工数70%削減、満足度向上\n\n🔮 **事例2: 物流T社様**\n課題：需要予測精度\n結果：機械学習で予測精度85%向上、在庫コスト30%削減\n\n💎 **事例3: EC事業者U社様**\n課題：レコメンド精度\n結果：AIパーソナライゼーションで売上40%増',
      '予測モデル、チャットボット、パーソナライゼーションなど、どのような機能をお求めですか？'
    ],
    
    organization: [
      '組織・体制についてご案内します。',
      '【組織・体制】\n研修からKPI設定、部門連携まで、デジタル変革を支える組織づくりをサポートします。\n\n【主な事例】\n\n📚 **事例1: 商社V社様**\n課題：デジタルスキル不足\n結果：段階的研修でDX推進、業務効率50%向上\n\n📊 **事例2: 製造業W社様**\n課題：部門間の情報共有不足\n結果：KPI統一で連携強化、プロジェクト成功率180%\n\n🤝 **事例3: サービス業X社様**\n課題：変革推進体制\n結果：専門チーム設立で全社DX、売上20%増',
      '研修、KPI設定、部門連携など、どのような組織課題がございますか？'
    ],
    
    cost: [
      'コスト最適化についてご案内します。',
      '【コスト最適化】\n運用費見直しから契約プラン変更まで、持続可能な成長を支援します。\n\n【主な事例】\n\n💰 **事例1: スタートアップY社様**\n課題：ITコストの圧迫\n結果：クラウド最適化で運用費60%削減、投資余力確保\n\n📋 **事例2: 中堅企業Z社様**\n課題：ツール利用効率\n結果：統合プラットフォーム導入でコスト40%削減\n\n⚖️ **事例3: 大企業AA社様**\n課題：ライセンス費用\n結果：使用状況分析で無駄な契約解約、年間2000万円削減',
      '運用費の見直し、契約プラン変更など、どのような最適化をお考えですか？'
    ],
    
    competition: [
      '競合対策についてご案内します。',
      '【競合対策】\n市場戦略からブランディング、差別化施策まで、競合優位性の確立を支援します。\n\n【主な事例】\n\n🏆 **事例1: IT企業BB社様**\n課題：後発参入での差別化\n結果：独自機能開発でシェア30%獲得\n\n🎯 **事例2: 小売CC社様**\n課題：価格競争からの脱却\n結果：ブランド価値向上で利益率20%改善\n\n🚀 **事例3: サービス業DD社様**\n課題：市場での認知度不足\n結果：戦略的PR施策で業界3位にランクアップ',
      '市場戦略、ブランディング、差別化施策など、どのような競合対策をお考えですか？'
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
                // 復元済みフラグ（UI未使用のためコメントアウト）
                // setHasResumed(true);
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
                  // setHasResumed(true);
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
        actionCableService.subscribeToConversation(convId, {
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
            text: 'こんにちは！運用サポートチームです。どのようなサポートが必要でしょうか？',
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
    // FAQカテゴリーが選択された場合は既存顧客用FAQページへ遷移
    if (category === 'faq') {
      navigate('/existing-faq');
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
        
        // 質問とフォーム表示（さらに1秒後）
        setIsLoading(true);
        setTimeout(() => {
          const questionMessage: Message = {
            id: messageId++,
            text: '詳しい情報を教えていただくために、以下のフォームにご記入ください。',
            sender: 'bot',
            timestamp: new Date()
          };
          setMessages(prev => [...prev, questionMessage]);
          setIsLoading(false);
          
          // 既存顧客用のフォームを表示
          setTimeout(() => {
            setShowContactForm(true);
          }, 500);
        }, 1000);
      }, 1500);
    }, 1000);
  };

  const handleSendMessage = async () => {
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
      
      // 初回メッセージの場合、会話を作成
      try {
        const userId = sessionManager.getUserId();
        const tabSessionId = sessionManager.getTabSessionId();
        
        const response = await fetch('http://localhost:3000/api/v1/conversations', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-User-Id': userId,
            'X-Session-Id': tabSessionId
          },
          body: JSON.stringify({
            initial_message: messageCopy,
            category: selectedCategory,
            customer_type: 'existing',
            metadata: {
              category_name: categoryNames[selectedCategory]
            }
          }),
          credentials: 'include'
        });

        if (response.ok) {
          const data = await response.json();
          const newConversationId = String(data.conversation.id);
          setConversationId(newConversationId);
          sessionStorage.setItem('current_conversation_id', newConversationId);
          
          // ActionCableに接続
          actionCableService.subscribeToConversation(newConversationId, {
            onConnected: () => {
              console.log('WebSocket connected for existing customer');
              setIsConnected(true);
              // 初回メッセージを送信
              actionCableService.sendMessage({
                content: messageCopy,
                role: 'user',
                metadata: {
                  category: selectedCategory,
                  conversationId: newConversationId,
                  customer_type: 'existing'
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
          });
        }
      } catch (error) {
        console.error('Error creating conversation:', error);
      }
      
      setIsLoading(true);
      // AI応答を生成（ローカル）
      setTimeout(() => {
        const response = generateExistingCustomerResponse(selectedCategory, messageCopy);
        
        const botMessage: Message = {
          id: Date.now() + 1,
          text: response,
          sender: 'bot',
          timestamp: new Date()
        };
        setMessages(prev => [...prev, botMessage]);
        setIsLoading(false);
        // setMessageCount(prev => prev + 1);
        
        // アシスタントメッセージも送信
        if (isConnected) {
          sendMessageToCable(response, 'assistant');
        }
      }, 1500);
    }
  };

  // 旧フォーム送信ハンドラー（未使用のため削除）

  // フローティングフォームのハンドラー
  const handleFloatingFormToggle = () => {
    if (showContactForm) {
      // フォームが表示されている場合は閉じる
      setShowContactForm(false);
    } else {
      // 既存のcontactFormを表示
      setShowContactForm(true);
    }
  };

  // フォーム表示時に下端へスクロール
  useEffect(() => {
    if (showContactForm) {
      // レイアウト反映後にスクロール
      setTimeout(() => {
        scrollToBottom();
      }, 0);
    }
  }, [showContactForm]);

  // 既存顧客用フォーム送信ハンドラー
  const handleExistingFormSubmit = async (
    formData: { customerName: string; company: string; email: string; message: string; priority: 'low' | 'medium' | 'high'; category: string },
    formType: 'support' | 'upgrade' | 'feedback'
  ) => {
    // フォームを閉じる
    setShowContactForm(false);

    // 内容確認中メッセージの送信
    const confirmMessage: Message = {
      id: Date.now(),
      text: '内容をご確認いたします...',
      sender: 'bot',
      timestamp: new Date(),
      isWaiting: true
    };
    setMessages(prev => [...prev, confirmMessage]);

    try {
      let realConversationId: number;

      if (conversationId && conversationId !== 'null') {
        realConversationId = parseInt(conversationId);
      } else {
        // 新しい会話を作成
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
              status: 'active',
              metadata: {
                customerType: 'existing',
                category: selectedCategory || formData.category,
                company: formData.company,
                email: formData.email,
                priority: formData.priority,
                formType
              }
            }
          })
        });

        const responseData = await createResponse.json();
        if (!createResponse.ok) {
          console.error('Conversation creation error:', responseData);
          throw new Error(responseData.error || 'Failed to create conversation');
        }
        realConversationId = responseData.conversation.id;
      }

      const formatted = `【サポート依頼（既存）】\nお名前: ${formData.customerName}\n会社名: ${formData.company}\nメールアドレス: ${formData.email}\n緊急度: ${formData.priority}\n種別: ${formType}\nカテゴリ: ${selectedCategory ? categoryNames[selectedCategory] : formData.category}\n内容:\n${formData.message}`;

      if (isConnected && conversationId === String(realConversationId)) {
        actionCableService.sendMessage({
          content: formatted,
          role: 'user',
          metadata: { category: selectedCategory || formData.category, conversationId: realConversationId }
        });
      } else {
        // 再接続して送信
        actionCableService.unsubscribe();
        actionCableService.subscribeToConversation(String(realConversationId), {
          onConnected: () => {
            setIsConnected(true);
            actionCableService.sendMessage({
              content: formatted,
              role: 'user',
              metadata: { category: selectedCategory || formData.category, conversationId: realConversationId }
            });
          },
          onDisconnected: () => setIsConnected(false),
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
                    m.id === newMessage.id || (m.text === newMessage.text && Math.abs(m.timestamp.getTime() - newMessage.timestamp.getTime()) < 1000)
                  );
                  if (exists) return prev;
                  return [...prev, newMessage];
                });
              }
            }
          }
        });
      }

      setConversationId(String(realConversationId));
      sessionStorage.setItem('current_conversation_id', String(realConversationId));

      // 90秒後の自動返信（企業側から返信がない場合）
      const autoReplyTimer = setTimeout(() => {
        const autoReplyMessage: Message = {
          id: Date.now(),
          text: `お問い合わせありがとうございます。\n以下の内容で承りました。\n【サポート依頼（既存）】\nお名前: ${formData.customerName}\n会社名: ${formData.company}\nメールアドレス: ${formData.email}\n緊急度: ${formData.priority}\n種別: ${formType}\n内容: ${formData.message}\n2営業日以内に担当者よりご連絡させていただきます。`,
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
          metadata: { conversationId: realConversationId }
        });
      }, 90000);
      (window as any).autoReplyTimer = autoReplyTimer;
    } catch (error) {
      console.error('Error handling existing customer form:', error);
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
            <MessageCircle size={24} color="#47d159" />
            <div>
              <h2 style={{
                fontSize: '1.125rem',
                fontWeight: '600',
                color: '#1f2937',
                margin: 0
              }}>
                運用サポート
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
              <CategorySelector onSelectCategory={handleCategorySelect} />
            </div>
          )}
          
          {/* 既存顧客用 依頼フォーム */}
          {showContactForm && (
            <div style={{
              animation: 'fadeIn 0.3s ease-in',
              backgroundColor: 'white',
              borderRadius: '0.75rem',
              padding: '0.5rem 0',
              marginTop: '1rem',
              boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
            }}>
              <ExistingCustomerForm
                isVisible={true}
                onClose={() => setShowContactForm(false)}
                onSubmit={handleExistingFormSubmit}
                isInline={true}
              />
            </div>
          )}
          {/* スクロールアンカー */}
          <div ref={bottomRef} />
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


      {/* 既存顧客用フローティングボタン */}
      <ExistingCustomerFormButton 
        onFormToggle={handleFloatingFormToggle}
        isFormVisible={showContactForm}
      />
      </div>
    // </AutoResumeChat>
  );
};

export default ExistingCustomerChat;
