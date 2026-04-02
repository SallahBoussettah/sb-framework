import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { getWallpaperBackground } from '../data/wallpapers'
import StatusBar from './StatusBar'
import BootScreen from './BootScreen'
import LockScreen from './LockScreen'
import HomeScreen from './HomeScreen'
import AppView from './AppView'
import HomeIndicator from './HomeIndicator'

/*
 * Phone layout uses the original 380x800 design size internally so all
 * px-based app content stays proportional.  CSS zoom scales it down
 * to the target visual size WITHOUT blurriness (zoom re-rasterizes text
 * at the target size, unlike transform: scale which blurs).
 *
 *   targetHeight = min(520px, 78vh)
 *   zoom         = targetHeight / 800
 *
 * Positioned fixed bottom-right.
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

export default function PhoneFrame() {
  const { isBooting, isLocked, currentApp, settings, cameraMode, cameraCapturing, cameraLandscape } = usePhoneStore()
  const zoom = usePhoneZoom()

  // Camera mode: solid black bg (Camera.tsx renders its own content with game view canvas)
  const bg = cameraMode ? '#000' : getWallpaperBackground(settings.wallpaper)
  const isInApp = !isBooting && !isLocked && currentApp !== 'home'
  const isLandscape = cameraMode && cameraLandscape

  return (
    <motion.div
      initial={{ y: 40, opacity: 0 }}
      animate={{ y: 0, opacity: cameraCapturing ? 0 : 1 }}
      exit={{ y: 40, opacity: 0 }}
      transition={{ type: 'spring', damping: 25, stiffness: 300 }}
      className="fixed bottom-[1vh] right-[1.5vw] z-[9998] pointer-events-auto"
      style={{
        width: isLandscape ? DESIGN_H : DESIGN_W,
        height: isLandscape ? DESIGN_W : DESIGN_H,
        zoom,
      }}
    >
      {/* Inner rotation wrapper — rotates the entire phone when landscape */}
      <div
        className="absolute inset-0"
        style={isLandscape ? {
          width: DESIGN_W,
          height: DESIGN_H,
          transform: 'rotate(-90deg)',
          transformOrigin: '0 0',
          left: 0,
          top: DESIGN_W,
        } : {
          width: '100%',
          height: '100%',
        }}
      >
        {/* Phone bezel — multi-layer for premium depth */}
        {/* Outer edge highlight (titanium catch light) */}
        <div
          className="absolute inset-0 rounded-[56px]"
          style={{
            background: 'linear-gradient(180deg, #2a2a2a 0%, #1a1a1a 30%, #0d0d0d 70%, #1a1a1a 100%)',
            boxShadow: '0 0 30px rgba(0,0,0,0.8), 0 0 60px rgba(0,0,0,0.4)',
          }}
        />
        {/* Inner body */}
        <div
          className="absolute inset-[1px] rounded-[55px]"
          style={{
            background: '#0a0a0a',
            boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.05), inset 0 -1px 0 rgba(255,255,255,0.02)',
          }}
        />

        {/* Side buttons with highlight */}
        <div className="absolute -left-[3px] top-[140px] w-[3px] h-[32px] rounded-l"
          style={{ background: '#1a1a1a', borderTop: '1px solid #333' }} />
        <div className="absolute -left-[3px] top-[190px] w-[3px] h-[56px] rounded-l"
          style={{ background: '#1a1a1a', borderTop: '1px solid #333' }} />
        <div className="absolute -left-[3px] top-[260px] w-[3px] h-[56px] rounded-l"
          style={{ background: '#1a1a1a', borderTop: '1px solid #333' }} />
        <div className="absolute -right-[3px] top-[200px] w-[3px] h-[72px] rounded-r"
          style={{ background: '#1a1a1a', borderTop: '1px solid #333' }} />

        {/* Screen area with glass-to-bezel border */}
        <div
          className="absolute inset-[5px] rounded-[50px] overflow-hidden flex flex-col"
          style={{
            background: bg,
            boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.5)',
          }}
        >

          {/* Status bar — hidden during camera mode */}
          {!isBooting && !cameraMode && <StatusBar />}

          {/* Content */}
          <div className={`flex-1 relative overflow-hidden ${isInApp && !cameraMode ? 'bg-[#0e0e0f]' : ''}`}>
            {isBooting ? (
              <BootScreen />
            ) : isLocked ? (
              <LockScreen />
            ) : currentApp === 'home' ? (
              <HomeScreen />
            ) : (
              <AppView />
            )}
          </div>

          {/* Home indicator — hidden during camera mode */}
          {!isBooting && !isLocked && !cameraMode && <HomeIndicator />}
        </div>
      </div>
    </motion.div>
  )
}
