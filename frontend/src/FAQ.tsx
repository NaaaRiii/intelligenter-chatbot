import React, { useState } from 'react';
import { ChevronDown, ChevronUp, HelpCircle, ArrowLeft, DollarSign, Settings, Shield, Wrench } from 'lucide-react';

interface FAQItem {
  question: string;
  answer: string;
  category: string;
}

const FAQ: React.FC = () => {
  const [expandedItems, setExpandedItems] = useState<number[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<string>('all');

  const faqData: FAQItem[] = [
    // サービス・料金について
    {
      question: '無料トライアルはありますか？',
      answer: 'はい、14日間の無料トライアルをご用意しています。クレジットカード登録不要でお試しいただけます。',
      category: 'service'
    },
    {
      question: '料金プランを教えてください',
      answer: 'スタータープラン（月額10,000円）、スタンダードプラン（月額30,000円）、エンタープライズプラン（要相談）をご用意しています。',
      category: 'service'
    },
    {
      question: '最低契約期間はありますか？',
      answer: '最低契約期間は3ヶ月となっております。それ以降は月単位で解約可能です。',
      category: 'service'
    },
    // 導入・セットアップ
    {
      question: '導入までどのくらいかかりますか？',
      answer: 'お申し込みから最短3営業日で導入可能です。データ移行が必要な場合は1-2週間程度かかります。',
      category: 'setup'
    },
    {
      question: '既存システムとの連携は可能ですか？',
      answer: 'はい、主要なCRM・ERPシステムとのAPI連携に対応しています。詳細はお問い合わせください。',
      category: 'setup'
    },
    {
      question: '社内研修は必要ですか？',
      answer: 'オンボーディングサポートを無料で提供しており、導入時に操作説明会を実施します。',
      category: 'setup'
    },
    // セキュリティ・サポート
    {
      question: 'データのセキュリティは大丈夫ですか？',
      answer: 'ISO27001認証取得済み、データは暗号化して国内データセンターに保管しています。',
      category: 'security'
    },
    {
      question: 'サポート体制について教えてください',
      answer: '平日9:00-18:00のメール・チャットサポート、エンタープライズプランは24時間電話サポート付きです。',
      category: 'security'
    },
    {
      question: '障害時の対応は？',
      answer: 'SLA99.9%を保証。障害発生時は1時間以内に初期対応、ステータスページで随時情報更新します。',
      category: 'security'
    },
    // 機能・仕様
    {
      question: 'ユーザー数に制限はありますか？',
      answer: 'プランによって異なります。スタータープラン：5名、スタンダードプラン：20名、エンタープライズプラン：無制限。',
      category: 'features'
    },
    {
      question: 'モバイルアプリはありますか？',
      answer: 'iOS/Android対応のネイティブアプリを提供しています。App Store/Google Playからダウンロード可能です。',
      category: 'features'
    },
    {
      question: 'データのエクスポートは可能ですか？',
      answer: 'はい、CSV/Excel形式でのデータエクスポートに対応しています。APIでの自動取得も可能です。',
      category: 'features'
    }
  ];

  const categories = [
    { id: 'all', name: 'すべて', icon: HelpCircle },
    { id: 'service', name: 'サービス・料金', icon: DollarSign },
    { id: 'setup', name: '導入・セットアップ', icon: Settings },
    { id: 'security', name: 'セキュリティ・サポート', icon: Shield },
    { id: 'features', name: '機能・仕様', icon: Wrench }
  ];

  const filteredFAQs = selectedCategory === 'all' 
    ? faqData 
    : faqData.filter(item => item.category === selectedCategory);

  const toggleExpand = (index: number) => {
    setExpandedItems(prev => 
      prev.includes(index) 
        ? prev.filter(i => i !== index)
        : [...prev, index]
    );
  };

  const handleBackToChat = () => {
    // 新規顧客として直接チャット画面へ遷移（カテゴリー選択から）
    window.location.href = '/chat/new';
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <div className="container mx-auto px-4 py-8 max-w-4xl">
        {/* ヘッダー */}
        <div className="bg-white rounded-xl shadow-lg p-6 mb-6">
          <button
            onClick={handleBackToChat}
            className="flex items-center gap-2 text-blue-600 hover:text-blue-700 mb-4 transition-colors"
          >
            <ArrowLeft size={20} />
            <span>チャットに戻る</span>
          </button>
          
          <div className="text-center">
            <HelpCircle className="w-12 h-12 text-blue-600 mx-auto mb-3" />
            <h1 className="text-3xl font-bold text-gray-800 mb-2">よくある質問</h1>
            <p className="text-gray-600">お探しの質問をクリックしてください</p>
          </div>
        </div>

        {/* カテゴリーフィルター */}
        <div className="bg-white rounded-xl shadow-lg p-4 mb-6">
          <div className="flex flex-wrap gap-2 justify-center">
            {categories.map(cat => {
              const Icon = cat.icon;
              return (
                <button
                  key={cat.id}
                  onClick={() => setSelectedCategory(cat.id)}
                  className={`flex items-center gap-2 px-4 py-2 rounded-lg transition-all ${
                    selectedCategory === cat.id
                      ? 'bg-blue-600 text-white shadow-md transform scale-105'
                      : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                  }`}
                >
                  <Icon size={18} />
                  <span className="text-sm font-medium">{cat.name}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* FAQ リスト */}
        <div className="space-y-3">
          {filteredFAQs.map((item, index) => (
            <div
              key={index}
              className="bg-white rounded-xl shadow-md hover:shadow-lg transition-all duration-300"
            >
              <button
                onClick={() => toggleExpand(index)}
                className="w-full px-6 py-4 flex items-center justify-between text-left hover:bg-gray-50 rounded-xl transition-colors"
              >
                <div className="flex items-start gap-3 flex-1">
                  <div className="mt-1">
                    <div className="w-6 h-6 bg-blue-100 rounded-full flex items-center justify-center flex-shrink-0">
                      <span className="text-blue-600 text-xs font-bold">Q</span>
                    </div>
                  </div>
                  <h3 className="font-semibold text-gray-800 pr-4">{item.question}</h3>
                </div>
                <div className="flex-shrink-0">
                  {expandedItems.includes(index) ? (
                    <ChevronUp className="w-5 h-5 text-blue-600" />
                  ) : (
                    <ChevronDown className="w-5 h-5 text-gray-400" />
                  )}
                </div>
              </button>
              
              {expandedItems.includes(index) && (
                <div className="px-6 pb-4 animate-fadeIn">
                  <div className="flex gap-3">
                    <div className="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center flex-shrink-0 mt-1">
                      <span className="text-green-600 text-xs font-bold">A</span>
                    </div>
                    <p className="text-gray-700 leading-relaxed">{item.answer}</p>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>

        {/* お問い合わせCTA */}
        <div className="mt-8 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-xl shadow-lg p-6 text-white text-center">
          <h2 className="text-xl font-bold mb-2">お探しの答えが見つかりませんか？</h2>
          <p className="mb-4 opacity-90">カスタマーサポートがお手伝いします</p>
          <button
            onClick={handleBackToChat}
            className="bg-white text-blue-600 px-6 py-3 rounded-lg font-semibold hover:bg-gray-100 transition-colors shadow-md"
          >
            チャットで問い合わせる
          </button>
        </div>
      </div>

      <style jsx>{`
        @keyframes fadeIn {
          from {
            opacity: 0;
            max-height: 0;
          }
          to {
            opacity: 1;
            max-height: 200px;
          }
        }
        .animate-fadeIn {
          animation: fadeIn 0.3s ease-in-out;
        }
      `}</style>
    </div>
  );
};

export default FAQ;