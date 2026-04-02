import { useState } from 'react'
import { motion } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { nuiFetch } from '../utils/nui'
import { soundManager } from '../utils/sound'
import { wallpapers } from '../data/wallpapers'
import AppHeader from '../components/AppHeader'
import { Palette, Music, Plane, Lock, ChevronRight, Check } from 'lucide-react'

type Section = 'main' | 'wallpaper' | 'ringtone' | 'passkey'

export default function SettingsApp() {
  const { settings, setSettings, myNumber } = usePhoneStore()
  const [section, setSection] = useState<Section>('main')
  const [pin, setPin] = useState('')
  const [confirmPin, setConfirmPin] = useState('')
  const [pinStep, setPinStep] = useState<'enter' | 'confirm'>('enter')

  const ringtones = ['default', 'harp', 'apex', 'radar', 'sencha', 'silk', 'summit']

  const saveWallpaper = (id: string) => {
    soundManager.tap()
    setSettings({ ...settings, wallpaper: id })
    nuiFetch('saveSettings', { ...settings, wallpaper: id })
  }

  const saveRingtone = (id: string) => {
    soundManager.tap()
    setSettings({ ...settings, ringtone: id })
    nuiFetch('saveSettings', { ...settings, ringtone: id })
  }

  const toggleAirplane = () => {
    const enabled = !settings.airplaneMode
    setSettings({ ...settings, airplaneMode: enabled })
    nuiFetch('toggleAirplaneMode', { enabled })
    soundManager.tap()
  }

  const savePasskey = () => {
    if (pinStep === 'enter') {
      if (pin.length === 4) {
        setPinStep('confirm')
      }
      return
    }
    if (pin === confirmPin) {
      nuiFetch('setPasskey', { passkey: pin })
      setSettings({ ...settings, hasPasskey: true })
      soundManager.send()
      setSection('main')
      setPin('')
      setConfirmPin('')
      setPinStep('enter')
    }
  }

  const removePasskey = () => {
    nuiFetch('setPasskey', { passkey: null })
    setSettings({ ...settings, hasPasskey: false })
    soundManager.delete()
  }

  if (section === 'wallpaper') {
    return (
      <div className="flex flex-col h-full bg-[#0e0e0f]">
        <AppHeader title="Wallpaper" />
        <div className="flex-1 overflow-y-auto px-4">
          <div className="grid grid-cols-3 gap-2">
            {wallpapers.map(w => (
              <button
                key={w.id}
                onClick={() => saveWallpaper(w.id)}
                className={`relative rounded-xl overflow-hidden h-36 ${settings.wallpaper === w.id ? 'ring-2 ring-phone-accent' : ''}`}
              >
                <div className="w-full h-full" style={{ background: w.background }} />
                <div className="absolute bottom-0 left-0 right-0 bg-black/60 py-1.5 text-center">
                  <span className="text-white text-[10px] font-medium">{w.label}</span>
                </div>
                {settings.wallpaper === w.id && (
                  <div className="absolute top-1.5 right-1.5 w-5 h-5 rounded-full bg-phone-accent flex items-center justify-center">
                    <Check size={12} className="text-white" />
                  </div>
                )}
              </button>
            ))}
          </div>
        </div>
      </div>
    )
  }

  if (section === 'ringtone') {
    return (
      <div className="flex flex-col h-full bg-[#0e0e0f]">
        <AppHeader title="Ringtone" />
        <div className="px-4 bg-phone-card rounded-xl overflow-hidden divide-y divide-white/5 mx-4">
          {ringtones.map(r => (
            <button
              key={r}
              onClick={() => saveRingtone(r)}
              className="flex items-center justify-between w-full px-4 py-3.5"
            >
              <span className="text-white text-sm capitalize">{r}</span>
              {settings.ringtone === r && <Check size={18} className="text-phone-accent" />}
            </button>
          ))}
        </div>
      </div>
    )
  }

  if (section === 'passkey') {
    return (
      <div className="flex flex-col h-full bg-[#0e0e0f]">
        <AppHeader title="Passcode" />
        <div className="flex flex-col items-center pt-12 gap-6 px-4">
          <Lock size={32} className="text-phone-muted" />
          <p className="text-white text-sm">
            {pinStep === 'enter' ? 'Enter a 4-digit passcode' : 'Confirm your passcode'}
          </p>

          <div className="flex gap-4">
            {[0, 1, 2, 3].map(i => {
              const val = pinStep === 'enter' ? pin : confirmPin
              return (
                <div key={i} className={`w-3.5 h-3.5 rounded-full border-2 transition-all ${
                  i < val.length ? 'bg-white border-white' : 'border-white/40'
                }`} />
              )
            })}
          </div>

          <div className="grid grid-cols-3 gap-4 mt-2">
            {['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'].map(key => (
              <button
                key={key}
                disabled={!key}
                onClick={() => {
                  if (key === 'del') {
                    if (pinStep === 'enter') setPin(p => p.slice(0, -1))
                    else setConfirmPin(p => p.slice(0, -1))
                  } else if (pinStep === 'enter' && pin.length < 4) {
                    const newPin = pin + key
                    setPin(newPin)
                    if (newPin.length === 4) setTimeout(() => setPinStep('confirm'), 300)
                  } else if (pinStep === 'confirm' && confirmPin.length < 4) {
                    const newPin = confirmPin + key
                    setConfirmPin(newPin)
                    if (newPin.length === 4) {
                      setTimeout(() => {
                        if (pin === newPin) {
                          nuiFetch('setPasskey', { passkey: pin })
                          setSettings({ ...settings, hasPasskey: true })
                          soundManager.send()
                          setSection('main')
                        } else {
                          setConfirmPin('')
                        }
                      }, 300)
                    }
                  }
                  soundManager.key()
                }}
                className={`w-[64px] h-[64px] rounded-full flex items-center justify-center text-white text-xl font-light ${
                  key ? 'bg-white/10 active:bg-white/25' : ''
                }`}
              >
                {key === 'del' ? '⌫' : key}
              </button>
            ))}
          </div>
        </div>
      </div>
    )
  }

  // Get current wallpaper label
  const currentWp = wallpapers.find(w => w.id === settings.wallpaper)

  // Main settings
  return (
    <div className="flex flex-col h-full bg-[#0e0e0f]">
      <AppHeader title="Settings" />

      <div className="flex-1 overflow-y-auto px-4 space-y-3">
        {/* My number */}
        <div className="bg-phone-card rounded-xl px-4 py-3">
          <p className="text-phone-dim text-xs mb-1">My Number</p>
          <p className="text-white text-lg font-semibold">{myNumber}</p>
        </div>

        {/* Settings list */}
        <div className="bg-phone-card rounded-xl overflow-hidden divide-y divide-white/5">
          {/* Airplane mode */}
          <button onClick={toggleAirplane} className="flex items-center gap-3 w-full px-4 py-3.5">
            <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${settings.airplaneMode ? 'bg-phone-yellow' : 'bg-phone-card border border-white/10'}`}>
              <Plane size={16} className="text-white" />
            </div>
            <span className="text-white text-sm flex-1 text-left">Airplane Mode</span>
            <div className={`w-12 h-7 rounded-full transition-colors relative ${settings.airplaneMode ? 'bg-phone-green' : 'bg-phone-dim/40'}`}>
              <motion.div
                animate={{ x: settings.airplaneMode ? 20 : 2 }}
                className="absolute top-[3px] w-[22px] h-[22px] rounded-full bg-white shadow"
              />
            </div>
          </button>

          {/* Wallpaper */}
          <button onClick={() => setSection('wallpaper')} className="flex items-center gap-3 w-full px-4 py-3.5">
            <div className="w-8 h-8 rounded-lg bg-phone-blue flex items-center justify-center">
              <Palette size={16} className="text-white" />
            </div>
            <span className="text-white text-sm flex-1 text-left">Wallpaper</span>
            <span className="text-phone-dim text-sm mr-1">{currentWp?.label || 'Midnight'}</span>
            <ChevronRight size={16} className="text-phone-dim" />
          </button>

          {/* Ringtone */}
          <button onClick={() => setSection('ringtone')} className="flex items-center gap-3 w-full px-4 py-3.5">
            <div className="w-8 h-8 rounded-lg bg-phone-purple flex items-center justify-center">
              <Music size={16} className="text-white" />
            </div>
            <span className="text-white text-sm flex-1 text-left">Ringtone</span>
            <span className="text-phone-dim text-sm capitalize mr-1">{settings.ringtone}</span>
            <ChevronRight size={16} className="text-phone-dim" />
          </button>

          {/* Passcode */}
          <button onClick={() => settings.hasPasskey ? removePasskey() : setSection('passkey')} className="flex items-center gap-3 w-full px-4 py-3.5">
            <div className="w-8 h-8 rounded-lg bg-phone-green flex items-center justify-center">
              <Lock size={16} className="text-white" />
            </div>
            <span className="text-white text-sm flex-1 text-left">Passcode</span>
            <span className="text-phone-dim text-sm mr-1">{settings.hasPasskey ? 'Enabled' : 'Off'}</span>
            <ChevronRight size={16} className="text-phone-dim" />
          </button>
        </div>
      </div>
    </div>
  )
}
