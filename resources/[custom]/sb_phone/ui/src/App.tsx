import { useEffect } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { usePhoneStore } from './store/phoneStore'
import { onNuiMessage } from './utils/nui'
import { soundManager } from './utils/sound'
import PhoneFrame from './components/PhoneFrame'
import PeekOverlay from './components/PeekOverlay'
import type { IncomingCallData } from './types'

function CameraHelpOverlay() {
  const { cameraMode } = usePhoneStore()
  if (!cameraMode) return null

  const hints = [
    { key: 'ENTER', action: 'Take Photo' },
    { key: '↑', action: 'Flip Camera' },
    { key: 'E', action: 'Toggle Flash' },
    { key: '← →', action: 'Change Mode' },
    { key: 'ALT', action: 'Toggle Cursor' },
    { key: 'BACKSPACE', action: 'Close Camera' },
  ]

  return (
    <motion.div
      initial={{ opacity: 0, x: -10 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0 }}
      className="fixed top-4 left-4 z-[9999] pointer-events-none"
    >
      <div className="flex flex-col gap-[3px]">
        {hints.map(({ key, action }) => (
          <div key={key} className="flex items-center gap-2 text-[12px]">
            <span className="font-bold text-yellow-300 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">{key}</span>
            <span className="text-white/80 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">{action}</span>
          </div>
        ))}
      </div>
    </motion.div>
  )
}

export default function App() {
  const { isOpen, openPhone, closePhone, minimizePhone, setCallState, resetCallState, addMessage, setPeekMessage, setCameraMode, setCameraFlash, setCameraLandscape } = usePhoneStore()

  useEffect(() => {
    const unsubs = [
      onNuiMessage('open', (data: any) => {
        soundManager.init(data.config?.soundVolume ?? 0.3, data.config?.keyboardSounds !== false)
        openPhone(data.data, data.metadata, data.isOwner, data.myNumber, data.config ?? { soundVolume: 0.3, keyboardSounds: true })
      }),
      onNuiMessage('close', () => {
        closePhone()
      }),
      onNuiMessage('phoneMinimized', () => {
        minimizePhone()
      }),
      onNuiMessage('expandCallPeek', () => {
        const store = usePhoneStore.getState()
        store.setPeekCall(false)
        usePhoneStore.setState({ isOpen: true, isBooting: false, isLocked: false })
      }),
      onNuiMessage('incomingCall', (data: any) => {
        const d = data.data as IncomingCallData
        setCallState({
          status: 'incoming',
          callerName: d.callerName,
          callerNumber: d.callerNumber,
          callerSource: d.callerSource,
          initial: d.initial,
          ringtone: d.ringtone,
        })
      }),
      onNuiMessage('callRinging', () => {
        setCallState({ status: 'outgoing' })
      }),
      onNuiMessage('callConnected', (data: any) => {
        setCallState({ status: 'active', channel: data.data?.channel, startTime: Date.now() })
        soundManager.callConnect()
      }),
      onNuiMessage('callEnded', () => {
        resetCallState()
        soundManager.callEnd()
      }),
      onNuiMessage('callDeclined', () => {
        soundManager.stopLoop()
        soundManager.playBusy()
        resetCallState()
      }),
      onNuiMessage('callFailed', (data: any) => {
        soundManager.stopLoop()
        const reason = data?.data?.reason
        const startVoicemail = () => {
          setCallState({ status: 'active', voicemail: true, startTime: Date.now() })
          soundManager.playVoicemail(() => {
            resetCallState()
            soundManager.callEnd()
          })
        }
        if (reason === 'unavailable' || reason === 'offline' || reason === 'airplane') {
          startVoicemail()
        } else if (reason === 'busy') {
          soundManager.playBusy()
          resetCallState()
        } else if (reason === 'invalid') {
          soundManager.playInvalid()
          resetCallState()
        } else {
          startVoicemail()
        }
      }),
      onNuiMessage('newMessage', (data: any) => {
        const d = data.data || data
        soundManager.receive()
        addMessage({
          id: Date.now(),
          sender_number: d.senderNumber,
          receiver_number: '',
          message: d.message,
          is_read: 0,
          created_at: new Date().toISOString(),
        })
        const store = usePhoneStore.getState()
        if (!store.isOpen) {
          setPeekMessage({
            senderNumber: d.senderNumber,
            senderName: d.senderName || null,
            message: d.message,
            timestamp: Date.now(),
          })
        }
      }),
      onNuiMessage('messagesRead', () => {}),
      onNuiMessage('typingIndicator', () => {}),
      onNuiMessage('cameraMode', (data: any) => {
        setCameraMode(data.active === true)
      }),
      onNuiMessage('goHome', () => {
        usePhoneStore.getState().goHome()
      }),
      onNuiMessage('cameraCapturing', (data: any) => {
        usePhoneStore.setState({ cameraCapturing: data.capturing === true })
      }),
      onNuiMessage('camera:setZoom', (data: any) => {
        usePhoneStore.getState().setCameraZoom(data.zoom ?? 1.0)
      }),
      onNuiMessage('camera:setZoomLevels', (data: any) => {
        if (Array.isArray(data.levels)) {
          usePhoneStore.getState().setCameraZoomLevels(data.levels)
        }
      }),
      onNuiMessage('camera:looking', (data: any) => {
        usePhoneStore.getState().setCameraLooking(data.looking === true)
      }),
      onNuiMessage('camera:setFlash', (data: any) => {
        setCameraFlash(data.mode ?? 'off')
      }),
      onNuiMessage('camera:setLandscape', (data: any) => {
        setCameraLandscape(data.active === true)
      }),
      // Camera keyboard actions from Lua → forwarded to Camera.tsx via custom event
      onNuiMessage('camera:keyAction', (data: any) => {
        window.dispatchEvent(new CustomEvent('camera:keyAction', { detail: data }))
      }),
      onNuiMessage('camera:focus', (data: any) => {
        window.dispatchEvent(new CustomEvent('camera:focus', { detail: data }))
      }),
    ]

    return () => unsubs.forEach(fn => fn())
  }, [])

  return (
    <div className="w-screen h-screen pointer-events-none overflow-hidden">
      {/* Camera help text — top-left, outside phone */}
      <AnimatePresence>
        <CameraHelpOverlay />
      </AnimatePresence>

      {/* Peek overlay — phone peeking from bottom-right */}
      <PeekOverlay />

      {/* Phone — anchored bottom-right */}
      <AnimatePresence>
        {isOpen && <PhoneFrame />}
      </AnimatePresence>
    </div>
  )
}
