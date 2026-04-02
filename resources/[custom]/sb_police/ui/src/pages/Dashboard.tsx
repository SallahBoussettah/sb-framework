import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { useMDTStore } from '../store/mdtStore'
import { fetchNui } from '../utils/nui'
import type { PageId } from '../types'

interface TileConfig {
  id: PageId
  label: string
  icon: string
  badgeKey?: 'alerts'
}

const tiles: TileConfig[] = [
  { id: 'dispatch', label: 'Dispatch', icon: 'fa-tower-broadcast', badgeKey: 'alerts' },
  { id: 'citizens', label: 'Citizens', icon: 'fa-id-card' },
  { id: 'vehicles', label: 'Vehicles', icon: 'fa-car-side' },
  { id: 'reports', label: 'Reports', icon: 'fa-file-lines' },
  { id: 'penal-code', label: 'Criminal Code', icon: 'fa-scale-balanced' },
  { id: 'warrants', label: 'Warrants & BOLO', icon: 'fa-triangle-exclamation' },
  { id: 'officers', label: 'Officers', icon: 'fa-users-gear' },
  { id: 'clock', label: 'Time Clock', icon: 'fa-clock' },
  { id: 'cameras', label: 'Cameras', icon: 'fa-video' },
  { id: 'federal', label: 'Federal', icon: 'fa-lock' },
]

