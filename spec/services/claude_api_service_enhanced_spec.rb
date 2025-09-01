# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaudeApiService do
  let(:service) { described_class.new }
  let(:conversation_history) { [] }
  let(:user_message) { 'ECサイトの売上を改善したい' }

  describe '#system_prompt (enhanced)' do
    it 'デジタルマーケティング専門の設定を含む' do
      prompt = service.system_prompt
      
      expect(prompt).to include('デジタルマーケティング')
      expect(prompt).to include('専門AIアシスタント')
    end

    it '会社情報を含む' do
      prompt = service.system_prompt
      
      expect(prompt).to include('DataPro Solutions株式会社')
      expect(prompt).to include('2016年')
      expect(prompt).to include('マーケティング支援')
    end

    it '専門領域の定義を含む' do
      prompt = service.system_prompt
      
      expect(prompt).to include('Google Ads')
      expect(prompt).to include('SEO・コンテンツマーケティング')
      expect(prompt).to include('ECサイト運営')
    end

    it '情報収集ルールを含む' do
      prompt = service.system_prompt
      
      expect(prompt).to include('事業概要')
      expect(prompt).to include('マーケティング現状')
      expect(prompt).to include('目標・KPI')
    end

    it '回答スタイルガイドラインを含む' do
      prompt = service.system_prompt
      
      expect(prompt).to include('具体的で実践的な提案')
      expect(prompt).to include('メリット・デメリット')
      expect(prompt).to include('次のステップ')
    end

    it '会話管理ルールを含む' do
      prompt = service.system_prompt
      
      expect(prompt).to include('3往復')
      expect(prompt).to include('エスカレーション')
    end
  end

  describe '#chatbot_system_prompt (enhanced)' do
    it '専門性とカスタマーサポートの両方の要素を含む' do
      prompt = service.chatbot_system_prompt
      
      expect(prompt).to include('BtoB SaaS')
      expect(prompt).to include('カスタマーサポート')
      expect(prompt).to include('デジタルマーケティング')
    end

    it '会社のサービス情報を含む' do
      prompt = service.chatbot_system_prompt
      
      expect(prompt).to include('CDP')
      expect(prompt).to include('MA/CRM')
      expect(prompt).to include('広告運用')
    end
  end

  describe '#generate_response with enhanced prompt' do
    context 'マーケティング関連の質問' do
      let(:user_message) { 'Google広告の最適化について教えてください' }

      it '専門的な知識を活用した応答を生成する' do
        allow_any_instance_of(Anthropic::Client).to receive(:messages) do |_, args|
          # system_promptに専門知識が含まれていることを確認
          expect(args[:system]).to include('Google Ads')
          expect(args[:system]).to include('DataPro Solutions')
          
          { 'content' => [{ 'type' => 'text', 'text' => 'Google広告の最適化について回答します' }] }
        end

        response = service.generate_response(conversation_history, user_message)
        expect(response).to include('Google広告')
      end
    end

    context '会社情報を活用した応答' do
      let(:user_message) { '御社の実績を教えてください' }

      it 'system_promptに含まれる会社情報を参照できる' do
        allow_any_instance_of(Anthropic::Client).to receive(:messages) do |_, args|
          # system_promptに実績情報が含まれていることを確認
          expect(args[:system]).to include('CVR')
          expect(args[:system]).to include('小売業')
          
          { 'content' => [{ 'type' => 'text', 'text' => '弊社の実績をご紹介します' }] }
        end

        response = service.generate_response(conversation_history, user_message)
        expect(response).to include('実績')
      end
    end
  end

  describe '#build_analysis_prompt with enhanced context' do
    it '会社の専門知識を考慮した分析プロンプトを生成する' do
      prompt = service.build_analysis_prompt(conversation_history, user_message)
      
      expect(prompt).to include('隠れたニーズ')
      expect(prompt).to include('プロアクティブな提案')
    end
  end

  describe '#analyze_conversation with enhanced knowledge' do
    it '専門知識を活用して会話を分析する' do
      allow_any_instance_of(Anthropic::Client).to receive(:messages) do |_, args|
        # 分析時も拡張されたプロンプトを使用していることを確認
        expect(args[:system]).to include('デジタルマーケティング')
        
        {
          'content' => [{
            'type' => 'text',
            'text' => '{"hidden_needs": [{"need_type": "効率化", "evidence": "売上改善", "confidence": 0.8, "proactive_suggestion": "ECサイト最適化"}], "customer_sentiment": "positive", "priority_level": "high", "escalation_required": false}'
          }]
        }
      end

      result = service.analyze_conversation(conversation_history, user_message)
      
      expect(result).to have_key('hidden_needs')
      expect(result['hidden_needs'].first).to have_key('proactive_suggestion')
    end
  end

  describe 'integration with InquiryAnalyzerService' do
    it '問い合わせ分析と統合して動作する' do
      analyzer = InquiryAnalyzerService.new
      analysis = analyzer.analyze(user_message, conversation_history)
      
      allow_any_instance_of(Anthropic::Client).to receive(:messages) do |_, args|
        # カテゴリに応じた専門知識が含まれることを確認
        if analysis[:category] == 'marketing'
          expect(args[:system]).to include('マーケティング')
        end
        
        { 'content' => [{ 'type' => 'text', 'text' => '分析結果を考慮した応答' }] }
      end
      
      response = service.generate_response(conversation_history, user_message)
      expect(response).not_to be_nil
    end
  end

  describe 'integration with CompanyKnowledgeService' do
    it '会社情報サービスと連携する' do
      knowledge_service = CompanyKnowledgeService.new
      company_info = knowledge_service.format_for_prompt
      
      prompt = service.system_prompt
      
      # 会社情報の主要な要素が含まれていることを確認
      expect(prompt).to include('DataPro Solutions')
      expect(prompt).to include('マーケティング')
      expect(prompt).to include('システム開発')
    end
  end
end