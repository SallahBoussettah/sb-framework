import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { nuiFetch } from '../utils/nui'
import { soundManager } from '../utils/sound'
import { formatPhoneNumber, formatCallDuration, timeAgo } from '../utils/time'
import AppHeader from '../components/AppHeader'
import {
  Phone, PhoneOff, PhoneMissed, PhoneIncoming, PhoneOutgoing,
  Delete, Mic, MicOff, Volume2, VolumeX, Grid3X3, Trash2
} from 'lucide-react'

type Tab = 'keypad' | 'recents'

export default function Dialer() {
  const { calls, setCalls, callState, setCallState, resetCallState, myNumber } = usePhoneStore()
  const [tab, setTab] = useState<Tab>('keypad')
  const [number, setNumber] = useState('')
  const [callTimer, setCallTimer] = useState(0)

  useEffect(() => {
    if (callState.status !== 'active') { setCallTimer(0); return }
    const t = setInterval(() => setCallTimer(s => s + 1), 1000)
    return () => clearInterval(t)
  }, [callState.status])

  const handleKey = (key: string) => {
    soundManager.key()
    if (number.length < 14) {
      setNumber(formatPhoneNumber(number.replace(/\D/g, '') + key))
    }
  }

  const handleDelete = () => {
    const digits = number.replace(/\D/g, '').slice(0, -1)
    setNumber(digits ? formatPhoneNumber(digits) : '')
  }

  const handleCall = () => {
    if (number.replace(/\D/g, '').length < 7) return
    nuiFetch('startCall', { number })
    setCallState({ status: 'outgoing', callerName: number, callerNumber: number })
  }

  const handleEndCall = () => {
    nuiFetch('endCall')
    resetCallState()
    soundManager.callEnd()
  }

  const handleMute = () => {
    const muted = !callState.muted
    nuiFetch('toggleCallMute', { muted })
    setCallState({ muted })
  }

  const handleSpeaker = () => {
    const speaker = !callState.speaker
    nuiFetch('toggleCallSpeaker', { speaker })
    setCallState({ speaker })
  }

  const clearHistory = () => {
    nuiFetch('clearCallHistory')
    setCalls([])
  }

  // Active call screen
  if (callState.status === 'active' || callState.status === 'outgoing') {
    return (
      <div className="flex flex-col h-full bg-[#0e0e0f] items-center pt-16 pb-8">
        <div className="w-20 h-20 rounded-full bg-phone-accent/20 flex items-center justify-center mb-4">
          <span className="text-phone-accent text-3xl font-bold">
            {(callState.callerName || '?')[0]?.toUpperCase()}
          </span>
        </div>
        <h2 className="text-white text-xl font-semibold">{callState.callerName || number}</h2>
        <p className="text-phone-muted text-sm mt-1">
          {callState.status === 'outgoing' ? 'Calling...' : formatCallDuration(callTimer)}
        </p>

        <div className="flex-1" />

        {/* Call controls */}
        <div className="grid grid-cols-3 gap-6 mb-8">
          <button onClick={handleMute} className={`flex flex-col items-center gap-2`}>
            <div className={`w-14 h-14 rounded-full flex items-center justify-center ${callState.muted ? 'bg-white' : 'bg-white/10'}`}>
              {callState.muted ? <MicOff size={24} className="text-black" /> : <Mic size={24} className="text-white" />}
            </div>
            <span className="text-white text-xs">Mute</span>
          </button>
          <button className="flex flex-col items-center gap-2">
            <div className="w-14 h-14 rounded-full bg-white/10 flex items-center justify-center">
              <Grid3X3 size={24} className="text-white" />
            </div>
            <span className="text-white text-xs">Keypad</span>
          </button>
          <button onClick={handleSpeaker} className="flex flex-col items-center gap-2">
            <div className={`w-14 h-14 rounded-full flex items-center justify-center ${callState.speaker ? 'bg-white' : 'bg-white/10'}`}>
              {callState.speaker ? <Volume2 size={24} className="text-black" /> : <VolumeX size={24} className="text-white" />}
            </div>
            <span className="text-white text-xs">Speaker</span>
          </button>
        </div>

        {/* End call */}
        <button onClick={handleEndCall} className="w-16 h-16 rounded-full bg-phone-red flex items-center justify-center">
          <PhoneOff size={28} className="text-white" />
        </button>
      </div>
    )
  }

  return (
    <div className="flex flex-col h-full bg-[#0e0e0f]">
      <AppHeader
        title="Phone"
        rightAction={
          tab === 'recents' && calls.length > 0 ? (
            <button onClick={clearHistory} className="text-phone-red text-sm">Clear</button>
          ) : undefined
        }
      />

      {/* Tabs */}
      <div className="flex mx-4 mb-3 bg-phone-card rounded-lg p-0.5">
        {(['keypad', 'recents'] as Tab[]).map(t => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`flex-1 py-2 rounded-md text-sm font-medium transition-all ${
              tab === t ? 'bg-phone-accent text-white' : 'text-phone-muted'
            }`}
          >
            {t === 'keypad' ? 'Keypad' : 'Recents'}
          </button>
        ))}
      </div>

      {tab === 'keypad' ? (
        <div className="flex flex-col items-center flex-1 justify-end pb-6">
          {/* Number display */}
          <div className="h-16 flex items-center px-8">
            <p className="text-white text-3xl font-light tracking-wide">{number || ''}</p>
          </div>

          {/* Keypad grid */}
          <div className="grid grid-cols-3 gap-3 mt-4">
            {['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'].map(key => (
              <button
                key={key}
                onClick={() => handleKey(key)}
                className="w-[72px] h-[72px] rounded-full bg-phone-card flex flex-col items-center justify-center text-white active:bg-phone-elevated transition-colors"
              >
                <span className="text-2xl font-light">{key}</span>
              </button>
            ))}
          </div>

          {/* Call / Delete buttons */}
          <div className="flex items-center gap-8 mt-4">
            <div className="w-16" />
            <button
              onClick={handleCall}
              disabled={number.replace(/\D/g, '').length < 7}
              className="w-16 h-16 rounded-full bg-phone-green flex items-center justify-center disabled:opacity-40 transition-opacity"
            >
              <Phone size={28} className="text-white" />
            </button>
            <button
              onClick={handleDelete}
              className={`w-16 h-16 flex items-center justify-center ${number ? 'opacity-100' : 'opacity-0'}`}
            >
              <Delete size={24} className="text-phone-muted" />
            </button>
          </div>
        </div>
      ) : (
        /* Recents */
        <div className="flex-1 overflow-y-auto px-4">
          {calls.length === 0 ? (
            <p className="text-phone-muted text-center mt-16 text-sm">No recent calls</p>
          ) : (
            calls.map(call => {
              const isOutgoing = call.type === 'outgoing'
              const isMissed = call.type === 'missed'
              const otherNumber = call.caller_number === myNumber ? call.receiver_number : call.caller_number

              return (
                <button
                  key={call.id}
                  onClick={() => { setNumber(otherNumber); setTab('keypad') }}
                  className="flex items-center gap-3 w-full py-3 border-b border-white/5"
                >
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center ${
                    isMissed ? 'bg-phone-red/20' : isOutgoing ? 'bg-phone-blue/20' : 'bg-phone-green/20'
                  }`}>
                    {isMissed ? <PhoneMissed size={14} className="text-phone-red" /> :
                     isOutgoing ? <PhoneOutgoing size={14} className="text-phone-blue" /> :
                     <PhoneIncoming size={14} className="text-phone-green" />}
                  </div>
                  <div className="flex-1 text-left">
                    <p className={`text-sm font-medium ${isMissed ? 'text-phone-red' : 'text-white'}`}>{otherNumber}</p>
                    <p className="text-phone-dim text-xs">{call.type} {call.duration > 0 ? `· ${formatCallDuration(call.duration)}` : ''}</p>
                  </div>
                  <span className="text-phone-dim text-xs">{timeAgo(call.created_at)}</span>
                </button>
              )
            })
          )}
        </div>
      )}
    </div>
  )
}