export default function Dashboard() {
  const { isOnDuty, setDutyStatus, shiftStartTime, setShiftStartTime, onDutyOfficers, alerts, setPage, officerData } = useMDTStore()
  const [shiftDuration, setShiftDuration] = useState('0h 0m')

  useEffect(() => {
    if (!isOnDuty || !shiftStartTime) {
      setShiftDuration('0h 0m')
      return
    }

    const interval = setInterval(() => {
      const diff = Math.floor((Date.now() - shiftStartTime) / 1000 / 60)
      const hours = Math.floor(diff / 60)
      const mins = diff % 60
      setShiftDuration(`${hours}h ${mins}m`)
    }, 1000)

    return () => clearInterval(interval)
  }, [isOnDuty, shiftStartTime])

  const handleToggleDuty = () => {
    const newStatus = !isOnDuty
    setDutyStatus(newStatus)

    if (newStatus) {
      setShiftStartTime(Date.now())
    } else {
      setShiftStartTime(null)
    }

    fetchNui('toggleDuty', { isOnDuty: newStatus })
  }

  const formatShiftStart = () => {
    if (!shiftStartTime) return '--:--'
    const date = new Date(shiftStartTime)
    return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false })
  }

  const getBadgeCount = (key?: string) => {
    if (key === 'alerts') return alerts.length
    return 0
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="absolute inset-0 p-8 overflow-y-auto"
    >
      {/* Title Section */}
      <div className="mb-8 text-center">
        <h2 className="font-heading text-3xl tracking-[0.2em] text-mdt-text-primary uppercase">
          LSPD Command Center
        </h2>
        <p className="text-sm text-mdt-text-muted mt-2">
          Welcome, {officerData?.rank || 'Officer'} {officerData?.name || ''}
        </p>
      </div>

      {/* Tile Grid — 5 columns, 2 rows */}
      <div className="grid grid-cols-5 gap-4 mb-8">
        {tiles.map((tile, index) => {
          const badge = getBadgeCount(tile.badgeKey)
          return (
            <motion.button
              key={tile.id}
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.04, ease: 'easeOut' }}
              onClick={() => setPage(tile.id)}
              className="tile-hover relative flex flex-col items-center justify-center gap-4 py-8 px-4 bg-white/[0.04] border border-white/[0.08] rounded-2xl cursor-pointer"
            >
              {badge > 0 && (
                <span className="absolute top-3 right-3 min-w-[22px] h-[22px] px-1.5 bg-mdt-danger rounded-full text-[11px] font-bold text-white flex items-center justify-center shadow-lg">
                  {badge}
                </span>
              )}
              <i className={`fa-solid ${tile.icon} text-3xl text-white/70 tile-icon`} />
              <span className="tile-title text-[13px] font-medium text-mdt-text-secondary text-center uppercase tracking-wide">
                {tile.label}
              </span>
            </motion.button>
          )
        })}
      </div>

      {/* Bottom Banners */}
      <div className="grid grid-cols-2 gap-5 items-start mb-6">
        {/* Duty Status Banner */}
        <div className="relative bg-white/[0.03] border border-white/[0.08] rounded-2xl overflow-hidden">
          {/* Background image */}
          <div
            className="absolute inset-0 opacity-[0.08] bg-cover bg-center pointer-events-none"
            style={{ backgroundImage: "url('img/webp/duty.webp')" }}
          />
          <div className="relative p-6">
            <div className="flex items-center justify-between mb-5">
              <div className="flex items-center gap-3">
                <div className={`w-3 h-3 rounded-full ${isOnDuty ? 'bg-mdt-success animate-pulse' : 'bg-mdt-danger'}`} />
                <span className="font-heading text-xl tracking-wider text-mdt-text-primary">
                  DUTY STATUS
                </span>
              </div>
              <button
                onClick={handleToggleDuty}
                className={`px-6 py-2.5 rounded-xl text-xs font-bold uppercase tracking-wider transition-all ${
                  isOnDuty
                    ? 'bg-mdt-danger/20 border border-mdt-danger/40 text-mdt-danger hover:bg-mdt-danger/30'
                    : 'bg-mdt-success/20 border border-mdt-success/40 text-mdt-success hover:bg-mdt-success/30'
                }`}
              >
                {isOnDuty ? 'Go Off Duty' : 'Go On Duty'}
              </button>
            </div>
            <div className="flex gap-10">
              <div>
                <span className="text-[10px] text-mdt-text-muted uppercase tracking-wider block mb-1">Shift Start</span>
                <p className="text-xl font-semibold text-mdt-text-primary">{formatShiftStart()}</p>
              </div>
              <div>
                <span className="text-[10px] text-mdt-text-muted uppercase tracking-wider block mb-1">Duration</span>
                <p className="text-xl font-semibold text-mdt-text-primary">{shiftDuration}</p>
              </div>
              <div>
                <span className="text-[10px] text-mdt-text-muted uppercase tracking-wider block mb-1">Status</span>
                <p className={`text-xl font-semibold ${isOnDuty ? 'text-mdt-success' : 'text-mdt-danger'}`}>
                  {isOnDuty ? 'Active' : 'Inactive'}
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Officers Banner */}
        <div className="relative bg-white/[0.03] border border-white/[0.08] rounded-2xl overflow-hidden">
          <div
            className="absolute inset-0 opacity-[0.08] bg-cover bg-center pointer-events-none"
            style={{ backgroundImage: "url('img/webp/walkie.webp')" }}
          />
          <div className="relative p-6">
            <div className="flex items-center gap-3 mb-5">
              <i className="fa-solid fa-users text-white/60" />
              <span className="font-heading text-xl tracking-wider text-mdt-text-primary">
                ACTIVE OFFICERS
              </span>
            </div>
            <div className="flex items-end gap-4">
              <span className="text-6xl font-bold text-mdt-accent leading-none">
                {onDutyOfficers.length}
              </span>
              <span className="text-sm text-mdt-text-muted pb-2">
                officers currently on duty
              </span>
            </div>
            {onDutyOfficers.length > 0 && (
              <div className="flex flex-wrap gap-2 mt-4">
                {onDutyOfficers.slice(0, 6).map((officer) => (
                  <span
                    key={officer.source}
                    className="px-3 py-1 bg-white/[0.06] border border-white/[0.08] rounded-full text-[11px] text-mdt-text-secondary"
                  >
                    {officer.name}
                  </span>
                ))}
                {onDutyOfficers.length > 6 && (
                  <span className="px-3 py-1 bg-white/[0.04] rounded-full text-[11px] text-mdt-text-muted">
                    +{onDutyOfficers.length - 6} more
                  </span>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Welcome Footer */}
      <div className="text-center py-4">
        <p className="font-heading text-sm tracking-[0.3em] text-mdt-text-muted/60 uppercase">
          Welcome to the Police Internal Network
        </p>
      </div>
    </motion.div>
  )
}
