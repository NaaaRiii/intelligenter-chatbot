# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutoConversationService do
  let(:service) { described_class.new }
  let(:conversation) { create(:conversation) }
  let(:user_message) { 'ECサイトの売上を改善したいです' }

  describe '#process_initial_message' do
    context '初回メッセージの処理' do
      it '必要な情報を特定する' do
        result = service.process_initial_message(conversation, user_message)
        
        expect(result).to have_key(:required_info)
        expect(result[:required_info]).to be_an(Array)
        expect(result).to have_key(:next_question)
        expect(result[:next_question]).to be_a(String)
      end

      it '問い合わせカテゴリを判定する' do
        result = service.process_initial_message(conversation, user_message)
        
        expect(result).to have_key(:category)
        expect(result[:category]).to eq('marketing')
      end

      it '収集すべき情報リストを生成する' do
        result = service.process_initial_message(conversation, user_message)
        
        # ECサイトという情報は既に抽出されているので、business_typeは不要
        expect(result[:required_info]).not_to include('business_type')
        expect(result[:required_info]).to include('budget_range')
        expect(result[:required_info]).to include('current_tools')
      end

      it '最初の質問を生成する' do
        result = service.process_initial_message(conversation, user_message)
        
        # ECサイトの情報は既に取得済みなので、次は予算について聞く
        expect(result[:next_question]).to match(/予算|費用/)
      end
    end

    context '異なるカテゴリの問い合わせ' do
      let(:tech_message) { 'システムの不具合について相談したい' }

      it '技術系の問い合わせに対応する' do
        result = service.process_initial_message(conversation, tech_message)
        
        expect(result[:category]).to eq('tech')
        # システムの不具合という情報から、system_typeとerror_detailsは既に抽出されている
        expect(result[:collected_info][:system_type]).to eq('システム')
        expect(result[:collected_info][:error_details]).to include('不具合')
        # 次に必要な情報を確認
        expect(result[:required_info]).to include('occurrence_time')
      end
    end
  end

  describe '#generate_next_question' do
    let(:collected_info) do
      {
        'business_type' => '小売業',
        'budget_range' => nil,
        'current_tools' => nil
      }
    end

    it '未収集の情報について質問を生成する' do
      question = service.generate_next_question(collected_info, 'marketing')
      
      expect(question).not_to be_nil
      expect(question).to match(/予算|月額|費用/)
    end

    it '全ての情報が揃った場合はnilを返す' do
      complete_info = {
        'business_type' => '小売業',
        'budget_range' => '月額50万円',
        'current_tools' => 'Google Analytics, Shopify'
      }
      
      question = service.generate_next_question(complete_info, 'marketing')
      expect(question).to be_nil
    end

    it '優先度の高い情報から順に質問する' do
      empty_info = {
        'business_type' => nil,
        'budget_range' => nil,
        'current_tools' => nil
      }
      
      question = service.generate_next_question(empty_info, 'marketing')
      expect(question).to match(/業界|事業|ビジネス/)
    end
  end

  describe '#extract_information' do
    it 'ユーザーの回答から情報を抽出する' do
      message = '弊社は小売業で、月額予算は100万円程度です'
      result = service.extract_information(message, 'marketing')
      
      expect(result).to have_key(:business_type)
      expect(result[:business_type]).to eq('小売業')
      expect(result).to have_key(:budget_range)
      expect(result[:budget_range]).to match(/100万/)
    end

    it '複数の情報を同時に抽出できる' do
      message = 'アパレルのECサイトを運営しており、現在はShopifyとGoogle Analyticsを使っています'
      result = service.extract_information(message, 'marketing')
      
      expect(result[:business_type]).to match(/アパレル|EC/)
      expect(result[:current_tools]).to include('Shopify')
      expect(result[:current_tools]).to include('Google Analytics')
    end

    it '数値情報を適切に抽出する' do
      message = '月商は約3000万円で、広告費は月200万円くらいです'
      result = service.extract_information(message, 'marketing')
      
      expect(result[:monthly_revenue]).to match(/3000万/)
      expect(result[:ad_spend]).to match(/200万/)
    end
  end

  describe '#should_continue_conversation?' do
    it '3往復未満の場合はtrueを返す' do
      metadata = { 'ai_interaction_count' => 2 }
      expect(service.should_continue_conversation?(metadata)).to be true
    end

    it '5往復以上の場合はfalseを返す' do
      metadata = { 'ai_interaction_count' => 5 }
      expect(service.should_continue_conversation?(metadata)).to be false
    end

    it '必要情報が全て揃った場合はfalseを返す' do
      metadata = {
        'ai_interaction_count' => 2,
        'collected_info' => {
          'business_type' => '小売業',
          'budget_range' => '月額50万円',
          'current_tools' => 'Shopify',
          'target_metrics' => 'CVR向上'
        }
      }
      expect(service.should_continue_conversation?(metadata)).to be false
    end

    it '緊急度が高い場合はfalseを返す' do
      metadata = {
        'ai_interaction_count' => 1,
        'urgency' => 'high'
      }
      expect(service.should_continue_conversation?(metadata)).to be false
    end
  end

  describe '#generate_summary' do
    let(:collected_info) do
      {
        'business_type' => '小売業',
        'budget_range' => '月額100万円',
        'current_tools' => 'Shopify, Google Analytics',
        'challenges' => 'CVR改善'
      }
    end

    it '収集した情報のサマリーを生成する' do
      summary = service.generate_summary(collected_info, 'marketing')
      
      expect(summary).to include('小売業')
      expect(summary).to include('100万円')
      expect(summary).to include('CVR')
      expect(summary).to match(/ご相談内容を確認/)
    end

    it '次のアクションを提案する' do
      summary = service.generate_summary(collected_info, 'marketing')
      
      expect(summary).to match(/提案|ご案内|サポート/)
    end
  end

  describe '#determine_next_action' do
    it '情報収集が完了した場合は人間へのエスカレーションを推奨' do
      metadata = {
        'collected_info' => {
          'business_type' => '小売業',
          'budget_range' => '月額100万円',
          'current_tools' => 'Shopify'
        }
      }
      
      action = service.determine_next_action(metadata)
      expect(action).to eq(:escalate_to_human)
    end

    it '情報が不足している場合は継続を推奨' do
      metadata = {
        'collected_info' => {
          'business_type' => '小売業'
        },
        'ai_interaction_count' => 2
      }
      
      action = service.determine_next_action(metadata)
      expect(action).to eq(:continue_conversation)
    end

    it '会話回数が上限に達した場合はエスカレーション' do
      metadata = {
        'ai_interaction_count' => 5,
        'collected_info' => {
          'business_type' => '小売業'
        }
      }
      
      action = service.determine_next_action(metadata)
      expect(action).to eq(:escalate_to_human)
    end
  end

  describe '#build_context_aware_response' do
    let(:conversation_history) do
      [
        { role: 'user', content: 'ECサイトの売上を改善したい' },
        { role: 'assistant', content: 'ECサイトの改善についてご相談ですね。業界を教えていただけますか？' },
        { role: 'user', content: 'アパレル業界です' }
      ]
    end

    it '会話の文脈を考慮した応答を生成する' do
      collected_info = { 'business_type' => 'アパレル' }
      response = service.build_context_aware_response(
        conversation_history,
        collected_info,
        'marketing'
      )
      
      expect(response).to include('アパレル')
      expect(response).not_to match(/業界を教えて/) # 既に収集済みの情報は聞かない
    end

    it '次に必要な情報を自然に質問する' do
      collected_info = { 'business_type' => 'アパレル' }
      response = service.build_context_aware_response(
        conversation_history,
        collected_info,
        'marketing'
      )
      
      expect(response).to match(/予算|ツール|課題/)
    end
  end

  describe '#categorize_inquiry' do
    it 'マーケティング関連の問い合わせを判定' do
      category = service.categorize_inquiry('広告の効果を改善したい')
      expect(category).to eq('marketing')
    end

    it '技術関連の問い合わせを判定' do
      category = service.categorize_inquiry('APIの連携エラーが発生している')
      expect(category).to eq('tech')
    end

    it '一般的な問い合わせを判定' do
      category = service.categorize_inquiry('料金プランについて教えてください')
      expect(category).to eq('general')
    end
  end
end