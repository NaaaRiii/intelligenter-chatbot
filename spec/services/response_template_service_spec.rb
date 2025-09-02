# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResponseTemplateService do
  let(:service) { described_class.new }
  
  describe '#generate_template' do
    context 'カテゴリ別のテンプレート生成' do
      it '料金問い合わせのテンプレートを生成する' do
        context_data = {
          category: 'pricing',
          intent: 'inquiry',
          customer_type: 'new'
        }
        
        template = service.generate_template(context_data)
        
        expect(template[:content]).to include('料金プラン')
        expect(template[:structure]).to include(:greeting)
        expect(template[:structure]).to include(:main_content)
        expect(template[:structure]).to include(:call_to_action)
        expect(template[:variations]).to be_present
      end
      
      it '機能説明のテンプレートを生成する' do
        context_data = {
          category: 'features',
          intent: 'explanation',
          specific_feature: 'analytics'
        }
        
        template = service.generate_template(context_data)
        
        expect(template[:content]).to include('分析機能')
        expect(template[:key_points]).to include('データ可視化')
        expect(template[:examples]).to be_present
        expect(template[:difficulty_level]).to eq('intermediate')
      end
      
      it 'サポート対応のテンプレートを生成する' do
        context_data = {
          category: 'support',
          issue_type: 'technical',
          urgency: 'high'
        }
        
        template = service.generate_template(context_data)
        
        expect(template[:content]).to include('お困りの状況')
        expect(template[:tone]).to eq('empathetic')
        expect(template[:escalation_ready]).to be true
        expect(template[:troubleshooting_steps]).to be_present
      end
      
      it '導入相談のテンプレートを生成する' do
        context_data = {
          category: 'onboarding',
          company_size: 'enterprise',
          industry: 'finance'
        }
        
        template = service.generate_template(context_data)
        
        expect(template[:content]).to include('導入')
        expect(template[:content]).to include('エンタープライズ')
        expect(template[:customization_options]).to be_present
        expect(template[:compliance_mentions]).to include('セキュリティ')
      end
    end
  end
  
  describe '#apply_template' do
    let(:template) do
      {
        content: '{greeting}、{product_name}の{feature}について説明します。{details}',
        placeholders: {
          greeting: '山田様',
          product_name: 'インテリジェントチャットボット',
          feature: '分析機能',
          details: 'リアルタイムでデータを可視化できます'
        }
      }
    end
    
    it 'プレースホルダーを実際の値に置換する' do
      result = service.apply_template(template)
      
      expect(result).to include('山田様')
      expect(result).to include('インテリジェントチャットボット')
      expect(result).to include('分析機能')
      expect(result).not_to include('{')
    end
    
    it '動的な値を適用する' do
      dynamic_template = template.merge(
        dynamic_values: {
          current_time: -> { '午後2時' },
          user_count: -> { '1,000名' }
        }
      )
      
      result = service.apply_template(dynamic_template)
      
      expect(result).to be_a(String)
      expect(result.length).to be > 0
    end
  end
  
  describe '#categorize_conversation' do
    it '会話内容からカテゴリを判定する' do
      messages = [
        { role: 'user', content: '料金について教えてください' },
        { role: 'assistant', content: 'プランは3つございます' }
      ]
      
      category = service.categorize_conversation(messages)
      
      expect(category[:primary]).to eq('pricing')
      expect(category[:confidence]).to be > 0.7
      expect(category[:sub_categories]).to include('plan_comparison')
    end
    
    it '複数のカテゴリが混在する場合を処理する' do
      messages = [
        { role: 'user', content: '機能と料金を教えてください' },
        { role: 'assistant', content: '機能と価格についてご説明します' }
      ]
      
      category = service.categorize_conversation(messages)
      
      expect(category[:primary]).to be_in(['pricing', 'features'])
      expect(category[:secondary]).to be_present
      expect(category[:mixed]).to be true
    end
  end
  
  describe '#load_successful_templates' do
    before do
      # 成功したパターンをKnowledgeBaseに保存
      create(:knowledge_base,
             pattern_type: 'successful_conversation',
             tags: ['pricing', 'conversion'],
             success_score: 90,
             content: {
               'template' => '料金プランは{count}種類ございます',
               'category' => 'pricing'
             })
    end
    
    it '高評価のテンプレートを読み込む' do
      templates = service.load_successful_templates('pricing')
      
      expect(templates).not_to be_empty
      expect(templates.first[:success_score]).to be >= 80
      expect(templates.first[:template]).to include('料金プラン')
    end
    
    it 'カテゴリでフィルタリングする' do
      templates = service.load_successful_templates('support')
      
      # pricingのテンプレートは含まれない
      templates.each do |template|
        expect(template[:category]).not_to eq('pricing')
      end
    end
  end
  
  describe '#customize_for_context' do
    let(:base_template) do
      {
        content: '基本的な応答テンプレート',
        tone: 'professional'
      }
    end
    
    it '顧客タイプに応じてカスタマイズする' do
      context_info = {
        customer_type: 'vip',
        history: 'long_term',
        satisfaction: 'high'
      }
      
      customized = service.customize_for_context(base_template, context_info)
      
      expect(customized[:tone]).to eq('premium')
      expect(customized[:personalization_level]).to eq('high')
      expect(customized[:additional_offers]).to be_present
    end
    
    it '緊急度に応じて調整する' do
      context_info = {
        urgency: 'critical',
        issue_type: 'system_down'
      }
      
      customized = service.customize_for_context(base_template, context_info)
      
      expect(customized[:priority]).to eq('immediate')
      expect(customized[:escalation_included]).to be true
      expect(customized[:response_time_commitment]).to be_present
    end
  end
  
  describe '#validate_template' do
    it '有効なテンプレートを検証する' do
      template = {
        content: 'これは{placeholder}を含むテンプレートです',
        placeholders: { placeholder: 'テスト' },
        category: 'general'
      }
      
      validation = service.validate_template(template)
      
      expect(validation[:valid]).to be true
      expect(validation[:errors]).to be_empty
      expect(validation[:warnings]).to be_empty
    end
    
    it '不完全なテンプレートを検出する' do
      template = {
        content: 'これは{missing}を含むテンプレートです',
        placeholders: { different: 'テスト' }
      }
      
      validation = service.validate_template(template)
      
      expect(validation[:valid]).to be false
      expect(validation[:errors]).to include('missing_placeholder')
      expect(validation[:unmatched_placeholders]).to include('missing')
    end
  end
  
  describe '#merge_templates' do
    it '複数のテンプレートを組み合わせる' do
      template1 = {
        content: '機能説明：',
        sections: ['overview']
      }
      
      template2 = {
        content: '価格情報：',
        sections: ['pricing']
      }
      
      merged = service.merge_templates([template1, template2])
      
      expect(merged[:sections]).to include('overview', 'pricing')
      expect(merged[:content]).to include('機能説明')
      expect(merged[:content]).to include('価格情報')
      expect(merged[:merged_from]).to eq(2)
    end
  end
  
  describe '#optimize_for_channel' do
    let(:template) do
      {
        content: 'これは長いテンプレートメッセージです。' * 20,
        formatting: 'markdown'
      }
    end
    
    it 'チャット用に最適化する' do
      optimized = service.optimize_for_channel(template, 'chat')
      
      expect(optimized[:content].length).to be <= 500
      expect(optimized[:split_messages]).to be_present if template[:content].length > 500
      expect(optimized[:formatting]).to eq('plain')
    end
    
    it 'メール用に最適化する' do
      optimized = service.optimize_for_channel(template, 'email')
      
      expect(optimized[:subject]).to be_present
      expect(optimized[:formatting]).to eq('html')
      expect(optimized[:includes_signature]).to be true
    end
  end
  
  describe '#track_template_performance' do
    let(:template) do
      {
        id: 'template_001',
        category: 'pricing',
        content: 'テンプレート内容'
      }
    end
    
    it 'テンプレートの使用を記録する' do
      conversation = create(:conversation)
      
      tracking = service.track_template_performance(
        template: template,
        conversation: conversation,
        outcome: 'successful'
      )
      
      expect(tracking[:usage_count]).to eq(1)
      expect(tracking[:success_rate]).to be > 0
      expect(tracking[:last_used]).to be_present
    end
    
    it 'パフォーマンス統計を更新する' do
      # 複数回使用をシミュレート
      3.times do
        service.track_template_performance(
          template: template,
          conversation: create(:conversation),
          outcome: 'successful'
        )
      end
      
      stats = service.get_template_statistics(template[:id])
      
      expect(stats[:total_uses]).to eq(3)
      expect(stats[:success_rate]).to eq(1.0)
      expect(stats[:trending]).to be_in(['up', 'stable', 'down'])
    end
  end
  
  describe '#suggest_improvements' do
    let(:template) do
      {
        content: 'シンプルな応答',
        category: 'general',
        performance: { success_rate: 0.4 }
      }
    end
    
    before do
      # 高パフォーマンステンプレートをテストデータとして作成
      create(:knowledge_base,
             pattern_type: 'successful_conversation',
             content: { 
               'category' => 'general',
               'template' => '優れた応答テンプレート'
             },
             success_score: 90)
      create(:knowledge_base,
             pattern_type: 'successful_conversation',
             content: { 
               'category' => 'general',
               'template' => 'もう一つの優れたテンプレート'
             },
             success_score: 88)
    end
    
    it '低パフォーマンステンプレートの改善を提案する' do
      suggestions = service.suggest_improvements(template)
      
      expect(suggestions).not_to be_empty
      expect(suggestions[:recommended_changes]).to be_present
      expect(suggestions[:similar_high_performers]).to be_present
      expect(suggestions[:priority]).to eq('high')
    end
  end
end