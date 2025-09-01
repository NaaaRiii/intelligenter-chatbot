# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InquiryAnalyzerService do
  let(:service) { described_class.new }

  describe '#analyze' do
    context 'カテゴリ検出' do
      it 'マーケティング関連のキーワードを検出' do
        message = 'Google広告の運用とSEO対策について相談したい'
        result = service.analyze(message)
        
        expect(result[:category]).to eq('marketing')
        expect(result[:keywords]).to include('SEO')
      end

      it '技術関連のキーワードを検出' do
        message = 'APIの連携とデータベースの最適化をお願いしたい'
        result = service.analyze(message)
        
        expect(result[:category]).to eq('tech')
        expect(result[:keywords]).to include('API')
      end

      it '営業関連のキーワードを検出' do
        message = '見積もりと契約条件について確認したい'
        result = service.analyze(message)
        
        expect(result[:category]).to eq('sales')
      end
    end

    context '緊急度判定' do
      it '高緊急度のキーワードを検出' do
        message = '至急対応をお願いします。明日までに必要です'
        result = service.analyze(message)
        
        expect(result[:urgency]).to eq('high')
      end

      it '中緊急度のキーワードを検出' do
        message = '今週中に対応していただけますか？'
        result = service.analyze(message)
        
        expect(result[:urgency]).to eq('medium')
      end

      it '低緊急度のキーワードを検出' do
        message = '将来的に検討したいと思っています'
        result = service.analyze(message)
        
        expect(result[:urgency]).to eq('low')
      end
    end

    context '意図の検出' do
      it '情報収集の意図を検出' do
        message = 'サービスの詳細を教えてください'
        result = service.analyze(message)
        
        expect(result[:intent]).to eq('information_gathering')
      end

      it '問題解決の意図を検出' do
        message = 'システムがエラーで動かないので解決してほしい'
        result = service.analyze(message)
        
        expect(result[:intent]).to eq('problem_solving')
      end

      it '価格確認の意図を検出' do
        message = '月額料金と初期費用について知りたい'
        result = service.analyze(message)
        
        expect(result[:intent]).to eq('pricing')
      end
    end

    context 'エンティティ抽出' do
      it '予算情報を抽出' do
        message = '予算は月額50万円程度を考えています'
        result = service.analyze(message)
        
        expect(result[:entities][:budget]).to eq('50万円')
      end

      it '期間情報を抽出' do
        message = '3ヶ月以内に導入したいです'
        result = service.analyze(message)
        
        expect(result[:entities][:timeline]).to eq('3ヶ月')
      end

      it '規模情報を抽出' do
        message = '弊社は従業員100人の会社です'
        result = service.analyze(message)
        
        expect(result[:entities][:scale]).to eq('100人')
      end
    end

    context '感情分析' do
      it 'ポジティブな感情を検出' do
        message = '素晴らしいサービスで期待しています'
        result = service.analyze(message)
        
        expect(result[:sentiment]).to eq('positive')
      end

      it 'ネガティブな感情を検出' do
        message = '問題が多くて困っています'
        result = service.analyze(message)
        
        expect(result[:sentiment]).to eq('negative')
      end

      it 'ニュートラルな感情を検出' do
        message = 'サービスについて質問があります'
        result = service.analyze(message)
        
        expect(result[:sentiment]).to eq('neutral')
      end
    end

    context '複雑なメッセージの分析' do
      it '複数の要素を含むメッセージを正しく分析' do
        message = '至急、ECサイトのシステム開発をお願いしたい。予算は500万円で、3ヶ月以内に完成させたい。現在Reactを使っているが、パフォーマンスに問題があって困っている。'
        result = service.analyze(message)
        
        expect(result[:category]).to eq('tech')
        expect(result[:urgency]).to eq('high')
        expect(result[:intent]).to eq('problem_solving')
        expect(result[:entities][:budget]).to eq('500万円')
        expect(result[:entities][:timeline]).to eq('3ヶ月')
        expect(result[:keywords]).to include('React', 'EC')
        expect(result[:sentiment]).to eq('negative')
      end
    end

    context '会話履歴からのプロファイル構築' do
      it '業界情報を抽出' do
        conversation_history = [
          { content: '弊社は小売業を営んでいます', role: 'user' },
          { content: 'ECサイトの改善を検討中です', role: 'user' }
        ]
        
        result = service.analyze('相談したい', conversation_history)
        
        expect(result[:customer_profile][:industry]).to eq('小売')
      end

      it '複数の課題を収集' do
        conversation_history = [
          { content: '集客に課題があります', role: 'user' },
          { content: 'コンバージョン率を改善したい', role: 'user' }
        ]
        
        result = service.analyze('支援をお願いします', conversation_history)
        
        expect(result[:customer_profile][:main_challenges]).not_to be_empty
      end
    end

    context '次のアクション提案' do
      it '緊急案件は即座にエスカレーション' do
        message = '至急対応が必要です'
        result = service.analyze(message)
        
        expect(result[:next_action]).to eq('immediate_escalation')
      end

      it '価格問い合わせには価格情報送信' do
        message = '料金を教えてください'
        result = service.analyze(message)
        
        expect(result[:next_action]).to eq('send_pricing_info')
      end

      it '技術的問題にはテクニカルサポート' do
        message = 'システムがエラーで動きません'
        result = service.analyze(message)
        
        expect(result[:next_action]).to eq('technical_support')
      end
    end
  end
end