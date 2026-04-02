import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { nuiFetch } from '../utils/nui'
import { formatTime, formatCallDuration } from '../utils/time'
import { Phone, PhoneOff, MessageSquare, Plane } from 'lucide-react'
import { getWallpaperBackground } from '../data/wallpapers'

/*
 * PeekOverlay — Shows the top portion of the phone (same 380px design width
 * as PhoneFrame) when the phone is closed but a notification or active call
 * is happening.  Uses the same CSS zoom so it matches the full phone size.
 *
 * Behaviour:
 *   Incoming call  → Accept / Decline buttons.  Accept keeps peek, gives game control.
 *   Active call    → Docked peek showing call info.  Tap or Arrow Up → expand.
 *   Outgoing call  → Compact "Calling..." peek.
 *   New message    → Auto-dismiss after 5s.
 */

const DESIGN_W = 380
const DESIGN_H = 800
const TARGET_MAX_H = 640

function usePhoneZoom() {
  const [zoom, setZoom] = useState(() =>
    Math.min(TARGET_MAX_H, window.innerHeight * 0.78) / DESIGN_H
  )

  useEffect(() => {
    const update = () => setZoom(Math.min(TARGET_MAX_H, window.innerHeight * 0.78) / DESIGN_H)
    window.addEventListener('resize', update)
    return () => window.removeEventListener('resize', update)
  }, [])

  return zoom
}

