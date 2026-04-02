import { motion } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { soundManager } from '../utils/sound'
import type { AppId } from '../types'
import AppIcon from './AppIcon'

// Filled SVG icon components for iOS-style appearance
const PhoneIcon = () => (
  <svg width="28" height="28" viewBox="0 0 24 24" fill="white">
    <path d="M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 0 0-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99z"/>
  </svg>
)

const MessagesIcon = () => (
  <svg width="26" height="26" viewBox="0 0 24 24" fill="white">
    <path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 14H5.17L4 17.17V4h16v12z"/>
    <path d="M4 4h16v12H5.17L4 17.17z" opacity="0.7"/>
  </svg>
)

const CameraIcon = () => (
  <svg width="26" height="26" viewBox="0 0 24 24" fill="white">
    <path d="M12 15.2a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4z"/>
    <path d="M9 2 7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z"/>
  </svg>
)

const WalletIcon = () => (
  <svg width="26" height="26" viewBox="0 0 24 24" fill="white">
    <path d="M21 7H3V4c0-.55.45-1 1-1h16c.55 0 1 .45 1 1v3zm0 3H3v7c0 .55.45 1 1 1h16c.55 0 1-.45 1-1v-7zm-5 4c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1z"/>
  </svg>
)

const HeartIcon = () => (
  <svg width="26" height="26" viewBox="0 0 24 24" fill="white">
    <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
  </svg>
)

const BriefcaseIcon = () => (
  <svg width="26" height="26" viewBox="0 0 24 24" fill="white">
    <path d="M20 7h-4V5c0-1.1-.9-2-2-2h-4c-1.1 0-2 .9-2 2v2H4c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zM10 5h4v2h-4V5z"/>
  </svg>
)

const GalleryIcon = () => (
  <svg width="26" height="26" viewBox="0 0 24 24" fill="white">
    <path d="M22 16V4c0-1.1-.9-2-2-2H8c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2zm-11-4 2.03 2.71L16 11l4 5H8l3-4zM2 6v14c0 1.1.9 2 2 2h14v-2H4V6H2z"/>
  </svg>
)

const GearIcon = () => (
  <svg width="26" height="26" viewBox="0 0 24 24" fill="white">
    <path d="M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54a.48.48 0 0 0-.48-.41h-3.84a.48.48 0 0 0-.48.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96a.49.49 0 0 0-.59.22L2.74 8.87a.48.48 0 0 0 .12.61l2.03 1.58c-.05.3-.07.62-.07.94s.02.64.07.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.26.41.48.41h3.84c.24 0 .44-.17.48-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6A3.6 3.6 0 1 1 12 8.4a3.6 3.6 0 0 1 0 7.2z"/>
  </svg>
)

interface AppDef {
  id: AppId
  label: string
  icon: React.ReactNode
  gradient: string
  shadow?: string
  badge?: number
}

