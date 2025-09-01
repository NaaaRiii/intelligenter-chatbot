import { useState, useCallback } from 'react';

interface AnalysisResult {
  category: string;
  intent: string;
  urgency: string;
  keywords: string[];
  entities: {
    budget?: string;
    timeline?: string;
    scale?: string;
  };
  sentiment: string;
  customer_profile: {
    industry?: string;
    company_size?: string;
    main_challenges: string[];
    budget_range?: string;
    decision_timeline?: string;
  };
  required_info: string[];
  suggested_action: string;
  metadata: {
    has_budget: boolean;
    has_timeline: boolean;
    needs_escalation: boolean;
    confidence_score: number;
  };
}

export const useInquiryAnalysis = () => {
  const [analysis, setAnalysis] = useState<AnalysisResult | null>(null);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const analyzeMessage = useCallback(async (
    message: string,
    conversationHistory?: Array<{ content: string; role: string }>
  ) => {
    setIsAnalyzing(true);
    setError(null);

    try {
      const response = await fetch('http://localhost:3000/api/v1/inquiry_analysis/analyze', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message,
          conversation_history: conversationHistory || []
        }),
      });

      if (!response.ok) {
        throw new Error(`分析エラー: ${response.status}`);
      }

      const data = await response.json();
      setAnalysis(data);
      return data;
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : '分析中にエラーが発生しました';
      setError(errorMessage);
      console.error('Analysis error:', err);
      return null;
    } finally {
      setIsAnalyzing(false);
    }
  }, []);

  const batchAnalyze = useCallback(async (
    messages: Array<{ id: string; content: string; history?: any[] }>
  ) => {
    setIsAnalyzing(true);
    setError(null);

    try {
      const response = await fetch('http://localhost:3000/api/v1/inquiry_analysis/batch_analyze', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ messages }),
      });

      if (!response.ok) {
        throw new Error(`バッチ分析エラー: ${response.status}`);
      }

      const data = await response.json();
      return data.results;
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'バッチ分析中にエラーが発生しました';
      setError(errorMessage);
      console.error('Batch analysis error:', err);
      return [];
    } finally {
      setIsAnalyzing(false);
    }
  }, []);

  const formatAnalysisDisplay = useCallback((analysis: AnalysisResult) => {
    const urgencyColors = {
      high: '#ef4444',
      medium: '#f59e0b',
      low: '#10b981',
      normal: '#6b7280'
    };

    const sentimentIcons = {
      positive: '😊',
      negative: '😔',
      neutral: '😐'
    };

    return {
      categoryLabel: getCategoryLabel(analysis.category),
      intentLabel: getIntentLabel(analysis.intent),
      urgencyColor: urgencyColors[analysis.urgency as keyof typeof urgencyColors] || urgencyColors.normal,
      urgencyLabel: getUrgencyLabel(analysis.urgency),
      sentimentIcon: sentimentIcons[analysis.sentiment as keyof typeof sentimentIcons] || '😐',
      confidencePercentage: Math.round((analysis.metadata?.confidence_score || 0) * 100)
    };
  }, []);

  return {
    analysis,
    isAnalyzing,
    error,
    analyzeMessage,
    batchAnalyze,
    formatAnalysisDisplay
  };
};

// ラベル変換関数
function getCategoryLabel(category: string): string {
  const labels: Record<string, string> = {
    marketing: 'マーケティング',
    tech: '技術・システム',
    sales: '営業・販売',
    support: 'サポート',
    consultation: 'コンサルティング',
    general: '一般'
  };
  return labels[category] || category;
}

function getIntentLabel(intent: string): string {
  const labels: Record<string, string> = {
    information_gathering: '情報収集',
    problem_solving: '問題解決',
    comparison: '比較検討',
    pricing: '価格確認',
    implementation: '導入検討',
    general_inquiry: '一般的な問い合わせ'
  };
  return labels[intent] || intent;
}

function getUrgencyLabel(urgency: string): string {
  const labels: Record<string, string> = {
    high: '緊急',
    medium: '中程度',
    low: '低',
    normal: '通常'
  };
  return labels[urgency] || urgency;
}