/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        booking: {
          bg: {
            primary: '#0a0a0a',
            secondary: '#141414',
            tertiary: '#1a1a1a',
            hover: '#242424',
            elevated: '#2a2a2a',
          },
          accent: {
            DEFAULT: '#3b82f6',
            hover: '#60a5fa',
            dim: 'rgba(59, 130, 246, 0.15)',
            glow: 'rgba(59, 130, 246, 0.4)',
          },
          orange: {
            DEFAULT: '#ff6b35',
            hover: '#ff8555',
            dim: 'rgba(255, 107, 53, 0.15)',
          },
          success: {
            DEFAULT: '#22c55e',
            dim: 'rgba(34, 197, 94, 0.15)',
          },
          warning: {
            DEFAULT: '#f59e0b',
            dim: 'rgba(245, 158, 11, 0.15)',
          },
          danger: {
            DEFAULT: '#ef4444',
            dim: 'rgba(239, 68, 68, 0.15)',
          },
          border: {
            DEFAULT: '#2a2a2a',
            light: '#1a1a1a',
          },
          text: {
            primary: '#ffffff',
            secondary: '#888888',
            muted: '#555555',
          }
        }
      },
      fontFamily: {
        'sans': ['Quicksand', 'system-ui', 'sans-serif'],
        'display': ['Bebas Neue', 'sans-serif'],
        'body': ['Poppins', 'Quicksand', 'system-ui', 'sans-serif'],
      },
      animation: {
        'slide-in': 'slideIn 0.3s ease',
        'fade-in': 'fadeIn 0.2s ease',
      },
      keyframes: {
        slideIn: {
          '0%': { opacity: '0', transform: 'scale(0.95) translateY(20px)' },
          '100%': { opacity: '1', transform: 'scale(1) translateY(0)' },
        },
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
      },
    },
  },
  plugins: [],
}
