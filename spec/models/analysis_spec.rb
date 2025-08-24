require 'rails_helper'

RSpec.describe Analysis, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:conversation) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:analysis_data) }
    it { is_expected.to validate_presence_of(:analysis_type) }
    it { is_expected.to validate_inclusion_of(:analysis_type).in_array(%w[needs sentiment escalation pattern]) }
  end

  describe 'scopes' do
    let!(:needs_analysis) { create(:analysis, analysis_type: 'needs') }
    let!(:sentiment_analysis) { create(:analysis, analysis_type: 'sentiment') }
    let!(:high_priority) { create(:analysis, priority_level: 'high') }
    let!(:low_priority) { create(:analysis, priority_level: 'low') }

    describe '.by_type' do
      it 'filters by analysis type' do
        expect(described_class.by_type('needs')).to include(needs_analysis)
        expect(described_class.by_type('needs')).not_to include(sentiment_analysis)
      end
    end

    describe '.high_priority' do
      it 'returns only high priority analyses' do
        expect(described_class.high_priority).to include(high_priority)
        expect(described_class.high_priority).not_to include(low_priority)
      end
    end

    describe '.recent' do
      it 'orders by created_at desc' do
        described_class.delete_all # 既存のデータをクリア
        old_analysis = create(:analysis, created_at: 2.days.ago)
        new_analysis = create(:analysis, created_at: 1.hour.ago)

        expect(described_class.recent.to_a).to eq([new_analysis, old_analysis])
      end
    end

    describe '.needs_escalation' do
      let!(:escalated_analysis) { create(:analysis, escalated: true) }
      let!(:not_escalated_analysis) { create(:analysis, escalated: false, priority_level: 'high') }

      it 'returns high priority not yet escalated' do
        expect(described_class.needs_escalation).to include(not_escalated_analysis)
        expect(described_class.needs_escalation).not_to include(escalated_analysis)
      end
    end
  end

  describe '#hidden_needs' do
    let(:analysis) do
      create(:analysis, analysis_data: {
               'hidden_needs' => [
                 { 'need_type' => 'efficiency', 'confidence' => 0.9 },
                 { 'need_type' => 'cost_optimization', 'confidence' => 0.7 }
               ]
             })
    end

    it 'returns array of hidden needs from data' do
      expect(analysis.hidden_needs_from_data).to be_an(Array)
      expect(analysis.hidden_needs_from_data.size).to eq(2)
      expect(analysis.hidden_needs_from_data.first['need_type']).to eq('efficiency')
    end
  end

  describe '#sentiment_score' do
    let(:analysis) do
      create(:analysis, analysis_data: {
               'sentiment' => { 'score' => 0.8, 'label' => 'positive' }
             })
    end

    it 'returns sentiment score' do
      expect(analysis.sentiment_score).to eq(0.8)
    end

    context 'when sentiment data is missing' do
      let(:analysis) { create(:analysis, analysis_data: { 'content' => 'test' }) }

      it 'returns nil' do
        expect(analysis.sentiment_score).to be_nil
      end
    end
  end

  describe '#requires_escalation?' do
    context 'when priority is high and not escalated' do
      let(:analysis) { build(:analysis, priority_level: 'high', escalated: false) }

      it 'returns true' do
        expect(analysis.requires_escalation?).to be true
      end
    end

    context 'when priority is high but already escalated' do
      let(:analysis) { build(:analysis, priority_level: 'high', escalated: true) }

      it 'returns false' do
        expect(analysis.requires_escalation?).to be false
      end
    end

    context 'when sentiment is frustrated' do
      let(:analysis) do
        build(:analysis,
              sentiment: 'frustrated',
              escalated: false)
      end

      it 'returns true' do
        expect(analysis.requires_escalation?).to be true
      end
    end
  end

  describe '#escalate!' do
    let(:analysis) { create(:analysis, escalated: false) }

    it 'marks as escalated' do
      expect do
        analysis.escalate!
      end.to change(analysis, :escalated).from(false).to(true)
    end

    it 'sets escalated_at timestamp' do
      expect do
        analysis.escalate!
      end.to change(analysis, :escalated_at).from(nil)
    end

    # TODO: EscalationNotificationJobを実装後に有効化
    # it 'creates escalation notification' do
    #   expect {
    #     analysis.escalate!
    #   }.to have_enqueued_job(EscalationNotificationJob)
    # end
  end
end
