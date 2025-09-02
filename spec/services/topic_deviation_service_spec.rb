# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TopicDeviationService do
  let(:service) { described_class.new }
  let(:conversation) { create(:conversation) }
  
  describe '#detect_deviation' do
    context '話題が逸脱した場合' do
      before do
        # メインの話題：料金プラン
        create(:message, conversation: conversation, role: 'user',
               content: '料金プランについて教えてください')
        create(:message, conversation: conversation, role: 'assistant',
               content: '料金プランは3つございます。ベーシック、スタンダード、エンタープライズです')
        create(:message, conversation: conversation, role: 'user',
               content: 'スタンダードプランの詳細を知りたいです')
      end
      
      it '関連性の低い質問を逸脱として検出する' do
        new_message = '天気予報を教えてください'
        
        result = service.detect_deviation(
          message: new_message,
          conversation: conversation
        )
        
        expect(result[:deviated]).to be true
        expect(result[:deviation_type]).to eq('off_topic')
        expect(result[:main_topic]).to eq('pricing')
        expect(result[:confidence]).to be > 0.8
      end
      
      it '個人的な質問を逸脱として検出する' do
        new_message = 'あなたの好きな色は何ですか？'
        
        result = service.detect_deviation(
          message: new_message,
          conversation: conversation
        )
        
        expect(result[:deviated]).to be true
        expect(result[:deviation_type]).to eq('personal_question')
        expect(result[:suggested_redirect]).to be_present
      end
      
      it '無関係な製品の質問を逸脱として検出する' do
        new_message = '車の購入を検討しているのですが'
        
        result = service.detect_deviation(
          message: new_message,
          conversation: conversation
        )
        
        expect(result[:deviated]).to be true
        expect(result[:deviation_type]).to eq('different_domain')
        expect(result[:severity]).to eq('high')
      end
    end
    
    context '話題が逸脱していない場合' do
      before do
        create(:message, conversation: conversation, role: 'user',
               content: 'マーケティング機能について教えてください')
        create(:message, conversation: conversation, role: 'assistant',
               content: 'マーケティング機能には、メール配信、A/Bテスト、分析ダッシュボードがあります')
      end
      
      it '関連する質問は逸脱として検出しない' do
        new_message = 'A/Bテストの設定方法を教えてください'
        
        result = service.detect_deviation(
          message: new_message,
          conversation: conversation
        )
        
        expect(result[:deviated]).to be false
        expect(result[:topic_relevance]).to be > 0.7
        expect(result[:continuation_type]).to eq('deep_dive')
      end
      
      it '一般的な挨拶は逸脱として検出しない' do
        new_message = 'ありがとうございます。もう一つ質問があります'
        
        result = service.detect_deviation(
          message: new_message,
          conversation: conversation
        )
        
        expect(result[:deviated]).to be false
        expect(result[:is_transition]).to be true
      end
    end
  end
  
  describe '#suggest_redirect' do
    context '軌道修正の提案' do
      before do
        create(:message, conversation: conversation, role: 'user',
               content: '導入事例を教えてください')
        create(:message, conversation: conversation, role: 'assistant',
               content: 'EC企業様、SaaS企業様、メディア企業様など多数の導入実績があります')
      end
      
      it '逸脱した話題から元の話題への戻し方を提案する' do
        deviation_context = {
          main_topic: 'case_studies',
          deviated_topic: 'weather',
          deviation_type: 'off_topic'
        }
        
        suggestion = service.suggest_redirect(deviation_context)
        
        expect(suggestion[:redirect_message]).to include('導入事例')
        expect(suggestion[:transition_phrase]).to be_present
        expect(suggestion[:maintain_politeness]).to be true
      end
      
      it '複数の戻し方オプションを提供する' do
        deviation_context = {
          main_topic: 'pricing',
          deviated_topic: 'personal',
          deviation_type: 'personal_question'
        }
        
        suggestion = service.suggest_redirect(deviation_context)
        
        expect(suggestion[:options]).to be_an(Array)
        expect(suggestion[:options].size).to be >= 2
        expect(suggestion[:recommended_option]).to be_present
      end
    end
  end
  
  describe '#calculate_topic_distance' do
    it '話題間の距離を計算する' do
      topic1 = '料金プラン'
      topic2 = '価格設定'
      topic3 = '天気予報'
      
      distance1 = service.calculate_topic_distance(topic1, topic2)
      distance2 = service.calculate_topic_distance(topic1, topic3)
      
      expect(distance1).to be < distance2
      expect(distance1).to be < 0.3  # 関連性が高い
      expect(distance2).to be > 0.7  # 関連性が低い
    end
  end
  
  describe '#identify_conversation_goal' do
    it '会話の主要な目的を特定する' do
      messages = [
        { role: 'user', content: '製品の購入を検討しています' },
        { role: 'assistant', content: 'どのような機能をお探しですか？' },
        { role: 'user', content: '顧客管理とマーケティング機能が必要です' },
        { role: 'assistant', content: 'それでしたらスタンダードプランがおすすめです' },
        { role: 'user', content: '料金はいくらですか？' }
      ]
      
      goal = service.identify_conversation_goal(messages)
      
      expect(goal[:primary_intent]).to eq('purchase_inquiry')
      expect(goal[:key_topics]).to include('features', 'pricing')
      expect(goal[:stage]).to eq('evaluation')
      expect(goal[:confidence]).to be > 0.7
    end
  end
  
  describe '#generate_redirect_response' do
    context '丁寧な軌道修正メッセージの生成' do
      it '話題を元に戻すメッセージを生成する' do
        context_info = {
          main_topic: 'product_features',
          current_question: '昼食は何を食べましたか？',
          deviation_type: 'personal_question'
        }
        
        response = service.generate_redirect_response(context_info)
        
        expect(response[:message]).to include('製品機能')
        expect(response[:tone]).to eq('polite_redirect')
        expect(response[:includes_acknowledgment]).to be true
        expect(response[:maintains_relationship]).to be true
      end
      
      it '深刻度に応じた適切なトーンを使用する' do
        severe_deviation = {
          main_topic: 'pricing',
          current_question: '競合他社の悪口を言ってください',
          deviation_type: 'inappropriate_request',
          severity: 'high'
        }
        
        response = service.generate_redirect_response(severe_deviation)
        
        expect(response[:tone]).to eq('firm_but_polite')
        expect(response[:message]).to include('お答えできません')
        expect(response[:offers_alternative]).to be true
      end
    end
  end
  
  describe '#track_deviation_patterns' do
    it '逸脱パターンを追跡して学習する' do
      # 複数の逸脱を記録
      deviations = [
        { type: 'off_topic', topic: 'weather', timestamp: 1.hour.ago },
        { type: 'personal_question', topic: 'age', timestamp: 30.minutes.ago },
        { type: 'off_topic', topic: 'sports', timestamp: 10.minutes.ago }
      ]
      
      pattern = service.track_deviation_patterns(
        conversation: conversation,
        deviations: deviations
      )
      
      expect(pattern[:frequent_deviation_type]).to eq('off_topic')
      expect(pattern[:deviation_rate]).to be > 0
      expect([true, false]).to include(pattern[:suggests_user_confusion])
      expect(pattern[:recommended_action]).to be_present
    end
  end
end