import React, { useState } from 'react';
import { ChevronRight, Search, Book, Settings, CreditCard, Users, Shield, HelpCircle, FileText, AlertCircle } from 'lucide-react';

interface FAQItem {
  id: string;
  question: string;
  answer: string;
  category: string;
}

const ExistingCustomerFAQ: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [expandedItems, setExpandedItems] = useState<Set<string>>(new Set());

  const categories = [
    { id: 'all', name: 'すべて', icon: Book },
    { id: 'account', name: 'アカウント管理', icon: Users },
    { id: 'billing', name: '請求・支払い', icon: CreditCard },
    { id: 'technical', name: '技術的な問題', icon: Settings },
    { id: 'security', name: 'セキュリティ', icon: Shield },
    { id: 'contract', name: '契約・解約', icon: FileText },
    { id: 'other', name: 'その他', icon: HelpCircle },
  ];

  const faqItems: FAQItem[] = [
    // アカウント管理
    {
      id: '1',
      category: 'account',
      question: 'パスワードを忘れてしまいました',
      answer: 'ログイン画面の「パスワードをお忘れの方」リンクから、登録メールアドレスを入力してください。パスワードリセット用のメールをお送りします。メールが届かない場合は、迷惑メールフォルダをご確認いただくか、サポートまでお問い合わせください。'
    },
    {
      id: '2',
      category: 'account',
      question: 'ユーザーを追加したい',
      answer: '管理画面の「ユーザー管理」セクションから「新規ユーザー追加」をクリックし、必要な情報を入力してください。追加可能なユーザー数は契約プランによって異なります。上限に達している場合は、プランのアップグレードをご検討ください。'
    },
    {
      id: '3',
      category: 'account',
      question: '二段階認証を設定したい',
      answer: 'アカウント設定の「セキュリティ」タブから二段階認証を有効にできます。Google AuthenticatorまたはMicrosoft Authenticatorアプリをご利用いただけます。設定後は必ずバックアップコードを安全な場所に保管してください。'
    },
    
    // 請求・支払い
    {
      id: '4',
      category: 'billing',
      question: '請求書の発行をお願いしたい',
      answer: '管理画面の「請求履歴」から対象月を選択し、「請求書をダウンロード」ボタンをクリックしてください。PDFフォーマットでダウンロードできます。郵送をご希望の場合は、サポートまでご連絡ください。'
    },
    {
      id: '5',
      category: 'billing',
      question: '支払い方法を変更したい',
      answer: 'アカウント設定の「支払い情報」から変更可能です。クレジットカード、銀行振込、請求書払いに対応しています。変更は翌月の請求から反映されます。'
    },
    {
      id: '6',
      category: 'billing',
      question: 'プランをアップグレード/ダウングレードしたい',
      answer: '管理画面の「プラン管理」から変更できます。アップグレードは即座に反映され、差額は日割り計算されます。ダウングレードは次回更新時に適用されます。データ容量にご注意ください。'
    },
    
    // 技術的な問題
    {
      id: '7',
      category: 'technical',
      question: 'システムにログインできません',
      answer: '以下をご確認ください：\n1. インターネット接続が正常か\n2. ブラウザのキャッシュをクリアする\n3. 別のブラウザで試す\n4. ファイアウォール設定を確認\n問題が続く場合は、エラーメッセージと共にサポートへご連絡ください。'
    },
    {
      id: '8',
      category: 'technical',
      question: 'データのエクスポート方法を教えてください',
      answer: 'データ管理画面から「エクスポート」を選択し、形式（CSV、Excel、JSON）を選んでください。大量データの場合は、処理完了後にメールでダウンロードリンクをお送りします。'
    },
    {
      id: '9',
      category: 'technical',
      question: 'APIの利用制限はありますか',
      answer: '契約プランによって異なりますが、基本的には以下の制限があります：\n- スタンダード：1,000回/時\n- プロ：5,000回/時\n- エンタープライズ：無制限\n詳細はAPI ドキュメントをご参照ください。'
    },
    
    // セキュリティ
    {
      id: '10',
      category: 'security',
      question: '不正アクセスの疑いがあります',
      answer: '直ちに以下の対応をお願いします：\n1. パスワードを変更\n2. 二段階認証を有効化\n3. アクセスログを確認\n4. 不審なアクティビティをサポートに報告\n当社セキュリティチームが調査いたします。'
    },
    {
      id: '11',
      category: 'security',
      question: 'データのバックアップ頻度は？',
      answer: 'データは以下の頻度でバックアップされています：\n- リアルタイムレプリケーション\n- 日次バックアップ（30日間保持）\n- 週次バックアップ（90日間保持）\n- 月次バックアップ（1年間保持）'
    },
    
    // 契約・解約
    {
      id: '12',
      category: 'contract',
      question: '契約を解約したい',
      answer: '解約は30日前までにお申し出ください。管理画面の「契約管理」から解約申請フォームをご提出いただくか、カスタマーサポートまでご連絡ください。データのエクスポートは解約前に必ず行ってください。'
    },
    {
      id: '13',
      category: 'contract',
      question: '契約更新の流れを教えてください',
      answer: '契約期限の60日前に更新のご案内をメールでお送りします。自動更新設定の場合は、特別な手続きは不要です。契約内容の変更をご希望の場合は、30日前までにご連絡ください。'
    },
    
    // その他
    {
      id: '14',
      category: 'other',
      question: 'サポートの営業時間は？',
      answer: '平日9:00-18:00（土日祝日を除く）です。緊急時は24時間対応のエマージェンシーラインをご利用いただけます（エンタープライズプランのみ）。メールでのお問い合わせは24時間受け付けています。'
    },
    {
      id: '15',
      category: 'other',
      question: 'トレーニングや研修はありますか？',
      answer: '定期的にオンラインセミナーを開催しています。また、オンデマンドのトレーニング動画もご用意しています。企業様向けの個別研修も承っています（有償）。詳細はサポートまでお問い合わせください。'
    }
  ];

  const filteredFAQs = faqItems.filter(item => {
    const matchesSearch = item.question.toLowerCase().includes(searchTerm.toLowerCase()) ||
                          item.answer.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesCategory = selectedCategory === 'all' || item.category === selectedCategory;
    return matchesSearch && matchesCategory;
  });

  const toggleExpand = (id: string) => {
    const newExpanded = new Set(expandedItems);
    if (newExpanded.has(id)) {
      newExpanded.delete(id);
    } else {
      newExpanded.add(id);
    }
    setExpandedItems(newExpanded);
  };

  const handleContactSupport = () => {
    window.location.href = '/chat?customerType=existing';
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-blue-50 to-white p-4">
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-lg shadow-lg p-6 mb-6">
          <h1 className="text-2xl font-bold text-gray-800 mb-2">よくあるお問い合わせ</h1>
          <p className="text-gray-600">既存のお客様向けのFAQです。お探しの情報が見つからない場合は、サポートまでお問い合わせください。</p>
        </div>

        {/* 検索バー */}
        <div className="bg-white rounded-lg shadow-lg p-4 mb-6">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
            <input
              type="text"
              placeholder="質問を検索..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
        </div>

        {/* カテゴリフィルター */}
        <div className="bg-white rounded-lg shadow-lg p-4 mb-6">
          <div className="flex flex-wrap gap-2">
            {categories.map((category) => {
              const Icon = category.icon;
              return (
                <button
                  key={category.id}
                  onClick={() => setSelectedCategory(category.id)}
                  className={`flex items-center gap-2 px-4 py-2 rounded-lg transition-colors ${
                    selectedCategory === category.id
                      ? 'bg-blue-500 text-white'
                      : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  <span>{category.name}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* FAQ リスト */}
        <div className="space-y-4">
          {filteredFAQs.length > 0 ? (
            filteredFAQs.map((item) => (
              <div key={item.id} className="bg-white rounded-lg shadow-lg overflow-hidden">
                <button
                  onClick={() => toggleExpand(item.id)}
                  className="w-full px-6 py-4 text-left flex items-center justify-between hover:bg-gray-50 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
                      <HelpCircle className="w-5 h-5 text-blue-600" />
                    </div>
                    <span className="font-medium text-gray-800">{item.question}</span>
                  </div>
                  <ChevronRight
                    className={`w-5 h-5 text-gray-400 transition-transform ${
                      expandedItems.has(item.id) ? 'rotate-90' : ''
                    }`}
                  />
                </button>
                {expandedItems.has(item.id) && (
                  <div className="px-6 py-4 bg-gray-50 border-t border-gray-200">
                    <p className="text-gray-700 whitespace-pre-line">{item.answer}</p>
                  </div>
                )}
              </div>
            ))
          ) : (
            <div className="bg-white rounded-lg shadow-lg p-8 text-center">
              <AlertCircle className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600">該当するFAQが見つかりませんでした。</p>
              <p className="text-gray-500 text-sm mt-2">別のキーワードで検索するか、サポートにお問い合わせください。</p>
            </div>
          )}
        </div>

        {/* サポートへの導線 */}
        <div className="mt-8 bg-gradient-to-r from-blue-500 to-blue-600 rounded-lg shadow-lg p-6 text-white">
          <h2 className="text-xl font-bold mb-2">お探しの情報が見つかりませんでしたか？</h2>
          <p className="mb-4">カスタマーサポートが直接お答えします。</p>
          <button
            onClick={handleContactSupport}
            className="bg-white text-blue-600 px-6 py-2 rounded-lg font-medium hover:bg-gray-100 transition-colors"
          >
            サポートに問い合わせる
          </button>
        </div>
      </div>
    </div>
  );
};

export default ExistingCustomerFAQ;