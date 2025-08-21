import { defineConfig } from 'vitest/config'
import { resolve } from 'path'

export default defineConfig({
  test: {
    globals: true,
    environment: 'happy-dom',
    setupFiles: ['./spec/frontend/setup.ts'],
    include: ['spec/frontend/**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'spec/',
        '*.config.*',
        'public/',
        'vendor/'
      ]
    }
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, './app/javascript'),
      '@/controllers': resolve(__dirname, './app/javascript/controllers'),
      '@/components': resolve(__dirname, './app/javascript/components'),
      '@/types': resolve(__dirname, './app/javascript/types')
    }
  }
})