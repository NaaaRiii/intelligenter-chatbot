# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChatBotService, type: :service do
  let(:user) { create(:user) }
  let(:conversation) { create(:conversation, user: user) }
  let(:user_message) { create(:message, conversation: conversation, content: 'こんにちは', role: 'user') }

  describe '#initialize' do
    it '正しく初期化される' do
      service = described_class.new(
        conversation: conversation,
        user_message: user_message
      )

      expect(service.conversation).to eq(conversation)
      expect(service.user_message).to eq(user_message)
    end
  end

  describe '#generate_response' do
    context 'with valid parameters' do
      it 'ボット応答を生成する' do
        service = described_class.new(
          conversation: conversation,
          user_message: user_message
        )

        response = service.generate_response

        expect(response).to be_a(Message)
        expect(response.role).to eq('assistant')
        expect(response.conversation).to eq(conversation)
      end

      it 'メタデータに意図情報を含む' do
        service = described_class.new(
          conversation: conversation,
          user_message: user_message
        )

        response = service.generate_response

        expect(response.metadata).to include('intent')
        expect(response.metadata).to include('confidence')
        expect(response.metadata).to include('template_used')
      end

      it 'WebSocket配信を行う' do
        service = described_class.new(
          conversation: conversation,
          user_message: user_message
        )

        allow(ActionCable.server).to receive(:broadcast)

        service.generate_response

        expect(ActionCable.server).to have_received(:broadcast).with(
          "conversation_#{conversation.id}",
          hash_including(type: 'bot_response')
        )
      end
    end

    context 'with invalid parameters' do
      it '会話がnilの場合はnilを返す' do
        service = described_class.new(
          conversation: nil,
          user_message: user_message
        )

        expect(service.generate_response).to be_nil
        expect(service.errors[:conversation]).to include("can't be blank")
      end

      it 'メッセージがnilの場合はnilを返す' do
        service = described_class.new(
          conversation: conversation,
          user_message: nil
        )

        expect(service.generate_response).to be_nil
        expect(service.errors[:user_message]).to include("can't be blank")
      end
    end

    context 'with different intents' do
      it '挨拶メッセージに適切に応答する' do
        greeting_message = create(:message,
                                  conversation: conversation,
                                  content: 'おはようございます',
                                  role: 'user')

        service = described_class.new(
          conversation: conversation,
          user_message: greeting_message
        )

        response = service.generate_response
        expect(response.content).to include('お')
      end

      it '質問に適切に応答する' do
        question_message = create(:message,
                                  conversation: conversation,
                                  content: 'どうやって使いますか？',
                                  role: 'user')

        service = described_class.new(
          conversation: conversation,
          user_message: question_message
        )

        response = service.generate_response
        expect(response.metadata['intent']).to eq('question')
      end
    end
  end

  describe '#generate_response_async' do
    it '非同期ジョブをエンキューする' do
      service = described_class.new(
        conversation: conversation,
        user_message: user_message
      )

      expect do
        service.generate_response_async?
      end.to have_enqueued_job(BotResponseJob)
        .with(conversation_id: conversation.id, user_message_id: user_message.id)
    end

    it '無効なパラメータの場合はジョブをエンキューしない' do
      service = described_class.new(
        conversation: nil,
        user_message: user_message
      )

      expect { service.generate_response_async? }.not_to have_enqueued_job(BotResponseJob)
    end
  end
end
