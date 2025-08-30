import { vi } from 'vitest';

// グローバルモックの設定
global.fetch = vi.fn();

// localStorage モック
const localStorageMock = {
  getItem: vi.fn(),
  setItem: vi.fn(),
  removeItem: vi.fn(),
  clear: vi.fn(),
};
global.localStorage = localStorageMock as any;

// console モック（必要に応じて）
global.console = {
  ...console,
  error: vi.fn(),
  warn: vi.fn(),
};