# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SentimentAnalyzer, type: :service do
  let(:analyzer) { described_class.new }

  describe '#analyze_message' do
    context 'ポジティブな感情' do
      it 'ポジティブな感情を検出する' do
        result = analyzer.analyze_message('ありがとうございます！助かりました')

        expect(result[:category]).to eq(:positive)
        expect(result[:score]).to be_positive
        expect(result[:confidence]).to be_positive
      end

      it '解決の表現を検出する' do
        result = analyzer.analyze_message('問題が解決できました')

        expect(result[:category]).to eq(:positive)
      end
    end

    context 'ネガティブな感情' do
      it 'ネガティブな感情を検出する' do
        result = analyzer.analyze_message('システムが遅くて困っています')

        expect(result[:category]).to eq(:negative)
        expect(result[:score]).to be_negative
      end

      it '複雑・難しいという表現を検出する' do
        result = analyzer.analyze_message('操作が複雑で分かりません')

        expect(result[:category]).to eq(:negative)
      end
    end

    context 'フラストレーション' do
      it 'フラストレーションを検出する' do
        result = analyzer.analyze_message('もういい加減にしてください！イライラします')

        expect(result[:category]).to eq(:frustrated)
        expect(result[:score]).to be < -1
      end

      it '繰り返しの不満を検出する' do
        result = analyzer.analyze_message('何度も同じ問題が起きてうんざりです')

        expect(result[:category]).to eq(:frustrated)
      end
    end

    context '緊急性' do
      it '緊急の要求を検出する' do
        result = analyzer.analyze_message('至急対応をお願いします')

        expect(result[:category]).to eq(:urgent)
        expect(result[:all_scores][:urgent][:raw_score]).to be_positive
      end

      it '今すぐという表現を検出する' do
        result = analyzer.analyze_message('今すぐ修正してください')

        expect(result[:category]).to eq(:urgent)
      end
    end

    context '中立的な感情' do
      it '質問を中立と判定する' do
        result = analyzer.analyze_message('使い方を教えてください')

        expect(result[:category]).to eq(:neutral)
        expect(result[:score]).to be_between(-0.5, 0.5)
      end
    end

    context '空のメッセージ' do
      it '空文字列を処理できる' do
        result = analyzer.analyze_message('')

        expect(result[:category]).to eq(:neutral)
        expect(result[:score]).to eq(0)
        expect(result[:confidence]).to eq(0)
      end

      it 'nilを処理できる' do
        result = analyzer.analyze_message(nil)

        expect(result[:category]).to eq(:neutral)
        expect(result[:score]).to eq(0)
      end
    end
  end

  describe '#analyze_conversation' do
    context '会話全体の分析' do
      let(:messages) do
        [
          { role: 'user', content: 'システムが遅いです', created_at: 1.hour.ago },
          { role: 'assistant', content: '申し訳ございません' },
          { role: 'user', content: 'いつまで待てばいいですか？', created_at: 30.minutes.ago },
          { role: 'assistant', content: '確認いたします' },
          { role: 'user', content: 'もうイライラします！', created_at: Time.current }
        ]
      end

      it '全体的な感情を分析する' do
        result = analyzer.analyze_conversation(messages)

        expect(result[:overall_sentiment]).to eq(:frustrated).or eq(:negative)
        expect(result[:sentiment_history]).not_to be_empty
      end

      it '感情の推移を追跡する' do
        result = analyzer.analyze_conversation(messages)

        expect(result[:sentiment_trend]).to have_key(:dominant)
        expect(result[:sentiment_trend][:pattern]).to be_an(Array)
      end

      it 'エスカレーションを判定する' do
        result = analyzer.analyze_conversation(messages)

        expect(result[:escalation_required]).to be true
        expect(result[:escalation_reasons]).not_to be_empty
        expect(result[:escalation_priority]).to be_in(%i[low medium high urgent])
      end
    end

    context 'ポジティブな会話' do
      let(:positive_messages) do
        [
          { role: 'user', content: '使い方を教えてください' },
          { role: 'assistant', content: 'こちらをご覧ください' },
          { role: 'user', content: 'ありがとうございます！解決しました' }
        ]
      end

      it 'ポジティブな感情を検出する' do
        result = analyzer.analyze_conversation(positive_messages)

        expect(result[:overall_sentiment]).to eq(:positive).or eq(:neutral)
        expect(result[:escalation_required]).to be false
      end
    end

    context 'エスカレーショントリガー' do
      context '感情スコアの閾値' do
        let(:very_negative_messages) do
          [
            { role: 'user', content: '最悪です' },
            { role: 'user', content: 'ひどいシステムですね' },
            { role: 'user', content: '使い物になりません' }
          ]
        end

        it '感情スコアが閾値を下回るとエスカレーション' do
          result = analyzer.analyze_conversation(very_negative_messages)

          expect(result[:escalation_required]).to be true
          expect(result[:escalation_reasons].join).to include('感情スコア')
        end
      end

      context 'フラストレーションの繰り返し' do
        let(:frustrated_messages) do
          [
            { role: 'user', content: 'イライラします' },
            { role: 'assistant', content: '申し訳ございません' },
            { role: 'user', content: 'もううんざりです' },
            { role: 'user', content: '何度も同じ問題でイライラ' }
          ]
        end

        it 'フラストレーションが複数回でエスカレーション' do
          result = analyzer.analyze_conversation(frustrated_messages)

          expect(result[:escalation_required]).to be true
          expect(result[:escalation_reasons].join).to include('フラストレーション')
        end
      end

      context '緊急性の高い要求' do
        let(:urgent_messages) do
          [
            { role: 'user', content: '至急対応してください' },
            { role: 'assistant', content: '確認いたします' },
            { role: 'user', content: '今すぐお願いします！' }
          ]
        end

        it '緊急要求でエスカレーション優先度が上がる' do
          result = analyzer.analyze_conversation(urgent_messages)

          expect(result[:escalation_priority]).to eq(:urgent)
        end
      end

      context 'ネガティブトレンドの継続' do
        let(:declining_messages) do
          [
            { role: 'user', content: '遅いです' },
            { role: 'user', content: '改善されていません' },
            { role: 'user', content: 'さらに悪化しています' },
            { role: 'user', content: '全く使えません' }
          ]
        end

        it 'ネガティブが継続するとエスカレーション' do
          result = analyzer.analyze_conversation(declining_messages)

          expect(result[:escalation_required]).to be true
          expect(result[:escalation_reasons].join).to include('ネガティブ')
        end
      end
    end

    context 'キーワード分析' do
      let(:messages_with_keywords) do
        [
          { role: 'user', content: '遅い遅い本当に遅い' },
          { role: 'user', content: 'システムが遅くて困る' },
          { role: 'user', content: '処理が遅すぎます' }
        ]
      end

      it 'キーワードの頻度を分析する' do
        result = analyzer.analyze_conversation(messages_with_keywords)

        expect(result[:keyword_insights]).to have_key(:top_keywords)
        expect(result[:keyword_insights][:top_keywords]).to include('遅い')
      end

      it 'キーワードから洞察を生成する' do
        result = analyzer.analyze_conversation(messages_with_keywords)

        expect(result[:keyword_insights][:insights]).not_to be_empty
      end
    end

    context '感情の変動性' do
      let(:volatile_messages) do
        [
          { role: 'user', content: 'ありがとうございます' },
          { role: 'user', content: '最悪です' },
          { role: 'user', content: '素晴らしい' },
          { role: 'user', content: 'ひどい' }
        ]
      end

      it '感情の変動性を計算する' do
        result = analyzer.analyze_conversation(volatile_messages)

        expect(result[:sentiment_trend][:volatility]).to be_positive
      end
    end

    context '空の会話' do
      it '空の配列を処理できる' do
        result = analyzer.analyze_conversation([])

        expect(result[:overall_sentiment]).to eq(:neutral)
        expect(result[:escalation_required]).to be false
        expect(result[:sentiment_history]).to be_empty
      end
    end

    context 'アシスタントのみのメッセージ' do
      let(:assistant_only) do
        [
          { role: 'assistant', content: 'いかがですか？' },
          { role: 'assistant', content: 'お手伝いします' }
        ]
      end

      it 'ユーザーメッセージのみを分析対象とする' do
        result = analyzer.analyze_conversation(assistant_only)

        expect(result[:sentiment_history]).to be_empty
        expect(result[:overall_sentiment]).to eq(:neutral)
      end
    end
  end
end
