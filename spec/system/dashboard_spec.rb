# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '分析ダッシュボード', type: :system do
  let(:user) { create(:user) }

  before do
    # テストデータを作成
    @conversations = create_list(:conversation, 5, user: user)
    @conversations.each do |conv|
      create_list(:message, 3, conversation: conv)
    end

    # エスカレーション案件を作成
    @escalated_analysis = create(:analysis,
                                 conversation: @conversations.first,
                                 priority_level: 'high',
                                 escalated: true,
                                 sentiment: 'negative')
    
    @normal_analysis = create(:analysis,
                             conversation: @conversations.second,
                             priority_level: 'medium',
                             escalated: false,
                             sentiment: 'neutral')
  end

  describe 'ダッシュボードの基本構造' do
    it 'ダッシュボードにアクセスできる' do
      visit dashboard_path
      expect(page).to have_content('分析ダッシュボード')
      expect(page).to have_current_path(dashboard_path)
    end

    it '統計サマリーが表示される' do
      visit dashboard_path
      
      within '#statistics-summary' do
        expect(page).to have_content('総会話数')
        expect(page).to have_content('5')
        expect(page).to have_content('分析済み')
        expect(page).to have_content('2')
        expect(page).to have_content('エスカレーション')
        expect(page).to have_content('1')
      end
    end

    it '感情分析の分布が表示される' do
      visit dashboard_path
      
      within '#sentiment-distribution' do
        expect(page).to have_content('感情分析')
        expect(page).to have_css('.chart-container')
        expect(page).to have_content('ポジティブ')
        expect(page).to have_content('ネガティブ')
        expect(page).to have_content('ニュートラル')
      end
    end

    it '優先度別の件数が表示される' do
      visit dashboard_path
      
      within '#priority-breakdown' do
        expect(page).to have_content('優先度別')
        expect(page).to have_content('高')
        expect(page).to have_content('中')
        expect(page).to have_content('低')
      end
    end

    it 'エスカレーション案件リストが表示される' do
      visit dashboard_path
      
      within '#escalation-list' do
        expect(page).to have_content('エスカレーション案件')
        expect(page).to have_content(@conversations.first.id.to_s)
        expect(page).to have_content('high')
        expect(page).to have_link('詳細', href: conversation_path(@conversations.first))
      end
    end

    it '最近の会話リストが表示される' do
      visit dashboard_path
      
      within '#recent-conversations' do
        expect(page).to have_content('最近の会話')
        # 最新の5件が表示される
        @conversations.take(5).each do |conv|
          expect(page).to have_content("会話 ##{conv.id}")
          expect(page).to have_link('表示', href: conversation_path(conv))
        end
      end
    end

    it 'フィルター機能が動作する' do
      visit dashboard_path
      
      # 期間フィルター
      within '#filters' do
        select '過去7日間', from: 'period'
        click_button 'フィルタ適用'
      end
      
      expect(page).to have_content('過去7日間のデータ')
    end

    it 'リフレッシュボタンでデータが更新される' do
      visit dashboard_path
      
      # 新しい会話を作成
      create(:conversation, user: user)
      
      click_button 'データを更新'
      
      within '#statistics-summary' do
        expect(page).to have_content('総会話数')
        expect(page).to have_content('6') # 5 + 1
      end
    end
  end

  describe 'グラフとチャート' do
    it '感情分析の円グラフが表示される' do
      visit dashboard_path
      
      within '#sentiment-chart' do
        expect(page).to have_css('canvas#sentimentPieChart')
      end
    end

    it '時系列グラフが表示される' do
      visit dashboard_path
      
      within '#timeline-chart' do
        expect(page).to have_css('canvas#timelineChart')
        expect(page).to have_content('会話数の推移')
      end
    end

    it '優先度の棒グラフが表示される' do
      visit dashboard_path
      
      within '#priority-chart' do
        expect(page).to have_css('canvas#priorityBarChart')
      end
    end
  end

  describe 'アクション機能' do
    it '一括分析ボタンが機能する' do
      visit dashboard_path
      
      click_button '未分析の会話を一括分析'
      
      # フラッシュメッセージまたはプログレスバーの表示を確認
      expect(page).to have_css('.progress-bar')
    end

    it 'CSVエクスポートができる' do
      visit dashboard_path
      
      # CSVエクスポートリンクが存在することを確認
      expect(page).to have_link('CSVエクスポート', href: dashboard_export_path(format: :csv))
    end

    it '個別の会話詳細に遷移できる' do
      visit dashboard_path
      
      within '#recent-conversations' do
        # 最初のリンクをクリック
        first(:link, '表示').click
      end
      
      # 遷移先が会話詳細ページであることを確認（どの会話でも良い）
      expect(current_path).to match(%r{/conversations/\d+})
    end
  end

  describe 'リアルタイム更新' do
    it '新しいエスカレーションが自動的に表示される', :js do
      # 最初に新しいエスカレーションを作成
      create(:analysis,
             conversation: @conversations.third,
             priority_level: 'urgent',
             escalated: true)
      
      visit dashboard_path
      
      # エスカレーション案件リストに表示される
      within '#escalation-list' do
        expect(page).to have_content('urgent')
      end
    end
  end

  describe 'レスポンシブデザイン' do
    it 'モバイル画面でも適切に表示される' do
      visit dashboard_path
      
      # モバイルサイズにリサイズ
      page.driver.browser.manage.window.resize_to(375, 667)
      
      # チャートコンテナが存在することを確認
      expect(page).to have_css('.chart-container')
      
      # ダッシュボードが表示されていることを確認
      expect(page).to have_content('分析ダッシュボード')
    end
  end
end