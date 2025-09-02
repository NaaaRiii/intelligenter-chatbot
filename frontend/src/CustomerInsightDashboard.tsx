import React, { useState, useEffect } from 'react';
import { TrendingUp, Users, MessageCircle, Star, AlertTriangle, Eye, ChevronRight, Calendar, Target, Heart, Frown, ArrowUp, ArrowDown, Clock, CheckCircle, User, Building, Mail, Phone } from 'lucide-react';
import actionCableService from './services/actionCable';
import sessionManager from './services/sessionManager';

interface CustomerInsight {
  id: string;
  companyName: string;
  industry: string;
  extractedNeeds: string[];
  sentimentScore: number;
  urgencyLevel: number;
  contractProbability: number;
  lastContact: string;
  estimatedValue: string;
  keyInsights: string;
  customerType: 'new' | 'existing';
}

interface SentimentData {
  id: string;
  companyName: string;
  score: number;
  category: 'high' | 'low';
  feedback: string;
  date: string;
  issue?: string;
}

interface PendingChat {
  id: string | number; // データベースのIDは数値
  companyName: string;
  contactName: string;
  email: string;
  phone?: string;
  message: string;
  category: string;
  timestamp: string;
  responseType: 'immediate' | 'later' | null;
  status: 'pending' | 'responding' | 'completed';
  customerType: 'new' | 'existing';
}

