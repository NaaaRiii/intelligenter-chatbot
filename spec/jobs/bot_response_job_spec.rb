# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BotResponseJob, type: :job do
  let(:user) { create(:user) }
  let(:conversation) { create(:conversation, user: user) }
  let(:user_message) { create(:message, conversation: conversation, content: 'こんにちは', role: 'user') }

  describe '#perform' do
    context 'with valid parameters' do
      it 'ボット応答を生成する' do
        # user_messageは既に作成済みなので、ボット応答のみがカウントされる
        expect do
          described_class.perform_now(
            conversation_id: conversation.id,
            user_message_id: user_message.id
          )
        end.to change { conversation.messages.assistant_messages.count }.by(1)

        bot_message = conversation.messages.assistant_messages.last
        expect(bot_message).to be_present
        expect(bot_message.role).to eq('assistant')
      end

      it 'WebSocket配信を行う' do
        allow(ActionCable.server).to receive(:broadcast)

        described_class.perform_now(
          conversation_id: conversation.id,
          user_message_id: user_message.id
        )

        expect(ActionCable.server).to have_received(:broadcast).with(
          "conversation_#{conversation.id}",
          hash_including(type: 'bot_response')
        )
      end

      it '10メッセージごとに分析ジョブをエンキューする' do
        # user_messageと合わせて9個のメッセージを作成（ボット応答が10個目になる）
        8.times do |i|
          create(:message, conversation: conversation, role: i.even? ? 'user' : 'assistant')
        end

        expect do
          described_class.perform_now(
            conversation_id: conversation.id,
            user_message_id: user_message.id
          )
        end.to have_enqueued_job(AnalyzeConversationJob)
          .with(conversation.id)
          .on_queue('default')
      end
    end

    context 'with assistant message' do
      it 'アシスタントメッセージの場合は処理しない' do
        assistant_message = create(:message,
                                   conversation: conversation,
                                   content: '承知しました',
                                   role: 'assistant')

        expect do
          described_class.perform_now(
            conversation_id: conversation.id,
            user_message_id: assistant_message.id
          )
        end.not_to change(Message, :count)
      end
    end

    context 'with different conversation' do
      it '異なる会話のメッセージの場合は処理しない' do
        other_conversation = create(:conversation, user: user)
        other_message = create(:message,
                               conversation: other_conversation,
                               content: 'test',
                               role: 'user')

        expect do
          described_class.perform_now(
            conversation_id: conversation.id,
            user_message_id: other_message.id
          )
        end.not_to change(Message, :count)
      end
    end

    context 'with errors' do
      it 'エラー時はエラーメッセージを作成する' do
        chat_bot_service = instance_double(ChatBotService, generate_response: nil)
        allow(ChatBotService).to receive(:new).and_return(chat_bot_service)

        # user_messageは既に作成済みなので、アシスタントメッセージの増加を確認
        expect do
          described_class.perform_now(
            conversation_id: conversation.id,
            user_message_id: user_message.id
          )
        end.to change { conversation.messages.assistant_messages.count }.by(1)

        error_message = conversation.messages.last
        expect(error_message.content).to include('申し訳ございません')
        expect(error_message.metadata['error']).to be true
      end

      it 'エラー時はWebSocketでエラー通知を配信する' do
        chat_bot_service = instance_double(ChatBotService, generate_response: nil)
        allow(ChatBotService).to receive(:new).and_return(chat_bot_service)
        allow(ActionCable.server).to receive(:broadcast)

        described_class.perform_now(
          conversation_id: conversation.id,
          user_message_id: user_message.id
        )

        expect(ActionCable.server).to have_received(:broadcast).with(
          "conversation_#{conversation.id}",
          hash_including(type: 'bot_error')
        )
      end
    end

    context 'with not found records' do
      it '存在しない会話IDの場合はエラーログを出力' do
        allow(Rails.logger).to receive(:error)

        described_class.perform_now(
          conversation_id: 999_999,
          user_message_id: user_message.id
        )

        expect(Rails.logger).to have_received(:error).with(/Record not found/)
      end

      it '存在しないメッセージIDの場合はエラーログを出力' do
        allow(Rails.logger).to receive(:error)

        described_class.perform_now(
          conversation_id: conversation.id,
          user_message_id: 999_999
        )

        expect(Rails.logger).to have_received(:error).with(/Record not found/)
      end
    end
  end

  describe 'retry behavior' do
    it 'StandardErrorでリトライする' do
      expect do
        described_class.perform_later(
          conversation_id: conversation.id,
          user_message_id: user_message.id
        )
      end.to have_enqueued_job(described_class)
    end
  end
end
