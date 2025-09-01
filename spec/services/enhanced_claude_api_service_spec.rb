# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnhancedClaudeApiService do
  let(:service) { described_class.new }
  let(:conversation_history) { [] }
  let(:user_message) { 'Google広告の運用について相談したい' }

  describe '#generate_response' do
    context '基本的な応答生成' do
      it 'ユーザーメッセージに対して応答を生成する' do
        allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(
          { 'content' => [{ 'type' => 'text', 'text' => 'テスト応答' }] }
        )

        response = service.generate_response(conversation_history, user_message)
        
        expect(response).to eq('テスト応答')
      end

      it 'エラー時にフォールバック応答を返す' do
        allow_any_instance_of(Anthropic::Client).to receive(:messages).and_raise(StandardError)

        response = service.generate_response(conversation_history, user_message)
        
        expect(response).to include('申し訳ございません')
      end
    end
  end

  describe '#enhanced_system_prompt' do
    it '専門性重視型プロンプトを含む' do
      prompt = service.enhanced_system_prompt
      
      expect(prompt).to include('デジタルマーケティング')
      expect(prompt).to include('専門AIアシスタント')
      expect(prompt).to include('Google Ads')
      expect(prompt).to include('SEO')
    end

    it '会社情報を含む' do
      prompt = service.enhanced_system_prompt
      
      expect(prompt).to include('DataPro Solutions株式会社')
      expect(prompt).to include('2016年')
      expect(prompt).to include('80名')
    end

    it '情報収集ルールを含む' do
      prompt = service.enhanced_system_prompt
      
      expect(prompt).to include('事業概要')
      expect(prompt).to include('マーケティング現状')
      expect(prompt).to include('目標・KPI')
    end

    it '回答スタイルガイドラインを含む' do
      prompt = service.enhanced_system_prompt
      
      expect(prompt).to include('具体的で実践的な提案')
      expect(prompt).to include('メリット・デメリット')
      expect(prompt).to include('次のステップ')
    end
  end

  describe '#build_contextualized_messages' do
    let(:inquiry_analysis) {
      {
        category: 'marketing',
        intent: 'information_gathering',
        urgency: 'normal',
        keywords: ['Google広告', '運用'],
        entities: { budget: '月額50万円' }
      }
    }

    it '分析結果を含むコンテキストを構築する' do
      messages = service.build_contextualized_messages(
        conversation_history,
        user_message,
        inquiry_analysis
      )
      
      expect(messages.last[:content]).to include(user_message)
      expect(messages.last[:content]).to include('カテゴリ: marketing')
      expect(messages.last[:content]).to include('意図: information_gathering')
    end

    it '関連する会社情報を含む' do
      messages = service.build_contextualized_messages(
        conversation_history,
        user_message,
        inquiry_analysis
      )
      
      content = messages.last[:content]
      expect(content).to include('関連情報')
    end
  end

  describe '#should_collect_info?' do
    it '初回メッセージの場合はtrueを返す' do
      result = service.should_collect_info?([], {})
      expect(result).to be true
    end

    it '必要情報が揃っている場合はfalseを返す' do
      conversation_history = [
        { role: 'user', content: '弊社は小売業です' },
        { role: 'user', content: '月額予算は100万円です' },
        { role: 'user', content: 'CVR向上が目標です' }
      ]
      
      metadata = {
        'customer_profile' => {
          'industry' => '小売業',
          'budget_range' => '100万円',
          'main_challenges' => ['CVR向上']
        }
      }
      
      result = service.should_collect_info?(conversation_history, metadata)
      expect(result).to be false
    end
  end

  describe '#generate_info_collection_questions' do
    it 'マーケティングカテゴリの質問を生成する' do
      questions = service.generate_info_collection_questions('marketing', {})
      
      expect(questions.any? { |q| q.include?('マーケティング施策') }).to be true
      expect(questions.any? { |q| q.include?('予算') }).to be true
      expect(questions.any? { |q| q.include?('KPI') }).to be true
    end

    it '技術カテゴリの質問を生成する' do
      questions = service.generate_info_collection_questions('tech', {})
      
      expect(questions.any? { |q| q.include?('技術スタック') }).to be true
      expect(questions.any? { |q| q.include?('チームの規模') }).to be true
      expect(questions.any? { |q| q.include?('課題') }).to be true
    end

    it '既に収集済みの情報は質問しない' do
      metadata = {
        'customer_profile' => {
          'budget_range' => '100万円'
        }
      }
      
      questions = service.generate_info_collection_questions('marketing', metadata)
      
      expect(questions).not_to include('予算')
    end
  end

  describe '#handle_out_of_scope' do
    it '専門外の質問に対して適切な応答を返す' do
      response = service.handle_out_of_scope('法律相談')
      
      expect(response).to include('専門領域外')
      expect(response).to include('法律')
      expect(response).to include('デジタルマーケティングの観点')
    end
  end

  describe '#add_follow_up_question' do
    it '応答にフォローアップ質問を追加する' do
      base_response = 'Google広告の設定方法は以下の通りです。'
      enhanced = service.add_follow_up_question(base_response, 'marketing')
      
      expect(enhanced).to include(base_response)
      expect(enhanced).to match(/他にも.*についてご質問はありませんか？|次は.*について掘り下げてみましょうか？/)
    end
  end

  describe '#format_with_company_knowledge' do
    it 'カテゴリに応じた会社情報を含む' do
      formatted = service.format_with_company_knowledge('marketing')
      
      expect(formatted).to include('マーケティング支援')
      expect(formatted).to include('月額50万円〜')
      expect(formatted).to include('Google Analytics')
    end
  end

  describe '#integration with InquiryAnalyzer' do
    it '問い合わせ分析と統合して動作する' do
      analyzer = InquiryAnalyzerService.new
      analysis = analyzer.analyze(user_message, conversation_history)
      
      allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(
        { 'content' => [{ 'type' => 'text', 'text' => 'マーケティング支援について回答します' }] }
      )
      
      response = service.generate_enhanced_response(
        conversation_history,
        user_message,
        analysis
      )
      
      expect(response).to include('マーケティング')
    end
  end
end