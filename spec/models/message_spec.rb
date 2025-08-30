require 'rails_helper'

RSpec.describe Message, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:conversation) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_inclusion_of(:role).in_array(%w[user assistant system company]) }
  end

  describe 'scopes' do
    let(:conversation) { create(:conversation) }
    let!(:user_message) { create(:message, conversation: conversation, role: 'user') }
    let!(:assistant_message) { create(:message, conversation: conversation, role: 'assistant') }
    let!(:system_message) { create(:message, conversation: conversation, role: 'system') }
    let!(:company_message) { create(:message, conversation: conversation, role: 'company') }

    describe '.user_messages' do
      it 'returns only user messages' do
        expect(described_class.user_messages).to include(user_message)
        expect(described_class.user_messages).not_to include(assistant_message, system_message, company_message)
      end
    end

    describe '.assistant_messages' do
      it 'returns only assistant messages' do
        expect(described_class.assistant_messages).to include(assistant_message)
        expect(described_class.assistant_messages).not_to include(user_message, system_message, company_message)
      end
    end

    describe '.by_role' do
      it 'returns messages with specified role' do
        expect(described_class.by_role('company')).to include(company_message)
        expect(described_class.by_role('company')).not_to include(user_message, assistant_message, system_message)
      end
    end

    describe '.chronological' do
      it 'orders messages by created_at asc' do
        described_class.delete_all # 既存のデータをクリア
        old_message = create(:message, created_at: 2.hours.ago)
        new_message = create(:message, created_at: 1.minute.ago)

        expect(described_class.chronological.to_a).to eq([old_message, new_message])
      end
    end
  end

  describe 'callbacks' do
    describe 'after_create' do
      let(:conversation) { create(:conversation) }
      let(:message) { build(:message, conversation: conversation) }

      it 'updates conversation updated_at' do
        expect do
          message.save
        end.to(change { conversation.reload.updated_at })
      end

      it 'broadcasts to ActionCable' do
        allow(ActionCable.server).to receive(:broadcast)
        message.save
        expect(ActionCable.server).to have_received(:broadcast).with(
          "conversation_#{conversation.id}",
          hash_including(:message)
        )
      end
    end
  end

  describe '#user?' do
    it 'returns true for user role' do
      message = build(:message, role: 'user')
      expect(message.user?).to be true
    end

    it 'returns false for other roles' do
      message = build(:message, role: 'assistant')
      expect(message.user?).to be false
    end
  end

  describe '#assistant?' do
    it 'returns true for assistant role' do
      message = build(:message, role: 'assistant')
      expect(message.assistant?).to be true
    end

    it 'returns false for other roles' do
      message = build(:message, role: 'user')
      expect(message.assistant?).to be false
    end
  end

  describe '#company?' do
    it 'returns true for company role' do
      message = build(:message, role: 'company')
      expect(message.company?).to be true
    end

    it 'returns false for other roles' do
      message = build(:message, role: 'user')
      expect(message.company?).to be false
    end
  end

  describe '#from_company?' do
    it 'returns true for company role' do
      message = build(:message, role: 'company')
      expect(message.from_company?).to be true
    end

    it 'returns false for other roles' do
      message = build(:message, role: 'assistant')
      expect(message.from_company?).to be false
    end
  end

  describe '#word_count' do
    it 'returns the number of words in content' do
      message = build(:message, content: 'This is a test message')
      expect(message.word_count).to eq(5)
    end

    it 'handles Japanese text' do
      message = build(:message, content: 'これはテストメッセージです')
      expect(message.word_count).to be_positive
    end
  end
end
