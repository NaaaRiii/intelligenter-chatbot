# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CompanyKnowledgeService do
  let(:service) { described_class.new }

  describe '#company_info' do
    it '会社の基本情報を返す' do
      info = service.company_info
      
      expect(info[:name]).to eq('DataPro Solutions株式会社')
      expect(info[:established]).to eq('2016年')
      expect(info[:employees]).to eq('80名（エンジニア40名以上）')
      expect(info[:location]).to eq('東京都渋谷区')
      expect(info[:mission]).to include('AI')
      expect(info[:culture]).to be_an(Array)
      expect(info[:culture]).to include('フラットな組織体制')
    end
  end

  describe '#services' do
    context 'マーケティングサービス' do
      it 'マーケティングサービスの詳細を返す' do
        marketing = service.services[:marketing]
        
        expect(marketing[:overview]).to include('AIを活用')
        expect(marketing[:capabilities]).to be_an(Array)
        expect(marketing[:capabilities]).to include('CDP（カスタマーデータプラットフォーム）構築・分析')
        expect(marketing[:tools]).to include('Google Analytics 4')
        expect(marketing[:pricing][:consulting]).to eq('月額50万円〜')
      end
    end

    context '開発サービス' do
      it '開発サービスの技術スタックを返す' do
        development = service.services[:development]
        
        expect(development[:technologies][:frontend]).to include('React', 'Vue.js', 'Next.js')
        expect(development[:technologies][:backend]).to include('Python', 'Django', 'Go')
        expect(development[:technologies][:cloud]).to include('Google Cloud Platform（主力）')
        expect(development[:technologies][:ai]).to include('Claude API')
      end

      it 'プロジェクトタイプと納期を返す' do
        development = service.services[:development]
        
        expect(development[:project_types]).to include('AIを活用した分析ダッシュボード')
        expect(development[:timeline][:small]).to include('1-2ヶ月')
        expect(development[:timeline][:medium]).to include('3-6ヶ月')
      end
    end
  end

  describe '#case_studies' do
    it '実績・事例を返す' do
      cases = service.case_studies
      
      expect(cases).to be_an(Array)
      expect(cases.size).to be >= 3
      
      apparel_case = cases.find { |c| c[:client] == '大手アパレルブランドA社' }
      expect(apparel_case[:industry]).to eq('小売業')
      expect(apparel_case[:result]).to include('CVR 200%向上')
      expect(apparel_case[:technologies]).to include('React')
    end
  end

  describe '#search_knowledge' do
    context '料金に関する質問' do
      it '料金情報を検索して返す' do
        result = service.search_knowledge('料金を教えてください')
        
        expect(result).to include('マーケティング支援: 月額50万円〜')
        expect(result).to include('広告運用: 月額30万円〜')
      end
    end

    context '技術に関する質問' do
      it '技術スタック情報を返す' do
        result = service.search_knowledge('どんな技術を使っていますか')
        
        expect(result).to include('React')
        expect(result).to include('Python')
        expect(result).to include('フロントエンド')
        expect(result).to include('バックエンド')
      end
    end

    context '事例に関する質問' do
      it '実績情報を返す' do
        result = service.search_knowledge('実績を見せてください')
        
        expect(result).to include('小売業')
        expect(result).to include('CVR 200%向上')
      end
    end

    context '期間に関する質問' do
      it '納期情報を返す' do
        result = service.search_knowledge('どのくらいの期間で完成しますか')
        
        expect(result).to include('小規模: 1-2ヶ月')
        expect(result).to include('中規模: 3-6ヶ月')
        expect(result).to include('大規模: 6ヶ月以上')
      end
    end
  end

  describe '#find_faq' do
    it 'FAQから関連する回答を見つける' do
      result = service.find_faq('既存システムと連携できますか')
      
      expect(result).to include('APIやデータベース連携')
      expect(result).to include('様々な方法で既存システムとの連携が可能')
    end

    it '保守運用に関するFAQを返す' do
      result = service.find_faq('保守運用もお願いできますか')
      
      expect(result).to include('24時間365日')
      expect(result).to include('定期メンテナンス')
    end

    it '地方企業に関するFAQを返す' do
      result = service.find_faq('地方企業でも対応可能ですか')
      
      expect(result).to include('全国対応')
      expect(result).to include('オンライン')
    end
  end

  describe '#get_service_by_category' do
    it 'カテゴリに応じたサービス情報を返す' do
      result = service.get_service_by_category('marketing')
      
      expect(result[:overview]).to include('AI')
      expect(result[:capabilities]).to be_an(Array)
    end

    it '技術カテゴリのサービス情報を返す' do
      result = service.get_service_by_category('tech')
      
      expect(result[:technologies]).to be_a(Hash)
      expect(result[:technologies][:frontend]).to include('React')
    end

    it '不明なカテゴリの場合は全体概要を返す' do
      result = service.get_service_by_category('unknown')
      
      expect(result).to have_key(:marketing)
      expect(result).to have_key(:development)
    end
  end

  describe '#format_for_prompt' do
    it 'Claude API用にフォーマットされた会社情報を返す' do
      formatted = service.format_for_prompt
      
      expect(formatted).to be_a(String)
      expect(formatted).to include('DataPro Solutions株式会社')
      expect(formatted).to include('サービス概要')
      expect(formatted).to include('技術スタック')
      expect(formatted).to include('実績')
      expect(formatted).to include('料金')
    end

    it 'カテゴリを指定した場合、関連情報のみを含む' do
      formatted = service.format_for_prompt(category: 'marketing')
      
      expect(formatted).to include('マーケティング')
      expect(formatted).to include('CDP')
      expect(formatted).to include('月額50万円')
    end
  end

  describe '#get_relevant_info' do
    it 'メッセージに関連する情報を抽出する' do
      message = 'ECサイトを3ヶ月で開発したい。予算は500万円です。'
      info = service.get_relevant_info(message)
      
      expect(info[:services]).to include('ECサイト構築')
      expect(info[:timeline].any? { |t| t.include?('3-6ヶ月') }).to be true
      expect(info[:case_studies]).to be_an(Array)
      expect(info[:case_studies].any? { |c| c[:industry] == '小売業' }).to be true
    end

    it 'マーケティング関連の情報を抽出する' do
      message = '広告運用とSEO対策をお願いしたい'
      info = service.get_relevant_info(message)
      
      expect(info[:services]).to include('広告')
      expect(info[:services]).to include('SEO')
      expect(info[:pricing].any? { |p| p.include?('月額30万円') }).to be true
    end
  end
end