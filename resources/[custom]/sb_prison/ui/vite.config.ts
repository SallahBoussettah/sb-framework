import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: '../html',
    emptyOutDir: true,
    rollupOptions: {
      output: {
        entryFileNames: 'script.js',
        chunkFileNames: 'chunks/[name].[hash].js',
        assetFileNames: (info) => {
          if (info.name?.endsWith('.css')) return 'style.css'
          return 'assets/[name].[hash].[ext]'
        }
      }
    }
  }
})
