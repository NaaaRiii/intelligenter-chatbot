import { describe, it, expect, vi, beforeEach } from 'vitest';
import actionCableService from '../actionCable';

// @rails/actioncableをモック
vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({
    subscriptions: {
      create: vi.fn((params, handlers) => ({
        unsubscribe: vi.fn(),
        perform: vi.fn(),
        sendMessage: handlers.sendMessage
      }))
    },
    disconnect: vi.fn()
  }))
}));

describe('ActionCableService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('connect', () => {
    it('WebSocketコンシューマーを作成する', () => {
      const consumer = actionCableService.connect();
      expect(consumer).toBeDefined();
      expect(consumer.subscriptions).toBeDefined();
    });

    it('複数回呼び出しても同じコンシューマーを返す', () => {
      const consumer1 = actionCableService.connect();
      const consumer2 = actionCableService.connect();
      expect(consumer1).toBe(consumer2);
    });
  });

  describe('subscribeToConversation', () => {
    it('会話チャンネルにサブスクライブする', () => {
      const handlers = {
        onConnected: vi.fn(),
        onDisconnected: vi.fn(),
        onReceived: vi.fn()
      };

      const subscription = actionCableService.subscribeToConversation('test-123', handlers);
      
      expect(subscription).toBeDefined();
      expect(subscription.unsubscribe).toBeDefined();
    });

    it('conversationIdがnullでもサブスクライブできる', () => {
      const handlers = {
        onConnected: vi.fn(),
        onReceived: vi.fn()
      };

      const subscription = actionCableService.subscribeToConversation(null, handlers);
      expect(subscription).toBeDefined();
    });
  });

  describe('sendMessage', () => {
    it('メッセージを送信する', () => {
      const handlers = {
        onConnected: vi.fn(),
        onReceived: vi.fn()
      };

      actionCableService.subscribeToConversation('test-123', handlers);
      
      const message = {
        content: 'テストメッセージ',
        role: 'user' as const,
        metadata: { test: true }
      };

      // sendMessageを呼び出す
      actionCableService.sendMessage(message);
      
      // サブスクリプションが作成されていることを確認
      expect(actionCableService['subscription']).toBeDefined();
    });
  });

  describe('unsubscribe', () => {
    it('サブスクリプションを解除する', () => {
      const handlers = {
        onConnected: vi.fn(),
        onReceived: vi.fn()
      };

      const subscription = actionCableService.subscribeToConversation('test-123', handlers);
      const unsubscribeSpy = vi.spyOn(subscription, 'unsubscribe');
      
      actionCableService.unsubscribe();
      
      expect(unsubscribeSpy).toHaveBeenCalled();
      expect(actionCableService['subscription']).toBeNull();
    });
  });

  describe('disconnect', () => {
    it('接続を切断してコンシューマーをリセットする', () => {
      const consumer = actionCableService.connect();
      const disconnectSpy = vi.spyOn(consumer, 'disconnect');
      
      actionCableService.disconnect();
      
      expect(disconnectSpy).toHaveBeenCalled();
      expect(actionCableService['consumer']).toBeNull();
    });
  });
});