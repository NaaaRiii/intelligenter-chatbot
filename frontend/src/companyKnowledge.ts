// 会社の知識ベース
export const companyKnowledge = {
  // 会社基本情報
  companyInfo: {
    name: "DataPro Solutions株式会社",
    established: "2016年",
    employees: "80名（エンジニア40名以上）",
    location: "東京都渋谷区",
    mission: "AIとデータの力で、マーケティングの新たな価値を創造する",
    vision: "デジタル時代のマーケティング変革をリードする",
    culture: [
      "フラットな組織体制",
      "迅速な意思決定",
      "挑戦を評価する文化",
      "継続的な学習と成長を重視"
    ]
  },

  // サービス詳細
  services: {
    marketing: {
      overview: "AIを活用したデータドリブンマーケティングの実現",
      capabilities: [
        "マーケティングDXコンサルティング",
        "CDP（カスタマーデータプラットフォーム）構築・分析",
        "MA/CRM導入・改善支援",
        "Web広告運用・最適化（Google, Facebook, Instagram, Twitter）",
        "SEO/コンテンツマーケティング戦略",
        "ECサイト運営支援（Shopify Plus パートナー）",
        "クリエイティブ制作・UI/UX設計"
      ],
      tools: [
        "Google Analytics 4",
        "BigQuery",
        "Google Tag Manager",
        "Salesforce",
        "HubSpot",
        "Marketo",
        "SendGrid"
      ],
      pricing: {
        consulting: "月額50万円〜",
        operation: "月額30万円〜（広告費別）",
        setup: "初期費用100万円〜",
        customPlatform: "300万円〜（カスタムプラットフォーム構築）"
      }
    },
    
    development: {
      overview: "クラウドネイティブな高速・低コストのソリューション開発",
      technologies: {
        frontend: ["React", "Vue.js", "Next.js", "TypeScript", "Tailwind CSS"],
        backend: ["Python", "Django", "FastAPI", "Node.js", "Go"],
        mobile: ["React Native", "Flutter", "PWA"],
        cloud: ["Google Cloud Platform（主力）", "AWS", "Docker", "Cloud Run", "App Engine"],
        database: ["MySQL", "Cloud Datastore", "BigQuery", "PostgreSQL", "Redis"],
        ai: ["OpenAI API", "Claude API", "Vertex AI", "独自ML モデル"],
        devOps: ["GitHub Actions", "Cloud Build", "Terraform", "Monitoring（Cloud Monitoring）"]
      },
      projectTypes: [
        "マーケティングプラットフォーム開発",
        "CDP（顧客データ基盤）構築",
        "ECサイト構築・最適化",
        "AIを活用した分析ダッシュボード",
        "MA/CRM カスタマイズ開発",
        "データパイプライン構築",
        "リアルタイム分析システム"
      ],
      timeline: {
        small: "1-2ヶ月（簡易的なWebサイト・LP）",
        medium: "3-6ヶ月（業務システム・ECサイト）",
        large: "6ヶ月以上（大規模プラットフォーム）"
      }
    },

    consulting: {
      overview: "マーケティングDXを中心とした包括的な変革支援",
      areas: [
        "マーケティングDX戦略立案",
        "データドリブン経営への転換支援",
        "CDP導入・データ統合戦略",
        "MA/CRM最適化コンサルティング",
        "AI活用による業務自動化",
        "組織のデジタル人材育成"
      ]
    },
    
    products: {
      dataPlatform: {
        name: "DataConnect Platform",
        description: "顧客データを統合・分析し、マーケティングを最適化するプラットフォーム",
        features: [
          "マルチチャネルデータ統合",
          "リアルタイム顧客セグメンテーション",
          "AI による行動予測",
          "自動レポーティング",
          "APIによる外部連携"
        ]
      },
      analyticsTools: {
        name: "Marketing Analytics Suite",
        description: "AIを活用した高度なマーケティング分析ツール",
        features: [
          "クロスチャネル分析",
          "カスタマージャーニー可視化",
          "ROI自動計算",
          "予測分析"
        ]
      }
    }
  },

  // 実績・事例
  caseStudies: [
    {
      industry: "小売業",
      client: "大手アパレルブランドA社",
      challenge: "ECサイトの売上が伸び悩んでいた",
      solution: "UI/UX改善とレコメンドエンジン導入",
      result: "CVR 200%向上、月商3億円達成",
      technologies: ["React", "Node.js", "AWS", "機械学習"]
    },
    {
      industry: "製造業",
      client: "中堅製造業B社",
      challenge: "在庫管理と生産計画の非効率",
      solution: "リアルタイム在庫管理システム構築",
      result: "在庫回転率30%改善、欠品率80%削減",
      technologies: ["Ruby on Rails", "PostgreSQL", "Docker"]
    },
    {
      industry: "サービス業",
      client: "人材サービスC社",
      challenge: "問い合わせ対応の人手不足",
      solution: "AIチャットボット導入",
      result: "問い合わせ対応の80%を自動化",
      technologies: ["Python", "Claude API", "React"]
    }
  ],

  // 強み・差別化ポイント
  strengths: [
    "マーケティングとエンジニアリングの両方に精通",
    "ワンストップでの対応が可能",
    "最新のAI技術を活用した効率的なソリューション",
    "アジャイル開発による柔軟な対応",
    "専任PMによる密なコミュニケーション",
    "業界特化型のノウハウ蓄積"
  ],

  // FAQ
  faq: {
    development: {
      "既存システムとの連携は可能ですか？": "はい、APIやデータベース連携など、様々な方法で既存システムとの連携が可能です。",
      "保守運用もお願いできますか？": "もちろんです。24時間365日の監視体制や定期メンテナンスなど、ご要望に応じた保守プランをご提供します。",
      "開発中の仕様変更は可能ですか？": "アジャイル開発を採用しているため、柔軟に対応可能です。ただし、大きな変更は追加費用が発生する場合があります。"
    },
    marketing: {
      "効果測定はどのように行いますか？": "KPIを明確に設定し、Google AnalyticsやMA ツールを使用して定量的に測定します。月次レポートで詳細をご報告します。",
      "広告予算はどれくらい必要ですか？": "業界や目標により異なりますが、一般的には月額30万円以上を推奨しています。",
      "BtoBマーケティングも対応可能ですか？": "はい、BtoB企業様の実績も多数ございます。リード獲得からナーチャリングまで一貫してサポートします。"
    },
    general: {
      "地方企業でも対応可能ですか？": "もちろんです。オンラインでの打ち合わせやリモート開発により、全国対応しております。",
      "予算が限られていますが相談できますか？": "ご予算に応じた最適なプランをご提案します。段階的な導入も可能です。",
      "契約期間の縛りはありますか？": "プロジェクトにより異なりますが、最短3ヶ月から対応可能です。"
    }
  }
};

