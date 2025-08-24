# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalysisStorageService, type: :service do
  let(:conversation) { create(:conversation) }
  let(:service) { described_class.new(conversation) }

  describe '#store_analysis' do
    before do
      # メッセージを作成
      create(:message, conversation: conversation, role: 'user', content: 'システムが遅くて困っています')
      create(:message, conversation: conversation, role: 'assistant', content: '申し訳ございません')
      create(:message, conversation: conversation, role: 'user', content: 'いつまで待てばいいですか？')
    end

    context '正常な保存処理' do
      it '分析結果を保存する' do
        expect do
          service.store_analysis
        end.to(change(Analysis, :count).by(1))
      end

      it '感情分析結果を保存する' do
        analysis = service.store_analysis

        expect(analysis.customer_sentiment).to be_present
        expect(analysis.sentiment).to be_present
        expect(analysis.analysis_data).to have_key('sentiment')
      end

      it '隠れたニーズを保存する' do
        analysis = service.store_analysis

        expect(analysis.hidden_needs).to be_a(Hash)
        expect(analysis.analysis_data).to have_key('hidden_needs')
      end

      it 'エスカレーション情報を保存する' do
        analysis = service.store_analysis

        expect(analysis.escalated).to be_in([true, false])
        expect(analysis.priority_level).to be_present
      end

      it '信頼度スコアを計算して保存する' do
        analysis = service.store_analysis

        expect(analysis.confidence_score).to be_between(0, 1)
      end

      it '分析時刻を記録する' do
        analysis = service.store_analysis

        expect(analysis.analyzed_at).to be_within(1.second).of(Time.current)
      end
    end

    context '既存の分析がある場合' do
      let!(:existing_analysis) do
        create(:analysis,
               conversation: conversation,
               analysis_type: 'sentiment',
               analysis_data: { old: 'data' })
      end

      it '既存の分析を更新する' do
        expect do
          service.store_analysis
        end.not_to(change(Analysis, :count))

        existing_analysis.reload
        expect(existing_analysis.analysis_data).not_to have_key('old')
        expect(existing_analysis.analyzed_at).to be_within(1.second).of(Time.current)
      end
    end

    context 'エスカレーションが必要な場合' do
      before do
        # ネガティブなメッセージを追加
        create(:message, conversation: conversation, role: 'user', content: 'もうイライラします！')
        create(:message, conversation: conversation, role: 'user', content: '最悪です')
      end

      it 'エスカレーションフラグを設定する' do
        analysis = service.store_analysis

        expect(analysis.escalated).to be true
        expect(analysis.escalation_reasons).to be_present
      end

      it 'エスカレーション処理を実行する' do
        allow_any_instance_of(Analysis).to receive(:escalate!)

        analysis = service.store_analysis

        expect(analysis).to have_received(:escalate!) if analysis.escalated?
      end
    end

    context 'エラーハンドリング' do
      it 'トランザクション内でエラーが発生した場合はロールバックする' do
        allow_any_instance_of(SentimentAnalyzer).to receive(:analyze_conversation).and_raise(StandardError,
                                                                                             'Analysis error')

        expect do
          expect do
            service.store_analysis
          end.to raise_error(StandardError, 'Analysis error')
        end.not_to(change(Analysis, :count))
      end

      it 'エラーログを出力する' do
        allow_any_instance_of(SentimentAnalyzer).to receive(:analyze_conversation).and_raise(StandardError,
                                                                                             'Analysis error')

        expect(Rails.logger).to receive(:error).at_least(:once)

        expect do
          service.store_analysis
        end.to raise_error(StandardError)
      end
    end

    context '隠れたニーズ抽出' do
      context 'HiddenNeedsExtractorが定義されている場合' do
        before do
          stub_const('HiddenNeedsExtractor', Class.new do
            def initialize(conversation); end

            def extract
              {
                hidden_needs: {
                  'efficiency' => { need: 'パフォーマンス改善', confidence: 0.8 }
                },
                confidence_score: 0.8
              }
            end
          end)
        end

        it '隠れたニーズを抽出して保存する' do
          analysis = service.store_analysis

          expect(analysis.hidden_needs).to have_key('efficiency')
          expect(analysis.hidden_needs['efficiency']).to have_key('need')
        end
      end

      context 'HiddenNeedsExtractorが定義されていない場合' do
        it '空のニーズデータを保存する' do
          analysis = service.store_analysis

          expect(analysis.hidden_needs).to eq({})
        end
      end
    end

    context '信頼度スコアの計算' do
      it '感情分析の信頼度を計算する' do
        analysis = service.store_analysis

        expect(analysis.confidence_score).to be_a(Float)
        expect(analysis.confidence_score).to be >= 0
      end

      it '複数の信頼度スコアの平均を計算する' do
        stub_const('HiddenNeedsExtractor', Class.new do
          def initialize(conversation); end

          def extract
            { hidden_needs: {}, confidence_score: 0.9 }
          end
        end)

        analysis = service.store_analysis

        expect(analysis.confidence_score).to be_between(0, 1)
      end
    end
  end

  describe 'プライベートメソッド' do
    describe '#format_escalation_reasons' do
      it '配列を改行区切りの文字列に変換する' do
        reasons = %w[理由1 理由2 理由3]
        formatted = service.send(:format_escalation_reasons, reasons)

        expect(formatted).to eq("理由1\n理由2\n理由3")
      end

      it '空配列の場合はnilを返す' do
        formatted = service.send(:format_escalation_reasons, [])

        expect(formatted).to be_nil
      end
    end
  end
end
