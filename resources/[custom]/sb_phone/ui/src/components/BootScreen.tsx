import { useEffect } from 'react'
import { motion } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'

// Stylized phone outline SVG logo
const PhoneLogo = () => (
  <svg width="48" height="48" viewBox="0 0 48 48" fill="none">
    <rect x="10" y="2" width="28" height="44" rx="6" stroke="white" strokeWidth="2" />
    <rect x="19" y="40" width="10" height="1.5" rx="0.75" fill="white" opacity="0.4" />
    <circle cx="24" cy="6" r="1.5" fill="white" opacity="0.3" />
  </svg>
)

export default function BootScreen() {
  const { setBooting } = usePhoneStore()

  useEffect(() => {
    const t = setTimeout(() => setBooting(false), 1500)
    return () => clearTimeout(t)
  }, [])

  return (
    <div className="w-full h-full flex flex-col items-center justify-center relative"
      style={{
        background: 'radial-gradient(circle at 50% 45%, #111 0%, #000 70%)',
      }}
    >
      {/* Logo */}
      <motion.div
        initial={{ scale: 0.5, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ type: 'spring', damping: 15, stiffness: 200, delay: 0.2 }}
        className="flex flex-col items-center"
      >
        <PhoneLogo />
      </motion.div>

      {/* Thin progress bar */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.5 }}
        className="absolute bottom-24 w-32"
      >
        <div className="h-[2px] bg-white/10 rounded-full overflow-hidden">
          <motion.div
            initial={{ width: '0%' }}
            animate={{ width: '100%' }}
            transition={{ duration: 1.2, delay: 0.5, ease: 'easeInOut' }}
            className="h-full bg-white/60 rounded-full"
          />
        </div>
      </motion.div>
    </div>
  )
}
