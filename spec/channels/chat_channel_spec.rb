require 'rails_helper'

RSpec.describe ChatChannel, type: :channel do
  let(:user) { create(:user) }
  let(:conversation) { create(:conversation, user: user) }

  before do
    stub_connection(current_user: user)
  end

  describe '#subscribed' do
    context 'with valid conversation_id' do
      it 'subscribes to a stream' do
        subscribe(conversation_id: conversation.id)

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("conversation_#{conversation.id}")
      end

      it 'broadcasts user connected message' do
        expect do
          subscribe(conversation_id: conversation.id)
        end.to have_broadcasted_to("conversation_#{conversation.id}")
          .with(hash_including(type: 'user_connected'))
      end
    end

    context 'with invalid conversation_id' do
      it 'rejects subscription' do
        subscribe(conversation_id: 999_999)
        expect(subscription).to be_rejected
      end
    end

    context 'without conversation_id' do
      it 'rejects subscription' do
        subscribe
        expect(subscription).to be_rejected
      end
    end

    context 'when user is not authorized' do
      let(:other_user) { create(:user) }
      let(:other_conversation) { create(:conversation, user: other_user) }

      it 'rejects subscription' do
        subscribe(conversation_id: other_conversation.id)
        expect(subscription).to be_rejected
      end
    end
  end

  describe '#unsubscribed' do
    before do
      subscribe(conversation_id: conversation.id)
    end

    it 'broadcasts user disconnected message' do
      expect do
        unsubscribe
      end.to have_broadcasted_to("conversation_#{conversation.id}")
        .with(hash_including(type: 'user_disconnected'))
    end

    it 'stops all streams' do
      expect(subscription).to have_stream_from("conversation_#{conversation.id}")
      unsubscribe
      expect(subscription.streams).to be_empty
    end
  end

  describe '#send_message' do
    before do
      subscribe(conversation_id: conversation.id)
    end

    context 'with valid message data' do
      let(:message_data) { { 'content' => 'Hello, World!' } }

      it 'creates a new message' do
        expect do
          perform :send_message, message_data
        end.to change(Message, :count).by(1)
      end

      it 'broadcasts the message' do
        expect do
          perform :send_message, message_data
        end.to have_broadcasted_to("conversation_#{conversation.id}")
          .with(hash_including(
                  type: 'new_message',
                  message: hash_including(content: 'Hello, World!')
                ))
      end

      it 'enqueues AI response job' do
        expect do
          perform :send_message, message_data
        end.to have_enqueued_job(ProcessAiResponseJob)
      end
    end

    context 'with invalid message data' do
      let(:invalid_data) { { 'content' => '' } }

      it 'does not create a message' do
        expect do
          perform :send_message, invalid_data
        end.not_to change(Message, :count)
      end

      it 'transmits error message' do
        perform :send_message, invalid_data

        expect(transmissions.last).to include(
          'type' => 'error',
          'message' => 'メッセージの送信に失敗しました'
        )
      end
    end
  end

  describe '#typing' do
    before do
      subscribe(conversation_id: conversation.id)
    end

    it 'broadcasts typing notification' do
      expect do
        perform :typing, { 'is_typing' => true }
      end.to have_broadcasted_to("conversation_#{conversation.id}")
        .with(hash_including(
                type: 'typing',
                is_typing: true
              ))
    end
  end

  describe '#mark_as_read' do
    let(:message) { create(:message, conversation: conversation) }

    before do
      subscribe(conversation_id: conversation.id)
    end

    it 'broadcasts read notification' do
      expect do
        perform :mark_as_read, { 'message_id' => message.id }
      end.to have_broadcasted_to("conversation_#{conversation.id}")
        .with(hash_including(
                type: 'message_read',
                message_id: message.id
              ))
    end

    it 'updates message metadata' do
      perform :mark_as_read, { 'message_id' => message.id }

      message.reload
      expect(message.metadata['read_by']).to eq(user.id)
      expect(message.metadata['read_at']).to be_present
    end
  end
end