export default function PeekOverlay() {
  const { isOpen, callState, peekCall, peekMessage, settings, resetCallState, setCallState, setPeekMessage } = usePhoneStore()
  const [callTimer, setCallTimer] = useState(0)
  const [time, setTime] = useState(new Date())
  const zoom = usePhoneZoom()

  useEffect(() => {
    const t = setInterval(() => setTime(new Date()), 10000)
    return () => clearInterval(t)
  }, [])

  useEffect(() => {
    if (!peekCall || callState.status !== 'active') { setCallTimer(0); return }
    const t = setInterval(() => setCallTimer(s => s + 1), 1000)
    return () => clearInterval(t)
  }, [peekCall, callState.status])

  useEffect(() => {
    if (!peekMessage) return
    const t = setTimeout(() => setPeekMessage(null), 5000)
    return () => clearTimeout(t)
  }, [peekMessage])

  if (isOpen) return null

  const showIncomingCall = callState.status === 'incoming'
  const showActiveCall = peekCall && callState.status === 'active'
  const showOutgoingCall = callState.status === 'outgoing'
  const hasContent = showIncomingCall || showActiveCall || showOutgoingCall || !!peekMessage

  const handleAcceptCall = () => {
    nuiFetch('acceptCall', { callerSource: callState.callerSource })
    setCallState({ status: 'active', startTime: Date.now() })
  }

  const handleDeclineCall = () => {
    nuiFetch('declineCall', { callerSource: callState.callerSource })
    resetCallState()
  }

  const handleEndCall = () => {
    nuiFetch('endCall')
    resetCallState()
  }

  const handleExpandCall = () => {
    nuiFetch('phoneExpanded')
    usePhoneStore.getState().setPeekCall(false)
  }

  const bg = getWallpaperBackground(settings.wallpaper)

  return (
    <AnimatePresence>
      {hasContent && (
        <motion.div
          key="peek-phone"
          initial={{ y: '100%' }}
          animate={{ y: 0 }}
          exit={{ y: '100%' }}
          transition={{ type: 'spring', damping: 30, stiffness: 300 }}
          className="fixed bottom-0 right-[1.5vw] z-[9999] pointer-events-auto"
          style={{
            width: DESIGN_W,
            zoom,
          }}
        >
          {/* === PHONE BEZEL — matches PhoneFrame multi-layer === */}
          <div
            className="relative border-b-0"
            style={{
              borderRadius: '56px 56px 0 0',
              background: 'linear-gradient(180deg, #2a2a2a 0%, #1a1a1a 30%, #0d0d0d 70%, #1a1a1a 100%)',
              boxShadow: '0 0 30px rgba(0,0,0,0.8), 0 0 60px rgba(0,0,0,0.4)',
            }}
          >
            {/* Inner body */}
            <div
              className="absolute inset-[1px]"
              style={{
                borderRadius: '55px 55px 0 0',
                background: '#0a0a0a',
                boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.05)',
              }}
            />
            {/* Side buttons */}
            <div className="absolute -left-[3px] top-[17.5%] w-[3px] h-[8%] rounded-l"
              style={{ background: '#1a1a1a', borderTop: '1px solid #333' }} />
            <div className="absolute -left-[3px] top-[27%] w-[3px] h-[14%] rounded-l"
              style={{ background: '#1a1a1a', borderTop: '1px solid #333' }} />
            <div className="absolute -left-[3px] top-[43%] w-[3px] h-[14%] rounded-l"
              style={{ background: '#1a1a1a', borderTop: '1px solid #333' }} />
            <div className="absolute -right-[3px] top-[25%] w-[3px] h-[18%] rounded-r"
              style={{ background: '#1a1a1a', borderTop: '1px solid #333' }} />

            {/* === SCREEN AREA === */}
            <div
              className="overflow-hidden flex flex-col"
              style={{ margin: '5px 5px 0 5px', borderRadius: '50px 50px 0 0', background: bg }}
            >
              {/* Status bar */}
              <div className="relative z-50">
                <div className="flex items-center justify-between px-7 pt-[14px] min-h-[48px]">
                  <span className="text-white text-[14px] font-semibold w-16">
                    {formatTime(time)}
                  </span>

                  <div className="flex justify-center">
                    <div
                      className="bg-black rounded-full flex items-center justify-center relative"
                      style={{ width: 120, height: 34 }}
                    >
                      <div className="absolute left-4 flex items-center justify-center">
                        <div className="w-[12px] h-[12px] rounded-full border border-[#333] flex items-center justify-center">
                          <div className="w-[7px] h-[7px] rounded-full bg-[#1a1a2e]">
                            <div className="w-[3px] h-[3px] rounded-full bg-[#2a2a4e] mt-[1px] ml-[1px]" />
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-[5px] w-16 justify-end">
                    {settings.airplaneMode ? (
                      <Plane size={14} className="text-phone-yellow" />
                    ) : (
                      <>
                        <svg width="15" height="12" viewBox="0 0 15 12" fill="white">
                          <rect x="0" y="9" width="3" height="3" rx="0.5" />
                          <rect x="4" y="6" width="3" height="6" rx="0.5" />
                          <rect x="8" y="3" width="3" height="9" rx="0.5" />
                          <rect x="12" y="0" width="3" height="12" rx="0.5" />
                        </svg>
                        <svg width="14" height="12" viewBox="0 0 16 12" fill="white">
                          <path d="M8 10.5a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3z"/>
                          <path d="M4.93 8.36a4.37 4.37 0 0 1 6.14 0" stroke="white" strokeWidth="1.6" strokeLinecap="round" fill="none"/>
                          <path d="M2.1 5.53a8.07 8.07 0 0 1 11.8 0" stroke="white" strokeWidth="1.6" strokeLinecap="round" fill="none"/>
                        </svg>
                      </>
                    )}
                    <svg width="22" height="11" viewBox="0 0 25 12" fill="none">
                      <rect x="0.5" y="0.5" width="21" height="11" rx="2.5" stroke="white" strokeWidth="1"/>
                      <rect x="2" y="2" width="16" height="8" rx="1" fill="#30d158"/>
                      <path d="M23 4v4a2 2 0 0 0 0-4z" fill="white" opacity="0.5"/>
                    </svg>
                  </div>
                </div>

                <div className="h-[6px]" />
              </div>

              {/* === Notification content === */}

              {/* Incoming call */}
              {showIncomingCall && (
                <div className="px-4 pb-5">
                  <div className="flex items-center gap-2.5 mb-3">
                    <div className="w-11 h-11 rounded-full bg-phone-accent flex items-center justify-center text-white font-bold text-lg shrink-0">
                      {callState.initial || '?'}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-white text-[13px] font-semibold truncate">{callState.callerName}</p>
                      <p className="text-white/50 text-[11px]">Incoming Call...</p>
                    </div>
                  </div>
                  <div className="flex gap-2">
                    <button
                      onClick={handleDeclineCall}
                      className="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-xl bg-phone-red/90 active:bg-phone-red"
                    >
                      <PhoneOff size={14} className="text-white" />
                      <span className="text-white text-[11px] font-semibold">Decline</span>
                    </button>
                    <button
                      onClick={handleAcceptCall}
                      className="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-xl bg-phone-green/90 active:bg-phone-green"
                    >
                      <Phone size={14} className="text-white" />
                      <span className="text-white text-[11px] font-semibold">Accept</span>
                    </button>
                  </div>
                </div>
              )}

              {/* Outgoing call */}
              {showOutgoingCall && (
                <div className="px-4 pb-4">
                  <div className="flex items-center gap-2 py-1">
                    <Phone size={14} className="text-phone-green animate-pulse shrink-0" />
                    <div className="flex-1 min-w-0">
                      <p className="text-white text-xs font-medium truncate">Calling...</p>
                      <p className="text-white/50 text-[10px] truncate">{callState.callerName || callState.callerNumber}</p>
                    </div>
                  </div>
                </div>
              )}

              {/* Active call — docked peek */}
              {showActiveCall && (
                <div className="px-4 pb-4 cursor-pointer" onClick={handleExpandCall}>
                  <div className="flex items-center gap-2.5">
                    <div className="flex items-center gap-[3px]">
                      <div className="w-[3px] h-3 bg-phone-green rounded-full animate-pulse" />
                      <div className="w-[3px] h-4 bg-phone-green/80 rounded-full animate-pulse" style={{ animationDelay: '0.15s' }} />
                      <div className="w-[3px] h-2.5 bg-phone-green/60 rounded-full animate-pulse" style={{ animationDelay: '0.3s' }} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-white text-xs font-medium truncate">{callState.callerName || 'On Call'}</p>
                      <p className="text-phone-green text-[10px]">{formatCallDuration(callTimer)}</p>
                    </div>
                    <button
                      onClick={(e) => { e.stopPropagation(); handleEndCall() }}
                      className="w-8 h-8 rounded-full bg-phone-red flex items-center justify-center shrink-0"
                    >
                      <PhoneOff size={13} className="text-white" />
                    </button>
                  </div>
                  <p className="text-white/30 text-[9px] mt-1.5 text-center">Arrow Up to expand</p>
                </div>
              )}

              {/* Message notification */}
              {peekMessage && !showIncomingCall && !showActiveCall && !showOutgoingCall && (
                <div className="px-4 pb-4 cursor-pointer" onClick={() => setPeekMessage(null)}>
                  <div className="flex items-start gap-2.5">
                    <div className="w-9 h-9 rounded-full bg-phone-green/20 flex items-center justify-center shrink-0 mt-0.5">
                      <MessageSquare size={15} className="text-phone-green" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-white text-xs font-semibold truncate">{peekMessage.senderName || peekMessage.senderNumber}</p>
                      <p className="text-white/60 text-[10px] line-clamp-2 mt-0.5 leading-relaxed">{peekMessage.message}</p>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
