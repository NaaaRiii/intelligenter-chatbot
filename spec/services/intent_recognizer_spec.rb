# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IntentRecognizer, type: :service do
  describe '#recognize' do
    context 'with greeting messages' do
      it '挨拶を認識する' do
        recognizer = described_class.new(message: 'こんにちは、お元気ですか？')
        result = recognizer.recognize

        expect(result[:type]).to eq('greeting')
        expect(result[:confidence]).to be > 0.5
        expect(result[:keywords]).to include('こんにちは')
      end

      it '朝の挨拶を認識する' do
        recognizer = described_class.new(message: 'おはようございます')
        result = recognizer.recognize

        expect(result[:type]).to eq('greeting')
      end
    end

    context 'with question messages' do
      it '質問を認識する' do
        recognizer = described_class.new(message: 'これはどうやって使いますか？')
        result = recognizer.recognize

        expect(result[:type]).to eq('question')
        expect(result[:keywords]).to include('どうやって')
      end

      it '疑問符を含む質問を認識する' do
        recognizer = described_class.new(message: '料金はいくらですか？')
        result = recognizer.recognize

        expect(result[:type]).to eq('question')
      end
    end

    context 'with complaint messages' do
      it '苦情を認識する' do
        recognizer = described_class.new(message: 'エラーが発生して困っています')
        result = recognizer.recognize

        expect(result[:type]).to eq('complaint')
        expect(result[:keywords]).to include('エラー')
        expect(result[:keywords]).to include('困った')
      end

      it '不具合報告を認識する' do
        recognizer = described_class.new(message: 'アプリが動かない')
        result = recognizer.recognize

        expect(result[:type]).to eq('complaint')
      end
    end

    context 'with feedback messages' do
      it 'フィードバックを認識する' do
        recognizer = described_class.new(message: 'UIを改善してほしいという要望があります')
        result = recognizer.recognize

        expect(result[:type]).to eq('feedback')
        expect(result[:keywords]).to include('改善')
        expect(result[:keywords]).to include('要望')
      end
    end

    context 'with general messages' do
      it '一般的なメッセージを認識する' do
        recognizer = described_class.new(message: '今日は良い天気ですね')
        result = recognizer.recognize

        expect(result[:type]).to eq('general')
        expect(result[:confidence]).to be >= 0.3
      end
    end

    context 'with empty messages' do
      it '空のメッセージを処理する' do
        recognizer = described_class.new(message: '')
        result = recognizer.recognize

        expect(result[:type]).to eq('general')
        expect(result[:confidence]).to eq(0.3)
        expect(result[:keywords]).to be_empty
      end

      it 'nilメッセージを処理する' do
        recognizer = described_class.new(message: nil)
        result = recognizer.recognize

        expect(result[:type]).to eq('general')
      end
    end

    context 'with multiple intents' do
      it '優先順位に基づいて意図を選択する' do
        recognizer = described_class.new(message: 'こんにちは、エラーで困っています')
        result = recognizer.recognize

        # complaint が greeting より優先される
        expect(result[:type]).to eq('complaint')
      end
    end
  end

  describe '#analyze_sentiment' do
    it 'ポジティブな感情を分析する' do
      recognizer = described_class.new(message: '素晴らしいサービスで嬉しいです')
      sentiment = recognizer.analyze_sentiment

      expect(sentiment).to eq('positive')
    end

    it 'ネガティブな感情を分析する' do
      recognizer = described_class.new(message: '最悪のサービスで不満です')
      sentiment = recognizer.analyze_sentiment

      expect(sentiment).to eq('negative')
    end

    it 'ニュートラルな感情を分析する' do
      recognizer = described_class.new(message: '今日は月曜日です')
      sentiment = recognizer.analyze_sentiment

      expect(sentiment).to eq('neutral')
    end
  end
end