// コンテキストから適切な情報を検索する関数
export function searchKnowledge(query: string): string {
  const lowerQuery = query.toLowerCase();
  let relevantInfo: string[] = [];

  // 具体的な金額に関する質問
  if (lowerQuery.includes('50万') || lowerQuery.includes('50万円')) {
    relevantInfo.push('月額50万円でご提供できるサービス:');
    relevantInfo.push('• マーケティングDXコンサルティング（戦略立案・実行支援）');
    relevantInfo.push('• CDP構築・データ統合による顧客分析');
    relevantInfo.push('• MA/CRM最適化とワークフロー設計');
    relevantInfo.push('• AIを活用した業務自動化の設計・実装');
    relevantInfo.push('• 月次レポート・改善提案');
    return relevantInfo.join('\n');
  }

  if (lowerQuery.includes('30万') || lowerQuery.includes('30万円')) {
    relevantInfo.push('月額30万円でご提供できるサービス:');
    relevantInfo.push('• Web広告運用・最適化（Google, Facebook等）');
    relevantInfo.push('• SEO/コンテンツマーケティング');
    relevantInfo.push('• 基本的なデータ分析・レポーティング');
    relevantInfo.push('• 既存システムの改善・最適化');
    return relevantInfo.join('\n');
  }

  if (lowerQuery.includes('100万') || lowerQuery.includes('100万円')) {
    relevantInfo.push('100万円でご提供できるサービス:');
    relevantInfo.push('• システム開発初期費用（基本設計・要件定義）');
    relevantInfo.push('• ECサイト構築・リニューアル');
    relevantInfo.push('• マーケティングプラットフォーム開発');
    relevantInfo.push('• データ分析基盤の構築');
    return relevantInfo.join('\n');
  }

  // 一般的なキーワードマッチング
  if (lowerQuery.includes('料金') || lowerQuery.includes('費用') || lowerQuery.includes('価格')) {
    relevantInfo.push(`マーケティング支援: ${companyKnowledge.services.marketing.pricing.consulting}`);
    relevantInfo.push(`広告運用: ${companyKnowledge.services.marketing.pricing.operation}`);
    relevantInfo.push('システム開発: プロジェクト規模により個別見積もり');
  }

  if (lowerQuery.includes('期間') || lowerQuery.includes('納期') || lowerQuery.includes('スケジュール')) {
    relevantInfo.push(`小規模: ${companyKnowledge.services.development.timeline.small}`);
    relevantInfo.push(`中規模: ${companyKnowledge.services.development.timeline.medium}`);
    relevantInfo.push(`大規模: ${companyKnowledge.services.development.timeline.large}`);
  }

  if (lowerQuery.includes('技術') || lowerQuery.includes('言語') || lowerQuery.includes('フレームワーク')) {
    relevantInfo.push('対応技術スタック:');
    relevantInfo.push(`フロントエンド: ${companyKnowledge.services.development.technologies.frontend.join(', ')}`);
    relevantInfo.push(`バックエンド: ${companyKnowledge.services.development.technologies.backend.join(', ')}`);
  }

  if (lowerQuery.includes('事例') || lowerQuery.includes('実績')) {
    companyKnowledge.caseStudies.forEach(study => {
      relevantInfo.push(`${study.industry} - ${study.client}: ${study.result}`);
    });
  }

  return relevantInfo.join('\n');
}

