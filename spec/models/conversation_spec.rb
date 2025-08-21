require 'rails_helper'

RSpec.describe Conversation, type: :model do
  describe 'associations' do
    it { should have_many(:messages).dependent(:destroy) }
    it { should have_many(:analyses).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:conversation) }
    
    # session_idは自動生成されるため、プレゼンスバリデーションのテストは削除
    it { should validate_uniqueness_of(:session_id) }
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_conversation) { create(:conversation, ended_at: nil) }
      let!(:ended_conversation) { create(:conversation, ended_at: 1.hour.ago) }

      it 'returns only active conversations' do
        expect(Conversation.active).to include(active_conversation)
        expect(Conversation.active).not_to include(ended_conversation)
      end
    end

    describe '.recent' do
      let!(:old_conversation) { create(:conversation, created_at: 2.days.ago) }
      let!(:new_conversation) { create(:conversation, created_at: 1.hour.ago) }

      it 'orders by created_at desc' do
        expect(Conversation.recent.first).to eq(new_conversation)
        expect(Conversation.recent.last).to eq(old_conversation)
      end
    end
  end

  describe '#active?' do
    context 'when ended_at is nil' do
      let(:conversation) { build(:conversation, ended_at: nil) }

      it 'returns true' do
        expect(conversation.active?).to be true
      end
    end

    context 'when ended_at is present' do
      let(:conversation) { build(:conversation, ended_at: Time.current) }

      it 'returns false' do
        expect(conversation.active?).to be false
      end
    end
  end

  describe '#duration' do
    let(:conversation) { create(:conversation, created_at: 2.hours.ago) }

    context 'when conversation is active' do
      it 'returns duration from creation to now' do
        expect(conversation.duration).to be_within(1).of(7200)
      end
    end

    context 'when conversation has ended' do
      before { conversation.update(ended_at: 30.minutes.ago) }

      it 'returns duration from creation to end' do
        expect(conversation.duration).to be_within(1).of(5400)
      end
    end
  end

  describe '#end_conversation!' do
    let(:conversation) { create(:conversation, ended_at: nil) }

    it 'sets ended_at to current time' do
      expect {
        conversation.end_conversation!
      }.to change { conversation.ended_at }.from(nil)
    end

    it 'returns true' do
      expect(conversation.end_conversation!).to be true
    end
  end
end