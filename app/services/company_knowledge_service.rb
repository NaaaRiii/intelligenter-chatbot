# frozen_string_literal: true

# 会社の知識ベースを管理するサービス
class CompanyKnowledgeService
  def company_info
    {
      name: 'DataPro Solutions株式会社',
      established: '2016年',
      employees: '80名（エンジニア40名以上）',
      location: '東京都渋谷区',
      mission: 'AIとデータの力で、マーケティングの新たな価値を創造する',
      vision: 'デジタル時代のマーケティング変革をリードする',
      culture: [
        'フラットな組織体制',
        '迅速な意思決定',
        '挑戦を評価する文化',
        '継続的な学習と成長を重視'
      ]
    }
  end

  def services
    {
      marketing: marketing_service,
      development: development_service,
      consulting: consulting_service,
      products: products_info
    }
  end

  def case_studies
    [
      {
        industry: '小売業',
        client: '大手アパレルブランドA社',
        challenge: 'ECサイトの売上が伸び悩んでいた',
        solution: 'UI/UX改善とレコメンドエンジン導入',
        result: 'CVR 200%向上、月商3億円達成',
        technologies: ['React', 'Node.js', 'AWS', '機械学習']
      },
      {
        industry: '製造業',
        client: '中堅製造業B社',
        challenge: '在庫管理と生産計画の非効率',
        solution: 'リアルタイム在庫管理システム構築',
        result: '在庫回転率30%改善、欠品率80%削減',
        technologies: ['Ruby on Rails', 'PostgreSQL', 'Docker']
      },
      {
        industry: 'サービス業',
        client: '人材サービスC社',
        challenge: '問い合わせ対応の人手不足',
        solution: 'AIチャットボット導入',
        result: '問い合わせ対応の80%を自動化',
        technologies: ['Python', 'Claude API', 'React']
      }
    ]
  end

  def search_knowledge(query)
    query_lower = query.downcase
    relevant_info = []

    if query_lower.match?(/料金|費用|価格|コスト|予算/)
      relevant_info << "マーケティング支援: #{services[:marketing][:pricing][:consulting]}"
      relevant_info << "広告運用: #{services[:marketing][:pricing][:operation]}"
      relevant_info << 'システム開発: プロジェクト規模により個別見積もり'
    end

    if query_lower.match?(/期間|納期|スケジュール|いつ/)
      relevant_info << "小規模: #{services[:development][:timeline][:small]}"
      relevant_info << "中規模: #{services[:development][:timeline][:medium]}"
      relevant_info << "大規模: #{services[:development][:timeline][:large]}"
    end

    if query_lower.match?(/技術|言語|フレームワーク|スタック/)
      relevant_info << '対応技術スタック:'
      relevant_info << "フロントエンド: #{services[:development][:technologies][:frontend].join(', ')}"
      relevant_info << "バックエンド: #{services[:development][:technologies][:backend].join(', ')}"
    end

    if query_lower.match?(/事例|実績|成功|導入/)
      case_studies.each do |study|
        relevant_info << "#{study[:industry]} - #{study[:client]}: #{study[:result]}"
      end
    end

    relevant_info.join("\n")
  end

  def find_faq(question)
    question_lower = question.downcase
    
    # デバッグ用: 地方企業のキーワードを直接チェック
    if question_lower.include?('地方')
      return faq_database[:general]['地方企業でも対応可能ですか？']
    end
    
    faq_database.each do |category, faqs|
      faqs.each do |q, answer|
        # 部分一致またはキーワードマッチング
        q_lower = q.downcase
        if question_lower.include?(q_lower) || 
           q_lower.include?(question_lower) ||
           fuzzy_match(question_lower, q_lower)
          return answer
        end
      end
    end

    '申し訳ございませんが、該当するFAQが見つかりませんでした。詳細はお問い合わせください。'
  end

  def get_service_by_category(category)
    case category
    when 'marketing'
      services[:marketing]
    when 'tech', 'development'
      services[:development]
    when 'consulting'
      services[:consulting]
    else
      services
    end
  end

  def format_for_prompt(category: nil)
    if category
      format_category_prompt(category)
    else
      format_full_prompt
    end
  end

  def get_relevant_info(message)
    {
      services: extract_relevant_services(message),
      timeline: extract_timeline_info(message),
      case_studies: extract_relevant_cases(message),
      pricing: extract_pricing_info(message)
    }
  end

  private

  def marketing_service
    {
      overview: 'AIを活用したデータドリブンマーケティングの実現',
      capabilities: [
        'マーケティングDXコンサルティング',
        'CDP（カスタマーデータプラットフォーム）構築・分析',
        'MA/CRM導入・改善支援',
        'Web広告運用・最適化（Google, Facebook, Instagram, Twitter）',
        'SEO/コンテンツマーケティング戦略',
        'ECサイト運営支援（Shopify Plus パートナー）',
        'クリエイティブ制作・UI/UX設計'
      ],
      tools: [
        'Google Analytics 4',
        'BigQuery',
        'Google Tag Manager',
        'Salesforce',
        'HubSpot',
        'Marketo',
        'SendGrid'
      ],
      pricing: {
        consulting: '月額50万円〜',
        operation: '月額30万円〜（広告費別）',
        setup: '初期費用100万円〜',
        custom_platform: '300万円〜（カスタムプラットフォーム構築）'
      }
    }
  end

  def development_service
    {
      overview: 'クラウドネイティブな高速・低コストのソリューション開発',
      technologies: {
        frontend: ['React', 'Vue.js', 'Next.js', 'TypeScript', 'Tailwind CSS'],
        backend: ['Python', 'Django', 'FastAPI', 'Node.js', 'Go'],
        mobile: ['React Native', 'Flutter', 'PWA'],
        cloud: ['Google Cloud Platform（主力）', 'AWS', 'Docker', 'Cloud Run', 'App Engine'],
        database: ['MySQL', 'Cloud Datastore', 'BigQuery', 'PostgreSQL', 'Redis'],
        ai: ['OpenAI API', 'Claude API', 'Vertex AI', '独自ML モデル'],
        devops: ['GitHub Actions', 'Cloud Build', 'Terraform', 'Monitoring（Cloud Monitoring）']
      },
      project_types: [
        'マーケティングプラットフォーム開発',
        'CDP（顧客データ基盤）構築',
        'ECサイト構築・最適化',
        'AIを活用した分析ダッシュボード',
        'MA/CRM カスタマイズ開発',
        'データパイプライン構築',
        'リアルタイム分析システム'
      ],
      timeline: {
        small: '1-2ヶ月（簡易的なWebサイト・LP）',
        medium: '3-6ヶ月（業務システム・ECサイト）',
        large: '6ヶ月以上（大規模プラットフォーム）'
      }
    }
  end

  def consulting_service
    {
      overview: 'マーケティングDXを中心とした包括的な変革支援',
      areas: [
        'マーケティングDX戦略立案',
        'データドリブン経営への転換支援',
        'CDP導入・データ統合戦略',
        'MA/CRM最適化コンサルティング',
        'AI活用による業務自動化',
        '組織のデジタル人材育成'
      ]
    }
  end

  def products_info
    {
      data_platform: {
        name: 'DataConnect Platform',
        description: '顧客データを統合・分析し、マーケティングを最適化するプラットフォーム',
        features: [
          'マルチチャネルデータ統合',
          'リアルタイム顧客セグメンテーション',
          'AI による行動予測',
          '自動レポーティング',
          'APIによる外部連携'
        ]
      },
      analytics_tools: {
        name: 'Marketing Analytics Suite',
        description: 'AIを活用した高度なマーケティング分析ツール',
        features: [
          'クロスチャネル分析',
          'カスタマージャーニー可視化',
          'ROI自動計算',
          '予測分析'
        ]
      }
    }
  end

  def faq_database
    {
      development: {
        '既存システムとの連携は可能ですか？' => 'はい、APIやデータベース連携など、様々な方法で既存システムとの連携が可能です。',
        '保守運用もお願いできますか？' => 'もちろんです。24時間365日の監視体制や定期メンテナンスなど、ご要望に応じた保守プランをご提供します。',
        '開発中の仕様変更は可能ですか？' => 'アジャイル開発を採用しているため、柔軟に対応可能です。ただし、大きな変更は追加費用が発生する場合があります。'
      },
      marketing: {
        '効果測定はどのように行いますか？' => 'KPIを明確に設定し、Google AnalyticsやMA ツールを使用して定量的に測定します。月次レポートで詳細をご報告します。',
        '広告予算はどれくらい必要ですか？' => '業界や目標により異なりますが、一般的には月額30万円以上を推奨しています。',
        'BtoBマーケティングも対応可能ですか？' => 'はい、BtoB企業様の実績も多数ございます。リード獲得からナーチャリングまで一貫してサポートします。'
      },
      general: {
        '地方企業でも対応可能ですか？' => 'もちろんです。オンラインでの打ち合わせやリモート開発により、全国対応しております。',
        '予算が限られていますが相談できますか？' => 'ご予算に応じた最適なプランをご提案します。段階的な導入も可能です。',
        '契約期間の縛りはありますか？' => 'プロジェクトにより異なりますが、最短3ヶ月から対応可能です。'
      }
    }
  end

  def fuzzy_match(str1, str2)
    # 簡易的な類似度マッチング
    common_keywords = %w[連携 システム 保守 運用 対応 可能 地方 企業]
    
    # キーワードマッチング
    if common_keywords.any? { |keyword| str1.include?(keyword) && str2.include?(keyword) }
      return true
    end
    
    # 特定のパターンマッチング
    if str1.include?('地方') && str2.include?('地方')
      return true
    end
    
    false
  end

  def format_full_prompt
    <<~PROMPT
      ## 会社概要
      #{company_info[:name]}
      設立: #{company_info[:established]}
      従業員数: #{company_info[:employees]}
      所在地: #{company_info[:location]}
      ミッション: #{company_info[:mission]}

      ## サービス概要
      ### マーケティング支援
      #{services[:marketing][:overview]}
      主要機能: #{services[:marketing][:capabilities].join(', ')}
      料金: #{services[:marketing][:pricing].values.join(', ')}

      ### システム開発
      #{services[:development][:overview]}
      技術スタック:
      - フロントエンド: #{services[:development][:technologies][:frontend].join(', ')}
      - バックエンド: #{services[:development][:technologies][:backend].join(', ')}
      - クラウド: #{services[:development][:technologies][:cloud].join(', ')}

      ## 実績
      #{case_studies.map { |c| "- #{c[:industry]}: #{c[:result]}" }.join("\n")}

      ## 強み
      - マーケティングとエンジニアリングの両方に精通
      - ワンストップでの対応が可能
      - 最新のAI技術を活用した効率的なソリューション
      - アジャイル開発による柔軟な対応
    PROMPT
  end

  def format_category_prompt(category)
    case category
    when 'marketing'
      <<~PROMPT
        ## マーケティング支援サービス
        #{services[:marketing][:overview]}
        
        ### 提供サービス
        #{services[:marketing][:capabilities].map { |c| "- #{c}" }.join("\n")}
        
        ### 料金体系
        - コンサルティング: #{services[:marketing][:pricing][:consulting]}
        - 広告運用: #{services[:marketing][:pricing][:operation]}
        - 初期設定: #{services[:marketing][:pricing][:setup]}
        
        ### 使用ツール
        #{services[:marketing][:tools].join(', ')}
      PROMPT
    when 'tech', 'development'
      <<~PROMPT
        ## システム開発サービス
        #{services[:development][:overview]}
        
        ### 技術スタック
        #{services[:development][:technologies].map { |k, v| "- #{k}: #{v.join(', ')}" }.join("\n")}
        
        ### 開発期間
        - 小規模: #{services[:development][:timeline][:small]}
        - 中規模: #{services[:development][:timeline][:medium]}
        - 大規模: #{services[:development][:timeline][:large]}
      PROMPT
    else
      format_full_prompt
    end
  end

  def extract_relevant_services(message)
    relevant = []
    message_lower = message.downcase

    # マーケティング関連サービスの抽出
    services[:marketing][:capabilities].each do |capability|
      keywords = capability.downcase.split(/[・（）、]/)
      if keywords.any? { |keyword| message_lower.include?(keyword.strip) && keyword.strip.length > 2 }
        relevant << capability
      end
    end

    # 開発関連サービスの抽出
    services[:development][:project_types].each do |project_type|
      keywords = project_type.downcase.split(/[・（）、]/)
      if keywords.any? { |keyword| message_lower.include?(keyword.strip) && keyword.strip.length > 2 }
        relevant << project_type
      end
    end

    # 特定キーワードの直接マッチング
    relevant << 'ECサイト構築' if message_lower.include?('ec')
    relevant << '広告' if message_lower.include?('広告')
    relevant << 'SEO' if message_lower.include?('seo')

    relevant.uniq
  end

  def extract_timeline_info(message)
    timeline_info = []
    
    if message.match?(/期間|納期|いつ|ヶ月|月/)
      timeline_info = services[:development][:timeline].values
    end
    
    timeline_info
  end

  def extract_relevant_cases(message)
    message_lower = message.downcase
    
    # ECサイトに関連する事例を優先的に返す
    if message_lower.include?('ec')
      return case_studies.select { |c| c[:industry] == '小売業' || c[:solution].include?('EC') }
    end
    
    case_studies.select do |study|
      message_lower.include?(study[:industry]) ||
        study[:technologies].any? { |tech| message_lower.include?(tech.downcase) }
    end
  end

  def extract_pricing_info(message)
    pricing_info = []
    
    if message.match?(/料金|費用|価格|予算/)
      pricing_info = services[:marketing][:pricing].values
    end
    
    # 広告に関する価格情報
    if message.match?(/広告/)
      pricing_info << services[:marketing][:pricing][:operation]
    end
    
    pricing_info.uniq
  end
end