const CustomerInsightDashboard: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'overview' | 'needs' | 'sentiment' | 'pending'>('overview');
  const [pendingChats, setPendingChats] = useState<PendingChat[]>([]);
  const [selectedChat, setSelectedChat] = useState<PendingChat | null>(null);
  const [showResponseModal, setShowResponseModal] = useState(false);
  const [chatFilter, setChatFilter] = useState<'new' | 'existing'>('new');
  const [showReplyModal, setShowReplyModal] = useState(false);
  const [replyMessage, setReplyMessage] = useState('');
  const [needsPreviews, setNeedsPreviews] = useState<any[]>([]);

  // カテゴリー名のマッピング（英語キーと日本語表示名の両方に対応）
  const categoryDisplayNames: { [key: string]: string } = {
    // 新規顧客用（英語キー）
    'service': '🏢 サービス概要',
    'tech': '💻 技術・システム',
    'marketing': '📈 マーケティング',
    'project': '👥 プロジェクト',
    'cost': '💰 費用・契約',
    'case': '🏆 実績・事例',
    'consultation': '💬 初回相談',
    // 既存顧客用
    'cdp': '📊 CDP運用',
    'ma_crm': '📧 MA/CRM最適化',
    'advertising': '📢 Web広告運用',
    'analytics': '📈 データ分析',
    'development': '⚙️ システム開発',
    'ecommerce': '🛒 ECサイト運営',
    'ai_ml': '🤖 AI・機械学習',
    'organization': '👥 組織・体制',
    'competition': '🎯 競合対策',
    // 日本語キー（後方互換性）
    'サービス概要・能力範囲': '🏢 サービス概要',
    '技術・システム関連': '💻 技術・システム',
    'マーケティング戦略': '📈 マーケティング',
    'プロジェクト進行・体制': '👥 プロジェクト',
    '費用・契約': '💰 費用・契約',
    '実績・事例': '🏆 実績・事例',
    '初回相談・問い合わせ': '💬 初回相談',
    'サポート': '🛠️ サポート',
    'その他': '📝 その他'
  };

  // モックデータ
  const highProbabilityDeals: CustomerInsight[] = [
    {
      id: '1',
      companyName: '株式会社テックソリューション',
      industry: 'IT',
      extractedNeeds: ['データ統合', 'レポート自動化', 'コスト削減'],
      sentimentScore: 0.8,
      urgencyLevel: 4,
      contractProbability: 85,
      lastContact: '2025-08-28 14:23',
      estimatedValue: '',
      keyInsights: '競合3社比較中、機能面で当社が優位。来月決定予定',
      customerType: 'new'
    },
    {
      id: '2',
      companyName: 'グローバル商事株式会社',
      industry: '商社',
      extractedNeeds: ['多拠点連携', 'セキュリティ強化'],
      sentimentScore: 0.7,
      urgencyLevel: 5,
      contractProbability: 78,
      lastContact: '2025-08-27 09:45',
      estimatedValue: '',
      keyInsights: '現行システム保守切れ迫る。6ヶ月以内の移行が必須',
      customerType: 'new'
    },
    {
      id: '3',
      companyName: 'マニュファクチャリング東日本',
      industry: '製造',
      extractedNeeds: ['業務効率化', 'リアルタイム分析'],
      sentimentScore: 0.6,
      urgencyLevel: 3,
      contractProbability: 72,
      lastContact: '2025-08-26 16:12',
      estimatedValue: '',
      keyInsights: 'IPO準備でガバナンス強化必要。監査対応できる機能を重視',
      customerType: 'new'
    }
  ];

  const highSatisfactionCustomers: SentimentData[] = [
    {
      id: '1',
      companyName: 'アドバンス株式会社',
      score: 0.9,
      category: 'high',
      feedback: 'サポート対応が迅速で助かっています',
      date: '2025-08-28'
    },
    {
      id: '2', 
      companyName: 'フューチャーシステムズ',
      score: 0.8,
      category: 'high',
      feedback: '新機能のダッシュボードが使いやすい',
      date: '2025-08-27'
    },
    {
      id: '3',
      companyName: 'エンタープライズ・ソリューション',
      score: 0.8,
      category: 'high', 
      feedback: 'データ分析機能で業務効率が大幅改善',
      date: '2025-08-26'
    }
  ];

  // モックデータ：要対応チャット
  const mockPendingChats: PendingChat[] = [
    {
      id: 'chat-1',
      companyName: '株式会社デジタルイノベーション',
      contactName: '田中太郎',
      email: 'tanaka@digital-innovation.jp',
      phone: '03-1234-5678',
      message: 'AIを活用した営業支援システムを探しています。月次レポートの自動生成と商談予測機能が必須です。',
      category: 'AIソリューション',
      timestamp: '2025-08-30 10:23',
      responseType: null,
      status: 'pending',
      customerType: 'new'
    },
    {
      id: 'chat-2',
      companyName: 'グローバルテック株式会社',
      contactName: '佐藤花子',
      email: 'sato@globaltech.co.jp',
      message: '現在のシステムが老朽化しており、クラウド移行を検討中です。セキュリティとコストが気になります。',
      category: 'クラウド移行',
      timestamp: '2025-08-30 09:45',
      responseType: 'immediate',
      status: 'responding',
      customerType: 'new'
    },
    {
      id: 'chat-3',
      companyName: 'スマートソリューションズ',
      contactName: '鈴木一郎',
      email: 'suzuki@smart-solutions.com',
      phone: '06-9876-5432',
      message: '業務効率化のためのワークフロー自動化ツールを導入したいです。',
      category: '業務効率化',
      timestamp: '2025-08-30 08:30',
      responseType: 'later',
      status: 'pending',
      customerType: 'new'
    },
    {
      id: 'chat-4',
      companyName: 'フューチャーシステムズ',
      contactName: '山田次郎',
      email: 'yamada@future-systems.com',
      phone: '045-555-1234',
      message: '現在利用中のダッシュボード機能に新しい分析指標を追加したいです。カスタマイズは可能でしょうか？',
      category: '機能追加',
      timestamp: '2025-08-30 11:15',
      responseType: null,
      status: 'pending',
      customerType: 'existing'
    },
    {
      id: 'chat-5',
      companyName: 'アドバンス株式会社',
      contactName: '高橋美香',
      email: 'takahashi@advance.co.jp',
      message: '契約更新の時期が近づいていますが、プランの見直しを検討しています。上位プランの詳細を教えてください。',
      category: '契約更新',
      timestamp: '2025-08-30 10:45',
      responseType: null,
      status: 'pending',
      customerType: 'existing'
    },
    {
      id: 'chat-6',
      companyName: 'ビジネスパートナーズ',
      contactName: '伊藤健一',
      email: 'ito@business-partners.jp',
      phone: '06-7777-8888',
      message: 'システムのレスポンスが遅いとユーザーから報告がありました。パフォーマンスの改善をお願いします。',
      category: '技術サポート',
      timestamp: '2025-08-30 09:30',
      responseType: 'immediate',
      status: 'responding',
      customerType: 'existing'
    }
  ];

  // useEffectフックでデータベースからデータを取得
  React.useEffect(() => {
    const fetchConversations = async () => {
      try {
        // ユーザーIDを取得
        const userId = sessionManager.getUserId();
        
        // APIから会話データを取得
        const response = await fetch('http://localhost:3000/api/v1/conversations', {
          headers: {
            'Content-Type': 'application/json',
            'X-User-Id': userId
          },
          credentials: 'include'
        });
        
        if (response.ok) {
          const data = await response.json();
          
          // データベースの会話をPendingChat形式に変換
          const conversationsWithMessages = data.conversations
            .filter((conv: any) => conv.messages && conv.messages.length > 0)
            .map((conv: any) => {
              const lastMessage = conv.messages[conv.messages.length - 1];
              const firstUserMessage = conv.messages.find((m: any) => m.role === 'user');
              
              // まずmetadataから情報を取得
              let formData = {
                companyName: conv.metadata?.company || '不明',
                contactName: conv.metadata?.contactName || '不明',
                email: conv.metadata?.email || '不明',
                phone: conv.metadata?.phone || '',
                category: conv.metadata?.category || '一般'
              };
              
              // metadataがない場合はメッセージから抽出
              if (!conv.metadata?.company && firstUserMessage && firstUserMessage.content) {
                const content = firstUserMessage.content;
                // コロンの前後のスペースも考慮
                const companyMatch = content.match(/会社名[:：]\s*(.+?)(?:\n|$)/);
                const nameMatch = content.match(/お名前[:：]\s*(.+?)(?:\n|$)/);
                const emailMatch = content.match(/メールアドレス[:：]\s*(.+?)(?:\n|$)/);
                const phoneMatch = content.match(/電話番号[:：]\s*(.+?)(?:\n|$)/);
                const categoryMatch = content.match(/お問い合わせカテゴリ[:：]\s*(.+?)(?:\n|$)/);
                const messageMatch = content.match(/お問い合わせ内容[:：]\s*([\s\S]+?)(?:\n\n|$)/);
                
                if (companyMatch) formData.companyName = companyMatch[1].trim();
                if (nameMatch) formData.contactName = nameMatch[1].trim();
                if (emailMatch) formData.email = emailMatch[1].trim();
                if (phoneMatch) formData.phone = phoneMatch[1].trim();
                if (categoryMatch) formData.category = categoryMatch[1].trim();
              }
              
              // メッセージ内容を取得
              let messageContent = '内容なし';
              if (firstUserMessage && firstUserMessage.content) {
                const messageMatch = firstUserMessage.content.match(/お問い合わせ内容[:：]\s*([\s\S]+?)(?:\n\n|$)/);
                if (messageMatch) {
                  messageContent = messageMatch[1].trim();
                } else if (!firstUserMessage.content.includes('会社名')) {
                  // フォームデータでない場合は全体をメッセージとして扱う
                  messageContent = firstUserMessage.content;
                }
              }
              
              // 新規/既存の判定：metadataのcustomerTypeまたはguest_user_idの有無で判定
              const isNewCustomer = conv.metadata?.customerType === 'new' || !conv.guest_user_id;
              
              return {
                id: conv.id, // 数値のID
                companyName: formData.companyName,
                contactName: formData.contactName,
                email: formData.email,
                phone: formData.phone,
                message: messageContent,
                category: formData.category,
                timestamp: new Date(conv.updated_at).toLocaleString('ja-JP'),
                responseType: conv.metadata?.responseType || null,
                status: conv.metadata?.responseType ? 'responding' : (conv.status === 'active' ? 'pending' : 'completed'),
                customerType: isNewCustomer ? 'new' : 'existing'
              };
            });
          
          // 既存のローカル状態とマージ（responseTypeを保持）
          setPendingChats(prevChats => {
            return conversationsWithMessages.map(newChat => {
              // 既存のチャットを探す
              const existingChat = prevChats.find(c => c.id === newChat.id);
              
              // responseTypeが既に設定されている場合は保持
              if (existingChat && existingChat.responseType) {
                return {
                  ...newChat,
                  responseType: existingChat.responseType,
                  status: existingChat.status
                };
              }
              
              return newChat;
            });
          });
        } else {
          console.error('Failed to fetch conversations:', response.status);
          // エラー時はモックデータを使用
          setPendingChats(mockPendingChats);
        }
      } catch (error) {
        console.error('Error fetching conversations:', error);
        // エラー時はモックデータを使用
        setPendingChats(mockPendingChats);
      }
    };
    
    // 初回データ取得
    fetchConversations();
    // needs_preview の取得
    const fetchNeedsPreviews = async () => {
      try {
        const res = await fetch('http://localhost:3000/api/v1/needs_previews?limit=20', {
          credentials: 'include',
          headers: {
            'Content-Type': 'application/json',
            'X-User-Id': sessionManager.getUserId()
          }
        });
        if (res.ok) {
          const json = await res.json();
          setNeedsPreviews(json.previews || []);
        } else {
          console.error('Failed to fetch needs previews:', res.status);
          setNeedsPreviews([]);
        }
      } catch (e) {
        console.error('Failed to fetch needs previews', e);
      }
    };
    fetchNeedsPreviews();
    
    // 定期的に更新（10秒ごと）
    const interval = setInterval(() => { fetchConversations(); fetchNeedsPreviews(); }, 10000);
    
    return () => clearInterval(interval);
  }, []);

  const lowSatisfactionCustomers: SentimentData[] = [
    {
      id: '4',
      companyName: 'ビジネスパートナーズ',
      score: 0.3,
      category: 'low',
      feedback: 'システムの動作が重くて困っている',
      date: '2025-08-28',
      issue: 'パフォーマンス問題'
    },
    {
      id: '5',
      companyName: 'トレードマスター',  
      score: 0.2,
      category: 'low',
      feedback: 'ログイン障害が頻発している',
      date: '2025-08-27',
      issue: '技術的問題'
    },
    {
      id: '6',
      companyName: 'グローバルトレード',
      score: 0.4,
      category: 'low',
      feedback: '機能が複雑で使いこなせない',
      date: '2025-08-26', 
      issue: 'ユーザビリティ'
    }
  ];

  const getProbabilityColor = (probability: number) => {
    if (probability >= 80) return 'bg-green-100 text-green-800';
    if (probability >= 60) return 'bg-yellow-100 text-yellow-800';
    return 'bg-red-100 text-red-800';
  };

  const getUrgencyIcon = (level: number) => {
    if (level >= 4) return <ArrowUp className="w-4 h-4 text-red-500" />;
    if (level >= 3) return <ArrowUp className="w-4 h-4 text-yellow-500" />;
    return <ArrowDown className="w-4 h-4 text-gray-400" />;
  };

  const getSentimentDisplay = (score: number): { symbol: string, color: string } => {
    if (score >= 0.8) return { symbol: '◎', color: 'text-green-600' };
    if (score >= 0.6) return { symbol: '○', color: 'text-blue-600' };
    if (score >= 0.4) return { symbol: 'ー', color: 'text-gray-600' };
    if (score >= 0.2) return { symbol: '△', color: 'text-yellow-600' };
    return { symbol: '×', color: 'text-red-600' };
  };

  const getSentimentIcon = (score: number) => {
    if (score >= 0.7) return <Heart className="w-4 h-4 text-green-500" />;
    if (score >= 0.4) return <Heart className="w-4 h-4 text-yellow-500" />;
    return <Frown className="w-4 h-4 text-red-500" />;
  };

  const handleChatResponse = async (chatId: string | number, responseType: 'immediate' | 'later') => {
    // データベースのmetadataを更新
    try {
      const updateResponse = await fetch(`http://localhost:3000/api/v1/conversations/${chatId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': sessionManager.getUserId()
        },
        credentials: 'include',
        body: JSON.stringify({
          conversation: {
            metadata: {
              responseType: responseType
            }
          }
        })
      });
      
      if (!updateResponse.ok) {
        const result = await updateResponse.json();
        console.error('Failed to update conversation metadata:', result);
      }
    } catch (error) {
      console.error('Error updating conversation:', error);
    }
    
    const updatedChats = pendingChats.map(chat => 
      chat.id === chatId 
        ? { ...chat, responseType, status: responseType === 'immediate' ? 'responding' as const : 'pending' as const }
        : chat
    );
    
    setPendingChats(updatedChats);
    
    setShowResponseModal(false);
    
    // 2営業日以内の返信を選択した場合のメッセージ
    if (responseType === 'later') {
      // ActionCableで自動返信メッセージを送信（数値IDを文字列に変換）
      const subscription = actionCableService.subscribeToConversation(String(chatId), {
        onConnected: () => {
          actionCableService.sendMessage({
            content: 'お問い合わせありがとうございます。\n2営業日以内に担当者よりご連絡させていただきます。',
            role: 'company',
            metadata: {
              chatId,
              sender: 'company',
              timestamp: new Date().toISOString()
            }
          });
          
          alert('お客様に「2営業日以内にご連絡いたします」というメッセージが送信されました。');
          setSelectedChat(null);
          
          // 接続を解除
          setTimeout(() => actionCableService.unsubscribe(), 1000);
        }
      });
    } else {
      // 即時対応の場合、返信モーダルを表示
      setShowReplyModal(true);
      setReplyMessage('');
    }
  };

  const handleSendReply = () => {
    if (!replyMessage.trim() || !selectedChat) return;
    
    // ActionCableで企業返信を送信（数値IDを文字列に変換）
    const subscription = actionCableService.subscribeToConversation(String(selectedChat.id), {
      onConnected: () => {
        // 接続後すぐにメッセージを送信
        actionCableService.sendMessage({
          content: replyMessage,
          role: 'company',
          metadata: {
            chatId: selectedChat.id,
            sender: 'company',
            timestamp: new Date().toISOString()
          }
        });
        
        // チャットのステータスを更新
        const updatedChatsAfterReply = pendingChats.map(chat => 
          chat.id === selectedChat.id
            ? { ...chat, status: 'responding' as const }
            : chat
        );
        
        setPendingChats(updatedChatsAfterReply);
        
        // モーダルを閉じる
        setShowReplyModal(false);
        setReplyMessage('');
        alert('返信を送信しました。');
        setSelectedChat(null);
        
        // 接続を解除
        setTimeout(() => actionCableService.unsubscribe(), 1000);
      }
    });
  };

  const handleChatClick = (chat: PendingChat) => {
    // 新しいウィンドウでチャット画面を開く
    window.open(`http://localhost:4000/chat#${chat.id}`, '_blank');
  };

  const getStatusBadge = (status: PendingChat['status'], responseType: PendingChat['responseType']) => {
    if (status === 'completed') {
      return <span className="bg-green-100 text-green-700 text-xs px-2 py-1 rounded">対応済み</span>;
    }
    if (status === 'responding') {
      return <span className="bg-blue-100 text-blue-700 text-xs px-2 py-1 rounded">対応中</span>;
    }
    if (responseType === 'later') {
      return <span className="bg-yellow-100 text-yellow-700 text-xs px-2 py-1 rounded">2営業日以内に返信予定</span>;
    }
    return <span className="bg-red-100 text-red-700 text-xs px-2 py-1 rounded">要対応</span>;
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* ヘッダー */}
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <h1 className="text-2xl font-bold text-gray-900">顧客インサイト分析システム</h1>
          <p className="text-gray-600 mt-1">チャットボット会話データからの自動分析結果</p>
        </div>
      </div>

      {/* タブナビゲーション */}
      <div className="max-w-7xl mx-auto px-6 py-6">
        <div className="bg-white rounded-lg shadow-sm">
          <div className="border-b border-gray-200">
            <nav className="flex space-x-8 px-6">
              <button
                onClick={() => setActiveTab('overview')}
                className={`py-4 px-1 border-b-2 font-medium text-sm ${
                  activeTab === 'overview'
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700'
                }`}
              >
                <div className="flex items-center gap-2">
                  <TrendingUp className="w-4 h-4" />
                  概要ダッシュボード
                </div>
              </button>
              <button
                onClick={() => setActiveTab('needs')}
                className={`py-4 px-1 border-b-2 font-medium text-sm ${
                  activeTab === 'needs'
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700'
                }`}
              >
                <div className="flex items-center gap-2">
                  <Target className="w-4 h-4" />
                  顧客の課題・ニーズ
                </div>
              </button>
              <button
                onClick={() => setActiveTab('sentiment')}
                className={`py-4 px-1 border-b-2 font-medium text-sm ${
                  activeTab === 'sentiment'
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700'
                }`}
              >
                <div className="flex items-center gap-2">
                  <Heart className="w-4 h-4" />
                  顧客満足度分析
                </div>
              </button>
              <button
                onClick={() => setActiveTab('pending')}
                className={`py-4 px-1 border-b-2 font-medium text-sm ${
                  activeTab === 'pending'
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700'
                }`}
              >
                <div className="flex items-center gap-2">
                  <Clock className="w-4 h-4" />
                  要対応チャット
                  {pendingChats.filter(c => c.status === 'pending' && !c.responseType).length > 0 && (
                    <span className="bg-red-500 text-white text-xs px-2 py-0.5 rounded-full">
                      {pendingChats.filter(c => c.status === 'pending' && !c.responseType).length}
                    </span>
                  )}
                </div>
              </button>
            </nav>
          </div>

          {/* 概要ダッシュボード */}
          {activeTab === 'overview' && (
            <div className="p-6">
              <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
                <div className="bg-blue-50 p-6 rounded-lg">
                  <div className="flex items-center">
                    <MessageCircle className="w-8 h-8 text-blue-600" />
                    <div className="ml-4">
                      <p className="text-sm font-medium text-gray-600">今月の問い合わせ</p>
                      <p className="text-2xl font-bold text-gray-900">157件</p>
                    </div>
                  </div>
                </div>
                <div className="bg-green-50 p-6 rounded-lg">
                  <div className="flex items-center">
                    <TrendingUp className="w-8 h-8 text-green-600" />
                    <div className="ml-4">
                      <p className="text-sm font-medium text-gray-600">抽出された課題</p>
                      <p className="text-2xl font-bold text-gray-900">89件</p>
                    </div>
                  </div>
                </div>
                <div className="bg-yellow-50 p-6 rounded-lg">
                  <div className="flex items-center">
                    <AlertTriangle className="w-8 h-8 text-yellow-600" />
                    <div className="ml-4">
                      <p className="text-sm font-medium text-gray-600">要対応</p>
                      <p className="text-2xl font-bold text-gray-900">8件</p>
                    </div>
                  </div>
                </div>
                <div className="bg-purple-50 p-6 rounded-lg">
                  <div className="flex items-center">
                    <Star className="w-8 h-8 text-purple-600" />
                    <div className="ml-4">
                      <p className="text-sm font-medium text-gray-600">平均満足度</p>
                      <p className="text-2xl font-bold text-gray-900">4.2/5</p>
                    </div>
                  </div>
                </div>
              </div>

              {/* クイックアクセス */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="bg-white border rounded-lg p-6">
                  <h3 className="text-lg font-semibold text-gray-900 mb-4">緊急対応が必要な案件</h3>
                  <div className="space-y-3">
                    <div className="flex items-center justify-between p-3 bg-red-50 rounded-lg">
                      <div>
                        <p className="font-medium text-gray-900">ビジネスパートナーズ</p>
                        <p className="text-sm text-gray-600">システム障害で業務停止中</p>
                      </div>
                      <ChevronRight className="w-5 h-5 text-gray-400" />
                    </div>
                    <div className="flex items-center justify-between p-3 bg-yellow-50 rounded-lg">
                      <div>
                        <p className="font-medium text-gray-900">グローバル商事</p>
                        <p className="text-sm text-gray-600">システム移行期限が迫る</p>
                      </div>
                      <ChevronRight className="w-5 h-5 text-gray-400" />
                    </div>
                  </div>
                </div>

                <div className="bg-white border rounded-lg p-6">
                  <h3 className="text-lg font-semibold text-gray-900 mb-4">今週の成果</h3>
                  <div className="space-y-4">
                    <div className="flex justify-between items-center">
                      <span className="text-gray-600">課題を抱えた企業</span>
                      <span className="font-semibold text-green-600">+12社</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-gray-600">解決提案実施</span>
                      <span className="font-semibold text-blue-600">8件</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-gray-600">フォローアップ予定</span>
                      <span className="font-semibold text-purple-600">15件</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* 顧客の課題・ニーズ */}
          {activeTab === 'needs' && (
            <div className="p-6">
              <div className="flex justify-between items-center mb-6">
                <h2 className="text-xl font-semibold text-gray-900">顧客の課題・ニーズ分析</h2>
                <button className="text-blue-600 hover:text-blue-700 text-sm font-medium flex items-center gap-1">
                  すべて表示 <ChevronRight className="w-4 h-4" />
                </button>
              </div>

              {/* needs_preview を表示 */}
              <div className="space-y-4">
                {needsPreviews.map((pv, index) => (
                  <div key={`${pv.conversation_id}-${index}`} className="bg-white border rounded-lg p-6 hover:shadow-md transition-shadow">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <div className="flex items-center gap-3 mb-3">
                          <h3 className="text-lg font-semibold text-gray-900">{pv.company_name || '不明'}</h3>
                          <span className="text-xs bg-emerald-100 text-emerald-700 px-2 py-1 rounded">
                            信頼度 {Math.round((pv.confidence || 0) * 100)}%
                          </span>
                          <span className="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded">
                            会話 #{pv.conversation_id}
                          </span>
                        </div>
                        <div className="grid grid-cols-1 md:grid-cols-1 gap-4 mb-4">
                          <div>
                            <p className="text-sm font-medium text-gray-600 mb-2">推定ニーズ / カテゴリ</p>
                            <div className="flex flex-wrap gap-2 mb-2">
                              <span className="bg-orange-100 text-orange-700 text-xs px-2 py-1 rounded-full">{pv.need_type || 'N/A'}</span>
                              <span className="bg-indigo-100 text-indigo-700 text-xs px-2 py-1 rounded-full">{pv.category || 'N/A'}</span>
                            </div>
                            <p className="text-sm font-medium text-gray-600 mb-1">キーワード</p>
                            <div className="flex flex-wrap gap-1">
                              {(pv.keywords || []).map((k: string, i: number) => (
                                <span key={i} className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full">{k}</span>
                              ))}
                            </div>
                          </div>
                        </div>
                      </div>
                      <div className="ml-6">
                        <button onClick={() => window.open(`http://localhost:4000/chat#${pv.conversation_id}`, '_blank')} className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition-colors">
                          会話を開く
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 要対応チャット */}
          {activeTab === 'pending' && (
            <div className="p-6">
              <div className="flex justify-between items-center mb-6">
                <h2 className="text-xl font-semibold text-gray-900">要対応チャット一覧</h2>
                <div className="flex gap-2 text-sm">
                  <span className="text-gray-600">
                    合計: {pendingChats.filter(c => c.customerType === chatFilter).length}件
                  </span>
                  <span className="text-red-600 font-semibold">
                    未対応: {pendingChats.filter(c => c.customerType === chatFilter && c.status === 'pending' && !c.responseType).length}件
                  </span>
                </div>
              </div>

              {/* 新規顧客/既存顧客フィルタータブ */}
              <div className="flex gap-4 mb-6 border-b border-gray-200">
                <button
                  onClick={() => setChatFilter('new')}
                  className={`pb-3 px-1 text-sm font-medium transition-colors relative ${
                    chatFilter === 'new' 
                      ? 'text-blue-600' 
                      : 'text-gray-500 hover:text-gray-700'
                  }`}
                >
                  新規顧客
                  {chatFilter === 'new' && (
                    <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-600" />
                  )}
                </button>
                <button
                  onClick={() => setChatFilter('existing')}
                  className={`pb-3 px-1 text-sm font-medium transition-colors relative ${
                    chatFilter === 'existing' 
                      ? 'text-blue-600' 
                      : 'text-gray-500 hover:text-gray-700'
                  }`}
                >
                  既存顧客
                  {chatFilter === 'existing' && (
                    <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-600" />
                  )}
                </button>
              </div>

              <div className="space-y-4">
                {pendingChats
                  .filter(chat => chat.customerType === chatFilter)
                  .map((chat) => (
                  <div key={chat.id} className="bg-white border rounded-lg p-6 hover:shadow-md transition-shadow">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <div className="flex items-center gap-3 mb-3">
                          <h3 className="text-lg font-semibold text-gray-900">{chat.companyName}</h3>
                          {/* カテゴリー表示を強調 */}
                          {chat.customerType === 'new' && (
                            <span className="bg-gradient-to-r from-blue-500 to-indigo-500 text-white text-xs px-3 py-1 rounded-full font-medium shadow-sm">
                              {categoryDisplayNames[chat.category] || chat.category}
                            </span>
                          )}
                          {chat.customerType === 'existing' && chat.category && (
                            <span className="bg-gradient-to-r from-green-500 to-emerald-500 text-white text-xs px-3 py-1 rounded-full font-medium shadow-sm">
                              {categoryDisplayNames[chat.category] || chat.category}
                            </span>
                          )}
                          {getStatusBadge(chat.status, chat.responseType)}
                        </div>
                        
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                          <div className="flex items-center gap-2 text-sm text-gray-600">
                            <User className="w-4 h-4" />
                            <span>{chat.contactName}</span>
                          </div>
                          <div className="flex items-center gap-2 text-sm text-gray-600">
                            <Mail className="w-4 h-4" />
                            <span>{chat.email}</span>
                          </div>
                          {chat.phone && (
                            <div className="flex items-center gap-2 text-sm text-gray-600">
                              <Phone className="w-4 h-4" />
                              <span>{chat.phone}</span>
                            </div>
                          )}
                          <div className="flex items-center gap-2 text-sm text-gray-600">
                            <Clock className="w-4 h-4" />
                            <span>{chat.timestamp}</span>
                          </div>
                        </div>

                        <div className="bg-gray-50 rounded-lg p-4 mb-4">
                          <p className="text-sm font-semibold text-gray-700 mb-2">お問い合わせ内容：</p>
                          <p className="text-sm text-gray-800">{chat.message}</p>
                        </div>
                      </div>
                    </div>

                    <div className="flex gap-3">
                      {/* 未対応の場合のみ「対応開始」ボタンを表示 */}
                      {chat.status === 'pending' && !chat.responseType && (
                        <button
                          onClick={() => {
                            setSelectedChat(chat);
                            setShowResponseModal(true);
                          }}
                          className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition-colors"
                        >
                          対応開始
                        </button>
                      )}
                      
                      {/* 対応済み（即時対応 or 2営業日以内）の場合のみ「チャットを確認」ボタンを表示 */}
                      {(chat.responseType === 'immediate' || chat.responseType === 'later' || chat.status === 'responding') && (
                        <button
                          onClick={() => handleChatClick(chat)}
                          className="bg-gray-100 text-gray-700 px-4 py-2 rounded-lg text-sm hover:bg-gray-200 transition-colors"
                        >
                          チャットを確認
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>

              {/* 対応選択モーダル */}
              {showResponseModal && selectedChat && (
                <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
                  <div className="bg-white rounded-lg p-6 max-w-md w-full">
                    <h3 className="text-lg font-semibold text-gray-900 mb-4">
                      ⚡ 担当者への通知
                    </h3>
                    <p className="text-gray-700 mb-6">
                      {selectedChat.companyName}様からの問い合わせにどのように対応しますか？
                    </p>
                    <div className="space-y-3">
                      <button
                        onClick={() => handleChatResponse(selectedChat.id, 'immediate')}
                        className="w-full bg-green-600 text-white px-4 py-3 rounded-lg hover:bg-green-700 transition-colors text-left"
                      >
                        <div className="font-semibold">すぐに対応する</div>
                        <div className="text-sm opacity-90 mt-1">担当者がすぐにチャットで返信します</div>
                      </button>
                      <button
                        onClick={() => handleChatResponse(selectedChat.id, 'later')}
                        className="w-full bg-blue-600 text-white px-4 py-3 rounded-lg hover:bg-blue-700 transition-colors text-left"
                      >
                        <div className="font-semibold">2営業日以内に返信</div>
                        <div className="text-sm opacity-90 mt-1">自動で「2営業日以内にご連絡いたします」と返信</div>
                      </button>
                      <button
                        onClick={() => {
                          setShowResponseModal(false);
                          setSelectedChat(null);
                        }}
                        className="w-full bg-gray-200 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-300 transition-colors"
                      >
                        キャンセル
                      </button>
                    </div>
                  </div>
                </div>
              )}

              {/* 返信モーダル */}
              {showReplyModal && selectedChat && (
                <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
                  <div className="bg-white rounded-lg p-6 max-w-2xl w-full">
                    <h3 className="text-lg font-semibold text-gray-900 mb-4">
                      💬 チャット返信
                    </h3>
                    <div className="mb-4">
                      <p className="text-sm text-gray-600">返信先: {selectedChat.companyName}様</p>
                      <div className="mt-2 p-3 bg-gray-50 rounded-lg">
                        <p className="text-sm text-gray-700">
                          <strong>お問い合わせ内容:</strong><br />
                          {selectedChat.message}
                        </p>
                      </div>
                    </div>
                    <div className="mb-4">
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        返信メッセージ
                      </label>
                      <textarea
                        value={replyMessage}
                        onChange={(e) => setReplyMessage(e.target.value)}
                        className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        rows={6}
                        placeholder="お客様への返信メッセージを入力してください..."
                      />
                    </div>
                    <div className="flex gap-3 justify-end">
                      <button
                        onClick={() => {
                          setShowReplyModal(false);
                          setReplyMessage('');
                        }}
                        className="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors"
                      >
                        キャンセル
                      </button>
                      <button
                        onClick={handleSendReply}
                        disabled={!replyMessage.trim()}
                        className={`px-4 py-2 rounded-lg transition-colors ${
                          replyMessage.trim()
                            ? 'bg-blue-600 text-white hover:bg-blue-700'
                            : 'bg-gray-300 text-gray-500 cursor-not-allowed'
                        }`}
                      >
                        送信
                      </button>
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* 顧客満足度分析 */}
          {activeTab === 'sentiment' && (
            <div className="p-6">
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                {/* 高満足度顧客 */}
                <div>
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-lg font-semibold text-green-700 flex items-center gap-2">
                      <Heart className="w-5 h-5" />
                      高満足度顧客
                    </h3>
                    <button className="text-green-600 hover:text-green-700 text-sm font-medium flex items-center gap-1">
                      すべて表示 <ChevronRight className="w-4 h-4" />
                    </button>
                  </div>
                  
                  <div className="space-y-3">
                    {highSatisfactionCustomers.map((customer) => (
                      <div key={customer.id} className="bg-green-50 border border-green-200 rounded-lg p-4">
                        <div className="flex items-start justify-between mb-2">
                          <div>
                            <h4 className="font-medium text-gray-900">{customer.companyName}</h4>
                            <div className="flex items-center gap-2 mt-1">
                                <span className={`font-bold text-lg ${getSentimentDisplay(customer.score).color}`}>
                              {getSentimentDisplay(customer.score).symbol}
                            </span>
                              <span className="text-sm text-gray-600">
                                満足度: 
                              <span className={`font-bold ml-1 ${getSentimentDisplay(customer.score).color}`}>
                                {getSentimentDisplay(customer.score).symbol}
                              </span>
                              </span>
                            </div>
                          </div>
                          <span className="text-xs text-gray-500">{customer.date}</span>
                        </div>
                        <p className="text-sm text-gray-700 italic">"{customer.feedback}"</p>
                      </div>
                    ))}
                  </div>
                </div>

                {/* 低満足度顧客 */}
                <div>
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-lg font-semibold text-red-700 flex items-center gap-2">
                      <AlertTriangle className="w-5 h-5" />
                      要改善顧客
                    </h3>
                    <button className="text-red-600 hover:text-red-700 text-sm font-medium flex items-center gap-1">
                      すべて表示 <ChevronRight className="w-4 h-4" />
                    </button>
                  </div>
                  
                  <div className="space-y-3">
                    {lowSatisfactionCustomers.map((customer) => (
                      <div key={customer.id} className="bg-red-50 border border-red-200 rounded-lg p-4">
                        <div className="flex items-start justify-between mb-2">
                          <div>
                            <h4 className="font-medium text-gray-900">{customer.companyName}</h4>
                            <div className="flex items-center gap-2 mt-1">
                              {getSentimentIcon(customer.score)}
                              <span className="text-sm text-gray-600">
                                満足度: 
                              <span className={`font-bold ml-1 ${getSentimentDisplay(customer.score).color}`}>
                                {getSentimentDisplay(customer.score).symbol}
                              </span>
                              </span>
                              {customer.issue && (
                                <span className="bg-red-100 text-red-700 text-xs px-2 py-1 rounded">
                                  {customer.issue}
                                </span>
                              )}
                            </div>
                          </div>
                          <span className="text-xs text-gray-500">{customer.date}</span>
                        </div>
                        <p className="text-sm text-gray-700 italic">"{customer.feedback}"</p>
                        <button className="mt-2 bg-red-600 text-white px-3 py-1 rounded text-xs hover:bg-red-700">
                          緊急対応
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default CustomerInsightDashboard;