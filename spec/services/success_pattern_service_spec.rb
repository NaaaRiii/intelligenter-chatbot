# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SuccessPatternService do
  let(:service) { described_class.new }
  let(:conversation) { create(:conversation) }
  let(:user) { conversation.user }
  
  describe '#evaluate_conversation' do
    context '会話の評価' do
      before do
        # 成功した会話のサンプル
        create(:message, conversation: conversation, role: 'user',
               content: '料金プランについて教えてください')
        create(:message, conversation: conversation, role: 'assistant',
               content: '3つのプランをご用意しています。ベーシック、スタンダード、エンタープライズです')
        create(:message, conversation: conversation, role: 'user',
               content: 'スタンダードプランの詳細を知りたいです')
        create(:message, conversation: conversation, role: 'assistant',
               content: 'スタンダードプランは月額5万円で、主要機能が全て利用可能です')
        create(:message, conversation: conversation, role: 'user',
               content: 'ありがとうございます。とても分かりやすいです')
      end
      
      it '会話の成功度を評価する' do
        evaluation = service.evaluate_conversation(conversation)
        
        expect(evaluation[:success_score]).to be_between(0, 100)
        expect(evaluation[:indicators]).to include(:positive_feedback)
        expect(evaluation[:indicators]).to include(:clear_resolution)
        expect(evaluation[:completion_rate]).to be > 0.7
      end
      
      it '高評価の閾値を判定する' do
        evaluation = service.evaluate_conversation(conversation)
        
        expect(evaluation[:is_successful]).to be true
        expect(evaluation[:success_score]).to be >= 70
        expect(evaluation[:save_recommended]).to be true
      end
      
      it '評価の根拠を提供する' do
        evaluation = service.evaluate_conversation(conversation)
        
        expect(evaluation[:reasoning]).to be_present
        expect(evaluation[:reasoning]).to include(:customer_satisfaction)
        expect(evaluation[:reasoning]).to include(:goal_achievement)
        expect(evaluation[:key_factors]).to be_an(Array)
      end
    end
    
    context '低評価の会話' do
      before do
        create(:message, conversation: conversation, role: 'user',
               content: '使い方が分かりません')
        create(:message, conversation: conversation, role: 'assistant',
               content: 'マニュアルをご覧ください')
        create(:message, conversation: conversation, role: 'user',
               content: 'マニュアルはどこですか？')
        # 会話が未解決のまま終了
      end
      
      it '低評価を正しく判定する' do
        evaluation = service.evaluate_conversation(conversation)
        
        expect(evaluation[:is_successful]).to be false
        expect(evaluation[:success_score]).to be < 50
        expect(evaluation[:save_recommended]).to be false
        expect(evaluation[:improvement_areas]).to be_present
      end
    end
  end
  
  describe '#save_to_knowledge_base' do
    let(:successful_conversation) { create(:conversation) }
    
    before do
      # 成功パターンの会話を作成
      create(:message, conversation: successful_conversation, role: 'user',
             content: '導入を検討しています')
      create(:message, conversation: successful_conversation, role: 'assistant',
             content: 'どのような機能をお探しでしょうか？')
      create(:message, conversation: successful_conversation, role: 'user',
             content: 'データ分析機能が必要です')
      create(:message, conversation: successful_conversation, role: 'assistant',
             content: 'データ分析機能でしたら、エンタープライズプランがおすすめです')
    end
    
    it '成功パターンをKnowledgeBaseに保存する' do
      evaluation = {
        success_score: 85,
        is_successful: true,
        indicators: [:positive_feedback, :goal_achievement],
        key_factors: ['適切な提案', 'ニーズの把握']
      }
      
      expect {
        service.save_to_knowledge_base(successful_conversation, evaluation)
      }.to change(KnowledgeBase, :count).by(1)
      
      saved = KnowledgeBase.last
      expect(saved.pattern_type).to eq('successful_conversation')
      expect(saved.success_score).to eq(85)
      expect(saved.conversation_id).to eq(successful_conversation.id)
    end
    
    it 'メタデータを含めて保存する' do
      evaluation = {
        success_score: 90,
        is_successful: true,
        indicators: [:clear_resolution, :customer_satisfaction],
        reasoning: { goal_achievement: true, satisfaction: 'high' }
      }
      
      saved_pattern = service.save_to_knowledge_base(successful_conversation, evaluation)
      
      expect(saved_pattern.metadata).to include('indicators')
      expect(saved_pattern.metadata['indicators']).to include('clear_resolution')
      expect(saved_pattern.metadata).to include('reasoning')
      expect(saved_pattern.tags).to include('high_score')
      expect(saved_pattern.tags).to include('customer_satisfaction')
    end
    
    it '会話の要約を生成して保存する' do
      evaluation = { success_score: 80, is_successful: true }
      
      saved_pattern = service.save_to_knowledge_base(successful_conversation, evaluation)
      
      expect(saved_pattern.summary).to be_present
      expect(saved_pattern.summary).to include('導入検討')
      expect(saved_pattern.summary).to include('データ分析')
      expect(saved_pattern.summary).to include('エンタープライズプラン')
    end
  end
  
  describe '#extract_success_patterns' do
    let(:knowledge_base_entry) { create(:knowledge_base, pattern_type: 'successful_conversation') }
    
    it '成功パターンから学習ポイントを抽出する' do
      patterns = service.extract_success_patterns(knowledge_base_entry)
      
      expect(patterns[:response_patterns]).to be_an(Array)
      expect(patterns[:effective_phrases]).to be_an(Array)
      expect(patterns[:conversation_flow]).to be_present
      expect(patterns[:success_triggers]).to be_an(Array)
    end
    
    it '再利用可能なテンプレートを生成する' do
      patterns = service.extract_success_patterns(knowledge_base_entry)
      
      expect(patterns[:templates]).to be_an(Array)
      expect(patterns[:templates].first).to include(:trigger)
      expect(patterns[:templates].first).to include(:response)
      expect(patterns[:templates].first).to include(:context)
    end
  end
  
  describe '#auto_save_high_rated' do
    context '自動保存の条件' do
      it '評価が閾値を超えた場合に自動保存する' do
        allow(service).to receive(:evaluate_conversation).and_return({
          success_score: 85,
          is_successful: true,
          save_recommended: true
        })
        
        expect {
          service.auto_save_high_rated(conversation)
        }.to change(KnowledgeBase, :count).by(1)
      end
      
      it '評価が低い場合は保存しない' do
        allow(service).to receive(:evaluate_conversation).and_return({
          success_score: 40,
          is_successful: false,
          save_recommended: false
        })
        
        expect {
          service.auto_save_high_rated(conversation)
        }.not_to change(KnowledgeBase, :count)
      end
      
      it '重複する会話は保存しない' do
        # 最初の保存
        service.auto_save_high_rated(conversation)
        
        # 同じ会話の2回目の保存試行
        expect {
          service.auto_save_high_rated(conversation)
        }.not_to change(KnowledgeBase, :count)
      end
    end
  end
  
  describe '#analyze_success_indicators' do
    it '成功指標を分析する' do
      messages = [
        { role: 'user', content: '素晴らしい対応ありがとうございました' },
        { role: 'assistant', content: 'お役に立てて嬉しいです' },
        { role: 'user', content: '契約したいと思います' }
      ]
      
      indicators = service.analyze_success_indicators(messages)
      
      expect(indicators).to include(:positive_feedback)
      expect(indicators).to include(:conversion_intent)
      expect(indicators).to include(:gratitude_expressed)
      expect(indicators.size).to be >= 3
    end
    
    it 'ネガティブ指標も検出する' do
      messages = [
        { role: 'user', content: 'よく分かりません' },
        { role: 'assistant', content: '申し訳ございません' },
        { role: 'user', content: 'もういいです' }
      ]
      
      indicators = service.analyze_success_indicators(messages)
      
      expect(indicators).to include(:confusion)
      expect(indicators).to include(:frustration)
      expect(indicators).to include(:abandonment)
    end
  end
  
  describe '#calculate_success_score' do
    it '複数の要因から成功スコアを計算する' do
      factors = {
        positive_feedback: true,
        goal_achievement: true,
        clear_resolution: true,
        customer_satisfaction: 'high',
        message_count: 6,
        resolution_time: 5.minutes
      }
      
      score = service.calculate_success_score(factors)
      
      expect(score).to be_between(0, 100)
      expect(score).to be > 70  # 良好な指標なので高スコア
    end
    
    it '重み付けを適用してスコアを計算する' do
      high_weight_factors = {
        conversion_intent: true,
        positive_feedback: true
      }
      
      low_weight_factors = {
        message_count: 10
      }
      
      high_score = service.calculate_success_score(high_weight_factors)
      low_score = service.calculate_success_score(low_weight_factors)
      
      expect(high_score).to be > low_score
    end
  end
  
  describe '#find_similar_patterns' do
    before do
      # 複数の成功パターンを作成
      create(:knowledge_base, 
             pattern_type: 'successful_conversation',
             tags: ['pricing', 'conversion'],
             success_score: 85)
      create(:knowledge_base,
             pattern_type: 'successful_conversation', 
             tags: ['support', 'resolution'],
             success_score: 90)
    end
    
    it '類似の成功パターンを検索する' do
      current_context = {
        topic: 'pricing',
        intent: 'purchase',
        tags: ['pricing']  # enterpriseを削除してpricingのみに
      }
      
      similar = service.find_similar_patterns(current_context)
      
      expect(similar).not_to be_empty
      expect(similar.first.tags).to include('pricing')
      expect(similar.first.success_score).to be >= 80
    end
    
    it '関連度でソートして返す' do
      context = { tags: ['pricing'] }
      
      similar = service.find_similar_patterns(context, limit: 5)
      
      expect(similar.size).to be <= 5
      expect(similar).to eq(similar.sort_by(&:success_score).reverse)
    end
  end
end