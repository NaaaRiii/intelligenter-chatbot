import React, { useState } from 'react';
import { TrendingUp, Users, MessageCircle, Star, AlertTriangle, Eye, ChevronRight, Calendar, Target, Heart, Frown, ArrowUp, ArrowDown } from 'lucide-react';

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

const CustomerInsightDashboard: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'overview' | 'needs' | 'sentiment'>('overview');

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

                              <div className="space-y-4">
                {highProbabilityDeals.map((deal, index) => (
                  <div key={deal.id} className="bg-white border rounded-lg p-6 hover:shadow-md transition-shadow">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <div className="flex items-center gap-3 mb-3">
                          <h3 className="text-lg font-semibold text-gray-900">{deal.companyName}</h3>
                          <span className="text-sm text-gray-500">({deal.industry})</span>
                          <span className="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded">
                            {deal.customerType === 'new' ? '新規' : '既存'}
                          </span>
                        </div>
                        
                        <div className="grid grid-cols-1 md:grid-cols-1 gap-4 mb-4">
                          <div>
                            <p className="text-sm font-medium text-gray-600 mb-2">抽出されたニーズ・課題</p>
                            <div className="flex flex-wrap gap-1 mb-4">
                              {deal.extractedNeeds.map((need, idx) => (
                                <span key={idx} className="bg-orange-100 text-orange-700 text-sm px-3 py-1 rounded-full font-medium">
                                  {need}
                                </span>
                              ))}
                            </div>
                          </div>
                          
                          {/* キーインサイトを強調表示 */}
                          <div className="bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-lg p-4">
                            <p className="text-sm font-semibold text-blue-700 mb-2 flex items-center gap-1">
                              <Eye className="w-4 h-4" />
                              重要なインサイト
                            </p>
                            <p className="text-sm text-blue-800 leading-relaxed">{deal.keyInsights}</p>
                          </div>
                        </div>

                        <div className="flex items-center gap-6 text-sm">
                          <div className="flex items-center gap-1">
                            <Calendar className="w-4 h-4 text-gray-400" />
                            <span className="text-gray-600">最終問い合わせ日時: {deal.lastContact}</span>
                          </div>
                        </div>
                      </div>

                      <div className="ml-6">
                        <button className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition-colors">
                          詳細分析を見る
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
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