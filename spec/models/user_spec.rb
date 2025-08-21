require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:conversations).dependent(:destroy) }
    it { is_expected.to have_many(:messages).through(:conversations) }
  end

  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to allow_value('user@example.com').for(:email) }
    it { is_expected.not_to allow_value('invalid-email').for(:email) }
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_user) { create(:user, last_active_at: 5.minutes.ago) }
      let!(:inactive_user) { create(:user, last_active_at: 2.days.ago) }

      it 'returns users active within last 24 hours' do
        expect(described_class.active).to include(active_user)
        expect(described_class.active).not_to include(inactive_user)
      end
    end

    describe '.with_conversations' do
      let!(:user_with_conversations) { create(:user) }
      let!(:user_without_conversations) { create(:user) }

      before do
        create(:conversation, user: user_with_conversations)
      end

      it 'returns users who have conversations' do
        expect(described_class.with_conversations).to include(user_with_conversations)
        expect(described_class.with_conversations).not_to include(user_without_conversations)
      end
    end
  end

  describe '#display_name' do
    context 'when name is present' do
      let(:user) { build(:user, name: 'John Doe', email: 'john@example.com') }

      it 'returns the name' do
        expect(user.display_name).to eq('John Doe')
      end
    end

    context 'when name is blank' do
      let(:user) { build(:user, name: nil, email: 'john@example.com') }

      it 'returns email username' do
        expect(user.display_name).to eq('john')
      end
    end
  end

  describe '#update_last_active!' do
    let(:user) { create(:user, last_active_at: 1.day.ago) }

    it 'updates last_active_at to current time' do
      expect do
        user.update_last_active!
      end.to(change(user, :last_active_at))
    end
  end

  describe '#conversation_count' do
    let(:user) { create(:user) }

    before do
      create_list(:conversation, 3, user: user)
    end

    it 'returns the number of conversations' do
      expect(user.conversation_count).to eq(3)
    end
  end

  describe '#average_sentiment_score' do
    let(:user) { create(:user) }
    let(:conversation1) { create(:conversation, user: user) }
    let(:conversation2) { create(:conversation, user: user) }

    before do
      create(:analysis,
             conversation: conversation1,
             analysis_data: { 'sentiment' => { 'score' => 0.8 } })
      create(:analysis,
             conversation: conversation2,
             analysis_data: { 'sentiment' => { 'score' => 0.6 } })
    end

    it 'returns average sentiment across all conversations' do
      expect(user.average_sentiment_score).to eq(0.7)
    end
  end
end
