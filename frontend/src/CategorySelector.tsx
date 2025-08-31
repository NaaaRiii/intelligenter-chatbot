import React from 'react';
import { 
  Briefcase, 
  Code, 
  TrendingUp, 
  Users, 
  DollarSign, 
  Award, 
  MessageCircle,
  HelpCircle 
} from 'lucide-react';

interface CategorySelectorProps {
  onSelect: (category: string) => void;
}

const CategorySelector: React.FC<CategorySelectorProps> = ({ onSelect }) => {
  const categories = [
    {
      id: 'service',
      title: 'サービス概要・能力範囲',
      icon: Briefcase,
      color: '#3b82f6',
      bgColor: '#dbeafe',
      questions: [
        'マーケティング戦略とシステム構築、どこまで対応可能？',
        'ワンストップサービスの具体的な流れは？',
        '他社との差別化ポイントは？'
      ]
    },
    {
      id: 'tech',
      title: '技術・システム関連',
      icon: Code,
      color: '#8b5cf6',
      bgColor: '#e9d5ff',
      questions: [
        'どんなシステム開発が得意？',
        '既存システムとの連携は可能？',
        '開発期間・工数の目安は？',
        '保守・運用サポートはある？'
      ]
    },
    {
      id: 'marketing',
      title: 'マーケティング戦略',
      icon: TrendingUp,
      color: '#10b981',
      bgColor: '#d1fae5',
      questions: [
        '業界別のマーケティング事例はある？',
        'デジタルマーケティングの成果測定方法は？',
        'SEO・広告運用も対応可能？'
      ]
    },
    {
      id: 'project',
      title: 'プロジェクト進行・体制',
      icon: Users,
      color: '#f59e0b',
      bgColor: '#fed7aa',
      questions: [
        'プロジェクトの進め方は？',
        '担当チームの構成は？',
        '進捗管理・報告頻度は？'
      ]
    },
    {
      id: 'cost',
      title: '費用・契約',
      icon: DollarSign,
      color: '#ef4444',
      bgColor: '#fee2e2',
      questions: [
        '料金体系・見積もり依頼',
        '契約期間・支払い条件',
        '追加費用が発生するケースは？'
      ]
    },
    {
      id: 'case',
      title: '実績・事例',
      icon: Award,
      color: '#06b6d4',
      bgColor: '#cffafe',
      questions: [
        '同業界での導入事例は？',
        'ROI・成果事例を知りたい',
        'クライアント規模別の対応実績'
      ]
    },
    {
      id: 'consultation',
      title: '初回相談・問い合わせ',
      icon: MessageCircle,
      color: '#ec4899',
      bgColor: '#fce7f3',
      questions: [
        'まず何から相談すれば良い？',
        '無料相談の範囲は？',
        '提案資料の作成は可能？'
      ]
    },
    {
      id: 'faq',
      title: 'よくある質問（FAQ）',
      icon: HelpCircle,
      color: '#6366f1',
      bgColor: '#e0e7ff',
      questions: [
        '料金プランや契約条件を確認',
        'サポート体制について知りたい',
        'よくある質問を見る'
      ]
    }
  ];

  return (
    <div style={{
      backgroundColor: 'white',
      borderRadius: '0.75rem',
      padding: '1.5rem',
      marginBottom: '1rem',
      boxShadow: '0 1px 3px rgba(0, 0, 0, 0.1)'
    }}>
      {/* ヘッダー */}
      <div style={{ marginBottom: '1.5rem', textAlign: 'center' }}>
        <h3 style={{
          fontSize: '1.125rem',
          fontWeight: '600',
          color: '#1f2937',
          marginBottom: '0.5rem'
        }}>
          お問い合わせありがとうございます
        </h3>
        <p style={{
          fontSize: '0.875rem',
          color: '#6b7280'
        }}>
          以下のカテゴリーの中からお選びください
        </p>
      </div>

      {/* カテゴリーグリッド */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
        gap: '0.75rem'
      }}>
        {categories.map((category) => {
          const Icon = category.icon;
          return (
            <button
              key={category.id}
              onClick={() => onSelect(category.id)}
              style={{
                padding: '1rem',
                backgroundColor: 'white',
                border: '1px solid #e5e7eb',
                borderRadius: '0.5rem',
                cursor: 'pointer',
                transition: 'all 0.2s',
                textAlign: 'left',
                display: 'flex',
                flexDirection: 'column',
                gap: '0.5rem'
              }}
              onMouseOver={(e) => {
                e.currentTarget.style.borderColor = category.color;
                e.currentTarget.style.backgroundColor = '#f9fafb';
                e.currentTarget.style.transform = 'translateY(-2px)';
                e.currentTarget.style.boxShadow = '0 4px 6px rgba(0, 0, 0, 0.1)';
              }}
              onMouseOut={(e) => {
                e.currentTarget.style.borderColor = '#e5e7eb';
                e.currentTarget.style.backgroundColor = 'white';
                e.currentTarget.style.transform = 'translateY(0)';
                e.currentTarget.style.boxShadow = 'none';
              }}
            >
              {/* アイコン */}
              <div style={{
                width: '2.5rem',
                height: '2.5rem',
                backgroundColor: category.bgColor,
                borderRadius: '0.375rem',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center'
              }}>
                <Icon size={20} color={category.color} />
              </div>

              {/* タイトル */}
              <div style={{
                fontSize: '0.875rem',
                fontWeight: '600',
                color: '#1f2937'
              }}>
                {category.title}
              </div>

              {/* サンプル質問（最初の1つを表示） */}
              <div style={{
                fontSize: '0.75rem',
                color: '#9ca3af',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap'
              }}>
                例: {category.questions[0]}
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
};

export default CategorySelector;