export default function HomeScreen() {
  const { navigate, messages, myNumber } = usePhoneStore()

  const unreadCount = messages.filter(m =>
    m.receiver_number === myNumber && !m.is_read
  ).length

  const apps: AppDef[] = [
    {
      id: 'dialer', label: 'Phone',
      icon: <PhoneIcon />,
      gradient: 'linear-gradient(135deg, #2CD058 0%, #1BA54A 100%)',
      shadow: 'rgba(44,208,88,0.3)',
    },
    {
      id: 'messages', label: 'Messages',
      icon: <MessagesIcon />,
      gradient: 'linear-gradient(135deg, #34C759 0%, #30B350 100%)',
      shadow: 'rgba(52,199,89,0.3)',
      badge: unreadCount,
    },
    {
      id: 'camera', label: 'Camera',
      icon: <CameraIcon />,
      gradient: 'linear-gradient(135deg, #1C1C1E 0%, #3A3A3C 100%)',
      shadow: 'rgba(60,60,60,0.3)',
    },
    {
      id: 'bank', label: 'Wallet',
      icon: <WalletIcon />,
      gradient: 'linear-gradient(135deg, #007AFF 0%, #0055D4 100%)',
      shadow: 'rgba(0,122,255,0.3)',
    },
    {
      id: 'social', label: 'SB Social',
      icon: <HeartIcon />,
      gradient: 'linear-gradient(135deg, #FF2D55 0%, #C2185B 50%, #9C27B0 100%)',
      shadow: 'rgba(255,45,85,0.3)',
    },
    {
      id: 'job', label: 'Job',
      icon: <BriefcaseIcon />,
      gradient: 'linear-gradient(135deg, #5856D6 0%, #3F3CC7 100%)',
      shadow: 'rgba(88,86,214,0.3)',
    },
    {
      id: 'gallery', label: 'Gallery',
      icon: <GalleryIcon />,
      gradient: 'linear-gradient(135deg, #FF9500 0%, #FF6B00 100%)',
      shadow: 'rgba(255,149,0,0.3)',
    },
    {
      id: 'settings', label: 'Settings',
      icon: <GearIcon />,
      gradient: 'linear-gradient(135deg, #8E8E93 0%, #636366 100%)',
      shadow: 'rgba(142,142,147,0.25)',
    },
  ]

  const dockApps: AppDef[] = [
    apps.find(a => a.id === 'dialer')!,
    apps.find(a => a.id === 'messages')!,
    apps.find(a => a.id === 'camera')!,
    apps.find(a => a.id === 'gallery')!,
  ]

  const handleTap = (id: AppId) => {
    soundManager.tap()
    navigate(id)
  }

  return (
    <div className="flex flex-col h-full px-6 pt-4">
      {/* App grid */}
      <div className="flex-1 grid grid-cols-4 gap-y-7 gap-x-4 content-start pt-2">
        {apps.map((app, i) => (
          <motion.button
            key={app.id}
            initial={{ scale: 0.8, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ delay: i * 0.04, type: 'spring', damping: 20 }}
            onClick={() => handleTap(app.id)}
            className="flex flex-col items-center gap-1.5 group"
          >
            <div className="relative transition-transform active:scale-90">
              <AppIcon gradient={app.gradient} icon={app.icon} shadow={app.shadow} />
              {app.badge != null && app.badge > 0 && (
                <div className="absolute -top-1.5 -right-1.5 min-w-[20px] h-[20px] rounded-full bg-phone-red flex items-center justify-center px-1 z-20">
                  <span className="text-white text-[11px] font-bold">{app.badge > 99 ? '99+' : app.badge}</span>
                </div>
              )}
            </div>
            <span className="text-white text-[10.5px] font-medium tracking-tight"
              style={{ textShadow: '0 1px 3px rgba(0,0,0,0.6)' }}
            >{app.label}</span>
          </motion.button>
        ))}
      </div>

      {/* Page dot */}
      <div className="flex justify-center py-1.5">
        <div className="w-[6px] h-[6px] rounded-full bg-white/50" />
      </div>

      {/* Dock */}
      <div className="mb-2">
        <div
          className="flex justify-around items-center h-[80px] rounded-[24px] mx-0 px-4"
          style={{
            background: 'linear-gradient(135deg, rgba(255,255,255,0.12) 0%, rgba(255,255,255,0.06) 100%)',
            border: '1px solid rgba(255,255,255,0.08)',
            boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.15), 0 2px 12px rgba(0,0,0,0.2)',
          }}
        >
          {dockApps.map(app => (
            <button
              key={`dock-${app.id}`}
              onClick={() => handleTap(app.id)}
              className="relative transition-transform active:scale-90"
            >
              <AppIcon gradient={app.gradient} icon={app.icon} size={54} shadow={app.shadow} />
              {app.badge != null && app.badge > 0 && (
                <div className="absolute -top-1 -right-1 min-w-[18px] h-[18px] rounded-full bg-phone-red flex items-center justify-center px-0.5 z-20">
                  <span className="text-white text-[10px] font-bold">{app.badge}</span>
                </div>
              )}
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
