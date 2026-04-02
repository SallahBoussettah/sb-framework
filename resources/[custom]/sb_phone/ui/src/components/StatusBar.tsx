import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { nuiFetch } from '../utils/nui'
import { formatTime, formatCallDuration } from '../utils/time'
import { Phone, PhoneOff, Plane } from 'lucide-react'

// iOS-style signal bars (4 ascending bars)
const SignalBars = () => (
  <svg width="15" height="12" viewBox="0 0 15 12" fill="white">
    <rect x="0" y="9" width="3" height="3" rx="0.5" />
    <rect x="4" y="6" width="3" height="6" rx="0.5" />
    <rect x="8" y="3" width="3" height="9" rx="0.5" />
    <rect x="12" y="0" width="3" height="12" rx="0.5" />
  </svg>
)

// iOS-style WiFi icon (rounded arcs)
const WifiIcon = () => (
  <svg width="14" height="12" viewBox="0 0 16 12" fill="white">
    <path d="M8 10.5a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3z"/>
    <path d="M4.93 8.36a4.37 4.37 0 0 1 6.14 0" stroke="white" strokeWidth="1.6" strokeLinecap="round" fill="none"/>
    <path d="M2.1 5.53a8.07 8.07 0 0 1 11.8 0" stroke="white" strokeWidth="1.6" strokeLinecap="round" fill="none"/>
  </svg>
)

// iOS-style battery (rounded rect with fill + nub)
const BatteryIcon = () => (
  <svg width="22" height="11" viewBox="0 0 25 12" fill="none">
    <rect x="0.5" y="0.5" width="21" height="11" rx="2.5" stroke="white" strokeWidth="1"/>
    <rect x="2" y="2" width="16" height="8" rx="1" fill="#30d158"/>
    <path d="M23 4v4a2 2 0 0 0 0-4z" fill="white" opacity="0.5"/>
  </svg>
)

export default function StatusBar() {
  const { settings, callState, setCallState, resetCallState, currentApp, isLocked } = usePhoneStore()
  const [time, setTime] = useState(new Date())
  const [callTimer, setCallTimer] = useState(0)

  useEffect(() => {
    const t = setInterval(() => setTime(new Date()), 10000)
    return () => clearInterval(t)
  }, [])

  useEffect(() => {
    if (callState.status !== 'active') { setCallTimer(0); return }
    const t = setInterval(() => setCallTimer(s => s + 1), 1000)
    return () => clearInterval(t)
  }, [callState.status])

  const handleAccept = () => {
    nuiFetch('acceptCall', { callerSource: callState.callerSource })
    setCallState({ status: 'active', startTime: Date.now() })
  }

  const handleDecline = () => {
    nuiFetch('declineCall', { callerSource: callState.callerSource })
    resetCallState()
  }

  const isExpanded = callState.status === 'incoming'
  const isCompact = callState.status === 'active'
  const isOutgoing = callState.status === 'outgoing'
  const isIdle = callState.status === 'idle'

  // Opaque background when inside an app (not home, not locked)
  const isInApp = !isLocked && currentApp !== 'home'

  return (
    <div className={`relative z-50 ${isInApp ? 'bg-[#0e0e0f]' : ''}`}>
      {/* Status bar row — time, island, icons all vertically centered to pill */}
      <div className="flex items-center justify-between px-7 pt-[14px] min-h-[48px]">
        {/* Left: time — vertically centered with the 34px pill */}
        <span className="text-white text-[14px] font-semibold w-16">
          {formatTime(time)}
        </span>

        {/* Center: Dynamic Island */}
        <div className="flex justify-center">
          <AnimatePresence mode="wait">
            {/* Default pill with camera dot */}
            {isIdle && (
              <motion.div
                key="pill"
                initial={false}
                animate={{ width: 120, height: 34 }}
                className="bg-black rounded-full flex items-center justify-center relative"
              >
                {/* Camera lens with concentric ring effect */}
                <div className="absolute left-4 flex items-center justify-center">
                  <div className="w-[12px] h-[12px] rounded-full border border-[#333] flex items-center justify-center">
                    <div className="w-[7px] h-[7px] rounded-full bg-[#1a1a2e]">
                      <div className="w-[3px] h-[3px] rounded-full bg-[#2a2a4e] mt-[1px] ml-[1px]" />
                    </div>
                  </div>
                </div>
              </motion.div>
            )}

            {/* Incoming call - expanded */}
            {isExpanded && (
              <motion.div
                key="incoming"
                initial={{ width: 120, height: 34 }}
                animate={{ width: 340, height: 76 }}
                exit={{ width: 120, height: 34 }}
                transition={{ type: 'spring', damping: 20, stiffness: 300 }}
                className="bg-black rounded-[26px] flex items-center px-3.5 gap-2.5"
              >
                <div className="w-11 h-11 rounded-full bg-phone-accent flex items-center justify-center text-white font-bold text-lg shrink-0">
                  {callState.initial || '?'}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-white text-[13px] font-semibold truncate">{callState.callerName}</p>
                  <p className="text-phone-muted text-[11px]">Incoming Call...</p>
                </div>
                <button onClick={handleDecline} className="w-9 h-9 rounded-full bg-phone-red flex items-center justify-center shrink-0">
                  <PhoneOff size={16} className="text-white" />
                </button>
                <button onClick={handleAccept} className="w-9 h-9 rounded-full bg-phone-green flex items-center justify-center shrink-0">
                  <Phone size={16} className="text-white" />
                </button>
              </motion.div>
            )}

            {/* Outgoing call */}
            {isOutgoing && (
              <motion.div
                key="outgoing"
                initial={{ width: 120, height: 34 }}
                animate={{ width: 200, height: 34 }}
                exit={{ width: 120, height: 34 }}
                transition={{ type: 'spring', damping: 20, stiffness: 300 }}
                className="bg-black rounded-full flex items-center px-4 gap-2"
              >
                <Phone size={13} className="text-phone-green animate-pulse" />
                <span className="text-white text-[12px] font-medium">Calling...</span>
              </motion.div>
            )}

            {/* Active call - compact */}
            {isCompact && (
              <motion.div
                key="active"
                initial={{ width: 120, height: 34 }}
                animate={{ width: 170, height: 34 }}
                exit={{ width: 120, height: 34 }}
                transition={{ type: 'spring', damping: 20, stiffness: 300 }}
                className="bg-gradient-to-r from-phone-green/80 to-phone-green/40 rounded-full flex items-center px-3.5 gap-2"
              >
                <div className="flex items-center gap-[3px]">
                  <div className="w-[3px] h-3 bg-white/80 rounded-full animate-pulse" />
                  <div className="w-[3px] h-4 bg-white/60 rounded-full animate-pulse" style={{ animationDelay: '0.15s' }} />
                  <div className="w-[3px] h-2.5 bg-white/70 rounded-full animate-pulse" style={{ animationDelay: '0.3s' }} />
                </div>
                <span className="text-white text-[12px] font-semibold">{formatCallDuration(callTimer)}</span>
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        {/* Right: iOS-style status icons */}
        <div className="flex items-center gap-[5px] w-16 justify-end">
          {settings.airplaneMode ? (
            <Plane size={14} className="text-phone-yellow" />
          ) : (
            <>
              <SignalBars />
              <WifiIcon />
            </>
          )}
          <BatteryIcon />
        </div>
      </div>

      {/* Small spacer below the status bar */}
      <div className="h-[6px]" />
    </div>
  )
}
