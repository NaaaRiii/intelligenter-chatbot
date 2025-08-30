import { createConsumer, Consumer, Subscription } from '@rails/actioncable';

interface Message {
  id?: number;
  content: string;
  role: 'user' | 'assistant' | 'system' | 'company';
  created_at?: string;
  metadata?: Record<string, any>;
}

interface ConversationHandlers {
  onConnected?: () => void;
  onDisconnected?: () => void;
  onReceived?: (data: { message: Message }) => void;
}

class ActionCableService {
  private consumer: Consumer | null = null;
  private subscription: Subscription | null = null;

  connect() {
    if (!this.consumer) {
      this.consumer = createConsumer('ws://localhost:3000/cable');
    }
    return this.consumer;
  }

  subscribeToConversation(
    conversationId: string | null,
    handlers: ConversationHandlers
  ) {
    this.unsubscribe();

    if (!this.consumer) {
      this.connect();
    }

    this.subscription = this.consumer!.subscriptions.create(
      {
        channel: 'ConversationChannel',
        conversation_id: conversationId
      },
      {
        connected: () => {
          console.log('Connected to ConversationChannel');
          handlers.onConnected?.();
        },
        disconnected: () => {
          console.log('Disconnected from ConversationChannel');
          handlers.onDisconnected?.();
        },
        received: (data: { message: Message }) => {
          console.log('Received message:', data);
          handlers.onReceived?.(data);
        },
        sendMessage: function(message: Message) {
          this.perform('send_message', message);
        }
      }
    );

    return this.subscription;
  }

  sendMessage(message: Message) {
    if (this.subscription && 'sendMessage' in this.subscription) {
      (this.subscription as any).sendMessage(message);
    }
  }

  unsubscribe() {
    if (this.subscription) {
      this.subscription.unsubscribe();
      this.subscription = null;
    }
  }

  disconnect() {
    this.unsubscribe();
    if (this.consumer) {
      this.consumer.disconnect();
      this.consumer = null;
    }
  }
}

export default new ActionCableService();