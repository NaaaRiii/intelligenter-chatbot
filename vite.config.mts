import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

export default defineConfig({
  plugins: [
    RubyPlugin(),
  ],
  esbuild: {
    jsx: 'automatic',
    jsxDev: false
  },
  optimizeDeps: {
    include: ['react', 'react-dom', 'react-dom/client']
  }
})
