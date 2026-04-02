import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { nuiFetch } from '../utils/nui'
import { soundManager } from '../utils/sound'
import { Lock } from 'lucide-react'

// Face ID scan icon (rounded square corners morphing)
const FaceIdIcon = ({ state }: { state: 'scanning' | 'failed' }) => {
  if (state === 'failed') return <Lock size={24} className="text-white/50" />
  return (
    <svg width="32" height="32" viewBox="0 0 32 32" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round"
      className="animate-pulse"
    >
      {/* Corner brackets */}
      <path d="M4 10V6a2 2 0 0 1 2-2h4" />
      <path d="M22 4h4a2 2 0 0 1 2 2v4" />
      <path d="M28 22v4a2 2 0 0 1-2 2h-4" />
      <path d="M10 28H6a2 2 0 0 1-2-2v-4" />
      {/* Face features */}
      <path d="M11 12v2" strokeWidth="1.5" />
      <path d="M21 12v2" strokeWidth="1.5" />
      <path d="M16 16v2.5c0 .5-.5 1-1 1" strokeWidth="1.5" />
      <path d="M12 21c1.5 1.5 6.5 1.5 8 0" strokeWidth="1.5" />
    </svg>
  )
}

// Up arrow for "swipe to unlock"
const UpArrow = () => (
  <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <path d="M5 8V2M2 4l3-2 3 2" />
  </svg>
)

export default function LockScreen() {
  const { setLocked, settings } = usePhoneStore()
  const [time, setTime] = useState(new Date())
  const [showPin, setShowPin] = useState(false)
  const [pin, setPin] = useState('')
  const [faceIdState, setFaceIdState] = useState<'idle' | 'scanning' | 'success' | 'failed'>('idle')

  useEffect(() => {
    const t = setInterval(() => setTime(new Date()), 1000)
    return () => clearInterval(t)
  }, [])

  useEffect(() => {
    // Start Face ID check
    if (settings.hasPasskey) {
      setShowPin(true)
    } else {
      // Try Face ID
      setFaceIdState('scanning')
      nuiFetch<{ success: boolean }>('checkFaceId').then(res => {
        if (res.success) {
          setFaceIdState('success')
          setTimeout(() => {
            soundManager.unlock()
            setLocked(false)
          }, 500)
        } else {
          setFaceIdState('failed')
          setTimeout(() => setShowPin(true), 500)
        }
      })
    }
  }, [])

  const handlePinKey = (key: string) => {
    soundManager.key()
    if (key === 'delete') {
      setPin(p => p.slice(0, -1))
    } else if (pin.length < 4) {
      const newPin = pin + key
      setPin(newPin)
      if (newPin.length === 4) {
        setTimeout(() => {
          nuiFetch<{ success: boolean }>('verifyPasskey', { pin: newPin }).then(res => {
            if (res.success) {
              soundManager.unlock()
              setLocked(false)
            } else {
              setPin('')
            }
          })
        }, 200)
      }
    }
  }

  const handleTapUnlock = () => {
    if (!settings.hasPasskey && faceIdState !== 'scanning') {
      soundManager.unlock()
      setLocked(false)
    }
  }

  // Format iOS 17 style date: "Thursday, February 6"
  const dateStr = time.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="w-full h-full flex flex-col items-center pt-16 relative"
      onClick={!showPin ? handleTapUnlock : undefined}
    >
      {!showPin ? (
        <>
          {/* Clock — iOS 17 style */}
          <motion.div
            initial={{ y: -20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ delay: 0.2 }}
            className="text-center"
          >
            <p className="text-white text-8xl font-extralight leading-none"
              style={{ letterSpacing: '-2px' }}
            >
              {time.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: false })}
            </p>
            <p className="text-white/80 text-[17px] font-light mt-3 tracking-wide">
              {dateStr}
            </p>
          </motion.div>

          {/* Face ID indicator */}
          <div className="flex-1" />
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.5 }}
            className="flex flex-col items-center gap-3 pb-8"
          >
            {(faceIdState === 'scanning' || faceIdState === 'failed') && (
              <FaceIdIcon state={faceIdState} />
            )}
            <div className="flex items-center gap-1.5 text-white/40">
              <UpArrow />
              <p className="text-[12px] font-light">Tap to unlock</p>
            </div>
          </motion.div>
        </>
      ) : (
        /* PIN Entry */
        <div className="flex flex-col items-center gap-6 pt-8">
          <Lock size={28} className="text-white/70" />
          <p className="text-white text-sm">Enter Passcode</p>

          {/* PIN dots */}
          <div className="flex gap-4">
            {[0, 1, 2, 3].map(i => (
              <div key={i} className={`w-3.5 h-3.5 rounded-full border-2 transition-all duration-200 ${
                i < pin.length ? 'bg-white border-white' : 'border-white/40'
              }`} />
            ))}
          </div>

          {/* Keypad — slightly larger buttons */}
          <div className="grid grid-cols-3 gap-4 mt-4">
            {['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'delete'].map(key => (
              <button
                key={key}
                onClick={() => key && handlePinKey(key)}
                disabled={!key}
                className={`w-[76px] h-[76px] rounded-full flex items-center justify-center text-white transition-all duration-100 ${
                  key ? 'bg-white/10 active:bg-white/25' : ''
                } ${key === 'delete' ? 'text-base' : 'text-[26px] font-light'}`}
              >
                {key === 'delete' ? (
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
                    <path d="M18 6L6 18M6 6l12 12"/>
                  </svg>
                ) : key}
              </button>
            ))}
          </div>
        </div>
      )}
    </motion.div>
  )
}