// AI応答を生成する関数
// ユーザーの課題に対して具体的な解決策を提案
// messageCountを追加して会話の流れを管理
export function generateAIResponse(userMessage: string, category: string, messageCount: number = 0): { message: string, showForm?: boolean } {
  const knowledge = searchKnowledge(userMessage);
  const lowerMessage = userMessage.toLowerCase();

  // 初回の課題入力時（カテゴリー選択後の最初の質問）
  if (messageCount === 0) {
    // 具体的な課題に対する提案
    if (lowerMessage.includes('営業') || lowerMessage.includes('リード') || lowerMessage.includes('新規顧客')) {
      return {
        message: `ご質問ありがとうございます。

営業・リード獲得の課題、非常によく理解できます。
弊社では以下のようなソリューションをご提供しています：

📊 **データドリブン営業支援**
・リード獲得チャネルの最適化
・スコアリングによるリードの質向上
・MAツールでのナーチャリング自動化

🎯 **実績**
同業他社ではリード獲得数を月間5件から50件に増加、
商談化率も150%向上した実績がございます。

詳しいプランをご提案させていただきたいのですが、
まずは無料診断で現状をお伺いできませんか？`,
        showForm: true
      };
    }

    if (lowerMessage.includes('ec') || lowerMessage.includes('ネットショップ') || lowerMessage.includes('通販')) {
      return {
        message: `ご質問ありがとうございます。

ECサイトの課題ですね。弊社のShopify Plusパートナーとしての
実績を活かし、以下のソリューションをご提案いたします：

🛒 **ECサイト最適化**
・UI/UX改善によるCVR向上
・AIレコメンドエンジン
・カート放棄対策
・リピーター育成プログラム

📈 **成果事例**
中堅EC事業者様でカート放棄率65%改善、
リピート率200%向上を実現しました。

貴社のECサイトの具体的な課題をお伺いし、
最適なプランをご提案いたします。`,
        showForm: true
      };
    }

    if (lowerMessage.includes('マーケティング') || lowerMessage.includes('広告') || lowerMessage.includes('集客')) {
      return {
        message: `ご質問ありがとうございます。

マーケティングの課題ですね。AIを活用した
データドリブンマーケティングで解決いたします：

🎯 **マーケティングDXソリューション**
・CDP構築による顧客データ統合
・AIを活用した広告最適化
・MA/CRM導入・最適化
・コンテンツマーケティング

📊 **実績**
大手不動産会社様でマーケティングROI 320%向上、
リード獲得コスト40%削減を達成しました。

まずは現状のマーケティング課題をお聞かせください。
無料診断で最適な改善プランをご提案いたします。`,
        showForm: true
      };
    }

    if (lowerMessage.includes('ai') || lowerMessage.includes('チャットボット') || lowerMessage.includes('自動')) {
      return {
        message: `ご質問ありがとうございます。

AI活用のご検討ですね。最新のAI技術で
業務効率化を実現します：

🤖 **AIソリューション**
・AIチャットボット（問い合わせ自動化）
・予測分析・需要予測
・自動コンテンツ生成
・データ分析・インサイト抽出

🎯 **導入事例**
人材サービス企業様で問い合わせ対応の80%を自動化、
オペレーターコストを年間2,000万円削減しました。

どのような業務へのAI活用をお考えでしょうか？
詳しくお聞かせください。`,
        showForm: true
      };
    }

    // その他の一般的な課題
    return {
      message: `ご質問ありがとうございます。

お客様の課題に対して、弊社では以下のような
ソリューションをご提供しています：

${knowledge}

詳しいプランをご提案させていただきたいので、
まずは無料診断でお話をお伺いできませんか？`,
      showForm: true
    };
  }
  
  // 2回目以降の返信（通常の会話継続）
  return {
    message: `承知いたしました。

${knowledge}

ご不明な点がございましたら、お気軽にお尋ねください。`,
    showForm: false
  };
}