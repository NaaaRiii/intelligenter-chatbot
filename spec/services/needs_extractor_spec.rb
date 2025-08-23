# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NeedsExtractor, type: :service do
  let(:extractor) { described_class.new }

  describe '#extract_needs' do
    context '効率化ニーズの検出' do
      let(:conversation_history) do
        [
          { role: 'user', content: 'レポート生成が遅いです' },
          { role: 'assistant', content: 'どのような処理が遅いですか？' },
          { role: 'user', content: '月次レポートの作成に3時間もかかります' }
        ]
      end

      it '効率化ニーズを検出する' do
        needs = extractor.extract_needs(conversation_history)
        
        expect(needs).not_to be_empty
        expect(needs.first[:type]).to eq(:efficiency)
        expect(needs.first[:evidence]).to include('遅い')
        expect(needs.first[:confidence]).to be > 0.5
      end

      it '適切な提案を生成する' do
        needs = extractor.extract_needs(conversation_history)
        
        expect(needs.first[:suggestion]).to include('効率化')
      end
    end

    context 'コスト削減ニーズの検出' do
      let(:conversation_history) do
        [
          { role: 'user', content: '月額料金が高いと感じています' },
          { role: 'assistant', content: '現在のプランについて確認します' },
          { role: 'user', content: '予算を削減したいです' }
        ]
      end

      it 'コスト削減ニーズを検出する' do
        needs = extractor.extract_needs(conversation_history)
        
        expect(needs).not_to be_empty
        expect(needs.first[:type]).to eq(:cost_reduction)
        expect(needs.first[:priority]).to eq('medium').or eq('high')
      end
    end

    context '機能要望の検出' do
      let(:conversation_history) do
        [
          { role: 'user', content: 'CSVエクスポート機能が欲しいです' },
          { role: 'assistant', content: 'ご要望ありがとうございます' },
          { role: 'user', content: 'データを外部システムと連携できません' }
        ]
      end

      it '機能要望を検出する' do
        needs = extractor.extract_needs(conversation_history)
        
        feature_need = needs.find { |n| n[:type] == :feature_request }
        expect(feature_need).not_to be_nil
        expect(feature_need[:evidence]).to include('欲しい')
      end

      it '統合ニーズも検出する' do
        needs = extractor.extract_needs(conversation_history)
        
        integration_need = needs.find { |n| n[:type] == :integration }
        expect(integration_need).not_to be_nil
        expect(integration_need[:evidence]).to include('連携')
      end
    end

    context '感情分析による優先度調整' do
      let(:conversation_history) do
        [
          { role: 'user', content: 'システムが遅くて困っています' },
          { role: 'assistant', content: '申し訳ございません' },
          { role: 'user', content: '至急改善してください！イライラします' }
        ]
      end

      it 'ネガティブな感情を検出して優先度を上げる' do
        needs = extractor.extract_needs(conversation_history)
        
        expect(needs.first[:priority]).to eq('high')
        expect(needs.first[:priority_boost]).to be_positive
      end
    end

    context 'コンテキスト分析' do
      let(:conversation_history) do
        [
          { role: 'user', content: 'データベースの処理が遅いです' },
          { role: 'assistant', content: '詳細を教えてください' },
          { role: 'user', content: 'データベースのクエリに時間がかかります' },
          { role: 'assistant', content: '確認いたします' },
          { role: 'user', content: 'データベースのパフォーマンスを改善したい' }
        ]
      end

      it '繰り返し言及されるトピックの信頼度を上げる' do
        needs = extractor.extract_needs(conversation_history)
        
        # データベースが3回言及されているので、信頼度が高いはず
        expect(needs.first[:confidence]).to be > 0.7
      end
    end

    context 'スケーラビリティニーズの検出' do
      let(:conversation_history) do
        [
          { role: 'user', content: 'ユーザー数が増えてきました' },
          { role: 'assistant', content: '現在何名程度ですか？' },
          { role: 'user', content: '1000人を超えて、システムが重くなっています' }
        ]
      end

      it 'スケーラビリティニーズを検出する' do
        needs = extractor.extract_needs(conversation_history)
        
        scale_need = needs.find { |n| n[:type] == :scalability }
        expect(scale_need).not_to be_nil
        expect(scale_need[:suggestion]).to include('スケーラビリティ')
      end
    end

    context 'ユーザビリティニーズの検出' do
      let(:conversation_history) do
        [
          { role: 'user', content: '操作が複雑で分かりにくいです' },
          { role: 'assistant', content: 'どの部分でしょうか？' },
          { role: 'user', content: '設定画面が使いにくくて迷います' }
        ]
      end

      it 'ユーザビリティニーズを検出する' do
        needs = extractor.extract_needs(conversation_history)
        
        usability_need = needs.find { |n| n[:type] == :usability }
        expect(usability_need).not_to be_nil
        expect(usability_need[:suggestion]).to include('UI/UX')
      end
    end

    context '複数ニーズの優先順位付け' do
      let(:conversation_history) do
        [
          { role: 'user', content: 'システムが遅くて困っています' },
          { role: 'assistant', content: '申し訳ございません' },
          { role: 'user', content: '料金も高いです' },
          { role: 'assistant', content: 'プランを確認します' },
          { role: 'user', content: '至急、処理速度を改善してください' }
        ]
      end

      it '複数のニーズを優先度順にソートする' do
        needs = extractor.extract_needs(conversation_history)
        
        expect(needs.length).to be >= 2
        
        # 優先度スコアが降順になっていることを確認
        priority_scores = needs.pluck(:priority_score)
        expect(priority_scores).to eq(priority_scores.sort.reverse)
        
        # 高優先度のニーズが検出される
        high_priority_needs = needs.select { |n| n[:priority] == 'high' }
        expect(high_priority_needs).not_to be_empty
        
        # 効率化ニーズとコスト削減ニーズの両方が検出される
        need_types = needs.pluck(:type)
        expect(need_types).to include(:efficiency)
        expect(need_types).to include(:cost_reduction)
      end
    end

    context '空の会話履歴' do
      let(:conversation_history) { [] }

      it '空の配列を返す' do
        needs = extractor.extract_needs(conversation_history)
        expect(needs).to be_empty
      end
    end

    context 'アシスタントのメッセージのみ' do
      let(:conversation_history) do
        [
          { role: 'assistant', content: 'いかがお過ごしですか？' },
          { role: 'assistant', content: 'お手伝いできることはありますか？' }
        ]
      end

      it '空の配列を返す' do
        needs = extractor.extract_needs(conversation_history)
        expect(needs).to be_empty
      end
    end
  end

  describe 'プライベートメソッド' do
    describe '#calculate_keyword_score' do
      it 'キーワードスコアを正しく計算する' do
        content = '処理が遅くて効率が悪い'
        keywords = %w[遅い 効率 自動化]
        
        score = extractor.send(:calculate_keyword_score, content, keywords)
        expect(score).to be_between(0, 1)
        expect(score).to eq(1.0 / 3) # 「効率」のみマッチ（「遅い」は「遅く」なので部分マッチ）
      end
    end

    describe '#calculate_confidence' do
      it '信頼度を0から1の範囲で返す' do
        confidence = extractor.send(:calculate_confidence, 0.5, /test/)
        
        expect(confidence).to be_between(0, 1)
      end
    end

    describe '#detect_sentiment' do
      it 'frustrated感情を検出する' do
        sentiment = extractor.send(:detect_sentiment, '困っています')
        expect(sentiment).to eq(:frustrated)
      end

      it 'urgent感情を検出する' do
        sentiment = extractor.send(:detect_sentiment, '至急お願いします')
        expect(sentiment).to eq(:urgent)
      end

      it '感情が検出されない場合はnilを返す' do
        sentiment = extractor.send(:detect_sentiment, '普通のメッセージです')
        expect(sentiment).to be_nil
      end
    end

    describe '#determine_priority_level' do
      it '高スコアにはhighを返す' do
        priority = extractor.send(:determine_priority_level, 150)
        expect(priority).to eq('high')
      end

      it '中スコアにはmediumを返す' do
        priority = extractor.send(:determine_priority_level, 90)
        expect(priority).to eq('medium')
      end

      it '低スコアにはlowを返す' do
        priority = extractor.send(:determine_priority_level, 50)
        expect(priority).to eq('low')
      end
    end
  end
end