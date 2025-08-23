# frozen_string_literal: true

# rubocop:disable RSpec/ContextWording, RSpec/AnyInstance, RSpec/NestedGroups

require 'rails_helper'

RSpec.describe ClaudeApiService, type: :service do
  let(:service) { described_class.new }
  let(:conversation_history) do
    [
      { role: 'user', content: 'システムの処理速度を改善したいです', created_at: 1.hour.ago },
      { role: 'assistant', content: 'どのような処理でお困りですか？', created_at: 50.minutes.ago },
      { role: 'user', content: 'レポート生成に時間がかかりすぎています', created_at: 45.minutes.ago }
    ]
  end

  describe '#analyze_conversation' do
    context '正常な分析' do
      let(:mock_response) do
        {
          'content' => [
            {
              'type' => 'text',
              'text' => <<~JSON
                {
                  "hidden_needs": [
                    {
                      "need_type": "効率化",
                      "evidence": "レポート生成に時間がかかりすぎています",
                      "confidence": 0.85,
                      "proactive_suggestion": "バッチ処理の最適化やキャッシュ機能の導入をご検討ください"
                    }
                  ],
                  "customer_sentiment": "frustrated",
                  "priority_level": "high",
                  "escalation_required": true,
                  "escalation_reason": "パフォーマンス問題により業務に支障"
                }
              JSON
            }
          ]
        }
      end

      before do
        allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(mock_response)
      end

      it '会話を分析して構造化された結果を返す' do # rubocop:disable RSpec/MultipleExpectations
        result = service.analyze_conversation(conversation_history)

        expect(result).to be_a(Hash)
        expect(result['hidden_needs']).to be_an(Array)
        expect(result['hidden_needs'].first['need_type']).to eq('効率化')
        expect(result['customer_sentiment']).to eq('frustrated')
        expect(result['priority_level']).to eq('high')
        expect(result['escalation_required']).to be true
      end # rubocop:enable RSpec/MultipleExpectations

      it 'ユーザークエリを含めて分析できる' do
        user_query = '緊急で対応が必要です'
        result = service.analyze_conversation(conversation_history, user_query)

        expect(result).to be_a(Hash)
        expect(result['escalation_required']).to be true
      end
    end

    context 'API エラーが発生した場合' do
      before do
        allow_any_instance_of(Anthropic::Client).to receive(:messages).and_raise(StandardError, 'API Error')
      end

      it 'ApiErrorを発生させる' do
        expect do
          service.analyze_conversation(conversation_history)
        end.to raise_error(ClaudeApiService::ApiError, /分析処理中にエラーが発生しました/)
      end
    end

    context 'JSONパースエラーが発生した場合' do
      let(:invalid_response) do
        {
          'content' => [
            { 'type' => 'text', 'text' => 'これはJSONではありません' }
          ]
        }
      end

      before do
        allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(invalid_response)
      end

      it 'デフォルトの分析結果を返す' do
        result = service.analyze_conversation(conversation_history)

        expect(result).to be_a(Hash)
        expect(result['hidden_needs']).to eq([])
        expect(result['customer_sentiment']).to eq('neutral')
        expect(result['priority_level']).to eq('low')
        expect(result['escalation_required']).to be false
      end
    end
  end

  describe '#generate_response' do
    let(:user_message) { 'この問題を解決する方法を教えてください' }

    context '正常な応答生成' do
      let(:mock_response) do
        {
          'content' => [
            {
              'type' => 'text',
              'text' => 'レポート生成を高速化するには、以下の方法をお試しください...'
            }
          ]
        }
      end

      before do
        allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(mock_response)
      end

      it 'チャットボット応答を生成する' do
        response = service.generate_response(conversation_history, user_message)

        expect(response).to be_a(String)
        expect(response).to include('レポート生成を高速化')
      end
    end

    context 'API エラーが発生した場合' do
      before do
        allow_any_instance_of(Anthropic::Client).to receive(:messages).and_raise(StandardError, 'API Error')
      end

      it 'フォールバック応答を返す' do
        response = service.generate_response(conversation_history, user_message)

        expect(response).to include('お問い合わせありがとうございます')
        expect(response).to include('システムに接続できません')
      end
    end
  end

  describe '#generate_embedding' do
    it 'NotImplementedErrorを発生させる' do
      expect do
        service.generate_embedding('テキスト')
      end.to raise_error(NotImplementedError, /not yet implemented/)
    end
  end

  describe 'プライベートメソッド' do
    describe '#parse_analysis_response' do
      context 'JSON形式の応答' do
        # rubocop:disable RSpec/ExampleLength
        it 'JSONブロックを抽出してパースする' do
          response = {
            'content' => [
              {
                'type' => 'text',
                'text' => <<~JSON
                  ```json
                  {
                    "hidden_needs": [],
                    "customer_sentiment": "neutral",
                    "priority_level": "low",
                    "escalation_required": false,
                    "test": "value"
                  }
                  ```
                JSON
              }
            ]
          }

          result = service.send(:parse_analysis_response, response)
          expect(result).to include('test' => 'value')
          expect(result).to include('customer_sentiment' => 'neutral')
        end
        # rubocop:enable RSpec/ExampleLength

        it '直接のJSONもパースできる' do
          response = {
            'content' => [
              {
                'type' => 'text',
                'text' => '{"direct": "json"}'
              }
            ]
          }

          result = service.send(:parse_analysis_response, response)
          expect(result).to eq({ 'direct' => 'json' })
        end
      end

      context '無効なJSON' do
        it 'デフォルトの分析結果を返す' do
          response = {
            'content' => [
              {
                'type' => 'text',
                'text' => 'not a json'
              }
            ]
          }

          result = service.send(:parse_analysis_response, response)
          expect(result['hidden_needs']).to eq([])
          expect(result['customer_sentiment']).to eq('neutral')
        end
      end
    end

    describe '#format_conversation' do
      it '会話履歴を整形する' do
        formatted = service.send(:format_conversation, conversation_history)

        expect(formatted).to include('ユーザー: システムの処理速度を改善したいです')
        expect(formatted).to include('サポート: どのような処理でお困りですか？')
        expect(formatted).to include('ユーザー: レポート生成に時間がかかりすぎています')
      end
    end
  end
end
# rubocop:enable RSpec/ContextWording, RSpec/AnyInstance, RSpec/NestedGroups
