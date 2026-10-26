import { defineConfig } from 'vitest/config'
import { svelte } from '@sveltejs/vite-plugin-svelte'

// The API runs on Laravel (php artisan serve, port 8000). The browser calls /api on its own
// address and Vite forwards it, so local development and `vite preview` need no CORS setting.
const proxy = { '/api': { target: process.env.PASAL_API_URL ?? 'http://localhost:8000', changeOrigin: true } }

export default defineConfig({
  plugins: [svelte()],
  server: { port: 5173, proxy },
  preview: { port: 5173, proxy },
  // Tests run Svelte as in a browser (mount needs the browser build of Svelte).
  resolve: process.env.VITEST ? { conditions: ['browser'] } : undefined,
  test: { environment: 'jsdom', include: ['src/**/*.test.ts'] },
})
