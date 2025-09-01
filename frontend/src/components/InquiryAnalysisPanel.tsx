import React from 'react';

interface AnalysisData {
  category: string;
  intent: string;
  urgency: string;
  keywords: string[];
  sentiment: string;
  entities: {
    budget?: string;
    timeline?: string;
    scale?: string;
  };
  metadata: {
    confidence_score: number;
    needs_escalation: boolean;
  };
}

interface InquiryAnalysisPanelProps {
  analysis: AnalysisData | null;
  isAnalyzing?: boolean;
}

export const InquiryAnalysisPanel: React.FC<InquiryAnalysisPanelProps> = ({ 
  analysis, 
  isAnalyzing = false 
}) => {
  if (isAnalyzing) {
    return (
      <div className="bg-gray-50 rounded-lg p-4 animate-pulse">
        <div className="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
        <div className="h-4 bg-gray-200 rounded w-1/2"></div>
      </div>
    );
  }

  if (!analysis) {
    return null;
  }

  const getCategoryColor = (category: string) => {
    const colors: Record<string, string> = {
      marketing: 'bg-purple-100 text-purple-800',
      tech: 'bg-blue-100 text-blue-800',
      sales: 'bg-green-100 text-green-800',
      support: 'bg-yellow-100 text-yellow-800',
      consultation: 'bg-indigo-100 text-indigo-800',
      general: 'bg-gray-100 text-gray-800'
    };
    return colors[category] || colors.general;
  };

  const getUrgencyColor = (urgency: string) => {
    const colors: Record<string, string> = {
      high: 'bg-red-100 text-red-800 border-red-300',
      medium: 'bg-orange-100 text-orange-800 border-orange-300',
      low: 'bg-green-100 text-green-800 border-green-300',
      normal: 'bg-gray-100 text-gray-800 border-gray-300'
    };
    return colors[urgency] || colors.normal;
  };

  const getSentimentEmoji = (sentiment: string) => {
    const emojis: Record<string, string> = {
      positive: '😊',
      negative: '😔',
      neutral: '😐'
    };
    return emojis[sentiment] || '😐';
  };

  const getCategoryLabel = (category: string) => {
    const labels: Record<string, string> = {
      marketing: 'マーケティング',
      tech: '技術・システム',
      sales: '営業・販売',
      support: 'サポート',
      consultation: 'コンサルティング',
      general: '一般'
    };
    return labels[category] || category;
  };

  const getIntentLabel = (intent: string) => {
    const labels: Record<string, string> = {
      information_gathering: '情報収集',
      problem_solving: '問題解決',
      comparison: '比較検討',
      pricing: '価格確認',
      implementation: '導入検討',
      general_inquiry: '一般問い合わせ'
    };
    return labels[intent] || intent;
  };

  const getUrgencyLabel = (urgency: string) => {
    const labels: Record<string, string> = {
      high: '緊急',
      medium: '中',
      low: '低',
      normal: '通常'
    };
    return labels[urgency] || urgency;
  };

  return (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4 mb-4">
      <h3 className="text-sm font-semibold text-gray-700 mb-3">自動分析結果</h3>
      
      {/* 緊急度とエスカレーション警告 */}
      {analysis.metadata.needs_escalation && (
        <div className="bg-red-50 border border-red-200 rounded-md p-2 mb-3">
          <p className="text-sm text-red-800 font-medium">
            ⚠️ エスカレーションが必要です
          </p>
        </div>
      )}

      {/* 基本情報 */}
      <div className="grid grid-cols-2 gap-3 mb-3">
        <div className="flex items-center space-x-2">
          <span className="text-xs text-gray-500">カテゴリ:</span>
          <span className={`px-2 py-1 text-xs rounded-full ${getCategoryColor(analysis.category)}`}>
            {getCategoryLabel(analysis.category)}
          </span>
        </div>
        
        <div className="flex items-center space-x-2">
          <span className="text-xs text-gray-500">緊急度:</span>
          <span className={`px-2 py-1 text-xs rounded-full border ${getUrgencyColor(analysis.urgency)}`}>
            {getUrgencyLabel(analysis.urgency)}
          </span>
        </div>

        <div className="flex items-center space-x-2">
          <span className="text-xs text-gray-500">意図:</span>
          <span className="text-xs font-medium text-gray-700">
            {getIntentLabel(analysis.intent)}
          </span>
        </div>

        <div className="flex items-center space-x-2">
          <span className="text-xs text-gray-500">感情:</span>
          <span className="text-lg">
            {getSentimentEmoji(analysis.sentiment)}
          </span>
        </div>
      </div>

      {/* キーワード */}
      {analysis.keywords.length > 0 && (
        <div className="mb-3">
          <span className="text-xs text-gray-500">キーワード:</span>
          <div className="flex flex-wrap gap-1 mt-1">
            {analysis.keywords.map((keyword, index) => (
              <span
                key={index}
                className="px-2 py-1 text-xs bg-gray-100 text-gray-700 rounded"
              >
                {keyword}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* エンティティ */}
      {(analysis.entities.budget || analysis.entities.timeline || analysis.entities.scale) && (
        <div className="border-t pt-2 mt-2">
          <span className="text-xs text-gray-500">抽出情報:</span>
          <div className="grid grid-cols-3 gap-2 mt-1">
            {analysis.entities.budget && (
              <div className="text-xs">
                <span className="text-gray-500">予算: </span>
                <span className="font-medium">{analysis.entities.budget}</span>
              </div>
            )}
            {analysis.entities.timeline && (
              <div className="text-xs">
                <span className="text-gray-500">期間: </span>
                <span className="font-medium">{analysis.entities.timeline}</span>
              </div>
            )}
            {analysis.entities.scale && (
              <div className="text-xs">
                <span className="text-gray-500">規模: </span>
                <span className="font-medium">{analysis.entities.scale}</span>
              </div>
            )}
          </div>
        </div>
      )}

      {/* 信頼度スコア */}
      <div className="mt-3 pt-2 border-t">
        <div className="flex items-center justify-between">
          <span className="text-xs text-gray-500">分析信頼度:</span>
          <div className="flex items-center space-x-2">
            <div className="w-24 bg-gray-200 rounded-full h-2">
              <div
                className="bg-blue-600 h-2 rounded-full"
                style={{ width: `${Math.round(analysis.metadata.confidence_score * 100)}%` }}
              />
            </div>
            <span className="text-xs font-medium text-gray-700">
              {Math.round(analysis.metadata.confidence_score * 100)}%
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};