import { useState, useEffect, useRef, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { nuiFetch } from '../utils/nui'
import { soundManager } from '../utils/sound'
import { createGameView } from '../utils/gameRender'
import { RotateCcw, X, Check, Image } from 'lucide-react'

type CameraMode = 'VIDEO' | 'PHOTO' | 'LANDSCAPE'
const MODES: CameraMode[] = ['VIDEO', 'PHOTO', 'LANDSCAPE']
const MODE_LABELS: Record<CameraMode, string> = { VIDEO: 'Video', PHOTO: 'Photo', LANDSCAPE: 'Landscape' }

export default function Camera() {
  const { gallery, setGallery, cameraFlash, setCameraFlash, cameraLandscape, setCameraLandscape } = usePhoneStore()
  const [selfie, setSelfie] = useState(false)
  const [capturing, setCapturing] = useState(false)
  const [flashAnim, setFlashAnim] = useState(false)
  const [captured, setCaptured] = useState<string | null>(null)
  const [shutterBounce, setShutterBounce] = useState(false)
  const [mode, setMode] = useState<CameraMode>('PHOTO')
  const [recording, setRecording] = useState(false)
  const [recordTime, setRecordTime] = useState(0)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const gameViewRef = useRef<ReturnType<typeof createGameView> | null>(null)
  const openedRef = useRef(false)
  const recordTimerRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const modeRef = useRef<CameraMode>('PHOTO')

  // Keep modeRef in sync
  useEffect(() => { modeRef.current = mode }, [mode])

  // Open camera + start game render to canvas
  useEffect(() => {
    if (openedRef.current) return
    openedRef.current = true
    nuiFetch('openCamera', { selfie: false })
    const timer = setTimeout(() => {
      if (canvasRef.current) {
        gameViewRef.current = createGameView(canvasRef.current)
      }
    }, 100)
    return () => {
      clearTimeout(timer)
      gameViewRef.current?.stop()
      gameViewRef.current = null
    }
  }, [])

  // Recording timer
  useEffect(() => {
    if (recording) {
      setRecordTime(0)
      recordTimerRef.current = setInterval(() => setRecordTime(t => t + 1), 1000)
    } else {
      if (recordTimerRef.current) { clearInterval(recordTimerRef.current); recordTimerRef.current = null }
      setRecordTime(0)
    }
    return () => { if (recordTimerRef.current) clearInterval(recordTimerRef.current) }
  }, [recording])

  // Listen for keyboard actions from Lua
  useEffect(() => {
    const handleKeyAction = (e: Event) => {
      const { key, selfie: isSelfie } = (e as CustomEvent).detail || {}
      if (key === 'takePhoto') handleShutterAction()
      if (key === 'flip') setSelfie(isSelfie === true)
      if (key === 'close') closeCamera()
      if (key === 'modeLeft') cycleMode(-1)
      if (key === 'modeRight') cycleMode(1)
    }
    window.addEventListener('camera:keyAction', handleKeyAction)
    return () => window.removeEventListener('camera:keyAction', handleKeyAction)
  }, [])

  const formatTime = (s: number) => {
    const m = Math.floor(s / 60)
    const sec = s % 60
    return `${m}:${sec.toString().padStart(2, '0')}`
  }

  const takePhoto = async () => {
    if (capturing) return
    setCapturing(true)
    setFlashAnim(true)
    setShutterBounce(true)
    soundManager.shutter()
    setTimeout(() => setFlashAnim(false), 150)
    setTimeout(() => setShutterBounce(false), 200)
    const res = await nuiFetch<{ success: boolean; url?: string }>('capturePhoto', { saveToGallery: true })
    setCapturing(false)
    if (res?.success && res.url) {
      setCaptured(res.url)
      const photos = await nuiFetch<any[]>('getGalleryPhotos')
      if (Array.isArray(photos)) setGallery(photos)
    }
  }

  const handleShutterAction = () => {
    const m = modeRef.current
    if (m === 'VIDEO') {
      if (!recording) {
        setRecording(true)
      } else {
        setRecording(false)
        takePhoto()
      }
    } else {
      takePhoto()
    }
  }

  const cycleMode = (dir: number) => {
    setMode(prev => {
      const idx = MODES.indexOf(prev)
      const next = MODES[(idx + dir + MODES.length) % MODES.length]
      if (recording && next !== 'VIDEO') setRecording(false)
      if (next === 'LANDSCAPE') {
        setCameraLandscape(true)
        nuiFetch('setCameraLandscape', { active: true })
      } else {
        setCameraLandscape(false)
        nuiFetch('setCameraLandscape', { active: false })
      }
      return next
    })
  }

  const handleModeClick = (newMode: CameraMode) => {
    if (recording && newMode !== 'VIDEO') setRecording(false)
    setMode(newMode)
    if (newMode === 'LANDSCAPE') {
      setCameraLandscape(true)
      nuiFetch('setCameraLandscape', { active: true })
    } else {
      setCameraLandscape(false)
      nuiFetch('setCameraLandscape', { active: false })
    }
  }

  const closeCamera = async () => {
    setRecording(false)
    gameViewRef.current?.stop()
    gameViewRef.current = null
    setCaptured(null)
    setCameraLandscape(false)
    usePhoneStore.getState().goHome()
    await nuiFetch('closeCamera')
  }

  return (
    <div className="flex flex-col h-full w-full relative bg-black">
      {/* Flash animation overlay */}
      <AnimatePresence>
        {flashAnim && (
          <motion.div initial={{ opacity: 1 }} animate={{ opacity: 0 }} transition={{ duration: 0.15 }}
            className="absolute inset-0 bg-white z-50 pointer-events-none" />
        )}
      </AnimatePresence>

      {/* Photo preview */}
      <AnimatePresence>
        {captured && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            className="absolute inset-0 bg-black z-40 flex flex-col">
            <img src={captured} alt="Captured" className="flex-1 object-cover" />
            <div className="absolute top-3 left-3 bg-black/60 rounded-lg px-2.5 py-1">
              <p className="text-green-400 text-[10px] font-medium">Saved to Gallery</p>
            </div>
            <div className="absolute bottom-4 left-0 right-0 flex justify-center gap-5">
              <button onClick={() => setCaptured(null)}
                className="w-11 h-11 rounded-full bg-white/20 flex items-center justify-center">
                <Check size={20} className="text-white" />
              </button>
              <button onClick={closeCamera}
                className="w-11 h-11 rounded-full bg-white/10 flex items-center justify-center">
                <X size={20} className="text-white/60" />
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Camera UI — minimal lb-phone style */}
      {!captured && (
        <>
          {/* Recording indicator — only visible during video recording */}
          <AnimatePresence>
            {recording && (
              <motion.div initial={{ opacity: 0, y: -5 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}
                className="absolute top-3 left-0 right-0 z-10 flex justify-center">
                <div className="flex items-center gap-1.5 bg-black/50 rounded-full px-2.5 py-1">
                  <div className="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse" />
                  <span className="text-red-400 text-[10px] font-medium tabular-nums">{formatTime(recordTime)}</span>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Viewfinder — CfxTexture WebGL canvas, clean with no overlays */}
          <motion.div
            animate={{ scale: shutterBounce ? 0.97 : 1 }}
            transition={{ type: 'spring', stiffness: 500, damping: 30 }}
            className="flex-1 relative overflow-hidden bg-black"
          >
            <canvas
              ref={canvasRef}
              width={window.innerWidth}
              height={window.innerHeight}
              className="absolute inset-0 w-full h-full"
              style={{
                objectFit: 'cover',
                ...(cameraLandscape ? {
                  transform: 'rotate(90deg) scale(1.8)',
                  transformOrigin: 'center center',
                } : {}),
              }}
            />
          </motion.div>

          {/* Mode selector */}
          <div className="flex items-center justify-center gap-4 py-1.5 bg-black/90 z-10">
            {MODES.map((m) => (
              <button key={m} onClick={() => handleModeClick(m)} className="flex flex-col items-center gap-0.5 px-1.5">
                <span className={`text-[10px] font-medium tracking-wide transition-colors ${
                  mode === m ? 'text-white' : 'text-white/30'
                }`}>{MODE_LABELS[m]}</span>
                {mode === m && (
                  <motion.div layoutId="modeIndicator"
                    className="w-1 h-1 rounded-full bg-[#007AFF]"
                    transition={{ type: 'spring', stiffness: 400, damping: 30 }} />
                )}
              </button>
            ))}
          </div>

          {/* Bottom controls */}
          <div className="flex items-center justify-center gap-6 px-4 py-3 bg-black z-10">
            {/* Gallery thumbnail */}
            <div className="w-9 h-9 rounded-[8px] bg-white/10 flex items-center justify-center overflow-hidden">
              {gallery.length > 0 ? (
                <img src={gallery[0].image_url} alt="" className="w-full h-full object-cover" />
              ) : (
                <Image size={14} className="text-white/30" />
              )}
            </div>

            {/* Shutter */}
            <button onClick={handleShutterAction} disabled={capturing}
              className={`w-16 h-16 rounded-full border-[3px] flex items-center justify-center ${
                mode === 'VIDEO' ? recording ? 'border-red-500' : 'border-red-500/60' : 'border-white/70'
              }`}>
              {mode === 'VIDEO' ? (
                <motion.div
                  animate={recording
                    ? { borderRadius: '6px', width: 22, height: 22 }
                    : { borderRadius: '24px', width: 48, height: 48 }}
                  transition={{ duration: 0.2 }}
                  className="bg-red-500"
                />
              ) : (
                <motion.div
                  animate={capturing ? { scale: 0.7 } : { scale: 1 }}
                  transition={{ duration: 0.1 }}
                  className="w-[48px] h-[48px] rounded-full bg-white"
                />
              )}
            </button>

            {/* Flip */}
            <div className="w-9 h-9 rounded-full bg-white/10 flex items-center justify-center">
              <RotateCcw size={15} className="text-white/60" />
            </div>
          </div>
        </>
      )}
    </div>
  )
}
