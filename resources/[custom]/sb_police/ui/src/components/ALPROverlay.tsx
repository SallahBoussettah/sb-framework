import { motion } from 'framer-motion'
import { useALPRStore } from '../store/alprStore'
import type { ALPRVehicle } from '../types'

const PLATE_COLORS: Record<number, string> = {
  0: '#000064',
  1: '#ffff00',
  2: '#ffc800',
  3: '#c80000',
  4: '#000064',
  5: '#323232',
}

export default function ALPROverlay() {
  const { isActive, front, rear } = useALPRStore()

  if (!isActive) return null

  return (
    <div className="fixed top-8 right-[320px] z-[9998] pointer-events-none flex gap-3">
      <PlateDisplay vehicle={front} />
      <PlateDisplay vehicle={rear} />
    </div>
  )
}

function PlateDisplay({ vehicle }: { vehicle: ALPRVehicle | null }) {
  if (!vehicle) return null

  const hasAlert = vehicle.flags && vehicle.flags.length > 0
  const isStolen = vehicle.flags?.some(f => f.type === 'stolen')
  const idx = vehicle.plateIndex ?? 0

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.9 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.9 }}
      className={isStolen ? 'animate-pulse' : ''}
      style={{
        filter: hasAlert
          ? isStolen
            ? 'drop-shadow(0 0 10px rgba(255,50,50,0.7))'
            : 'drop-shadow(0 0 10px rgba(255,200,0,0.7))'
          : 'drop-shadow(0 2px 6px rgba(0,0,0,0.5))',
      }}
    >
      {/* Plate */}
      <div className="relative" style={{ width: '140px' }}>
        <img
          src={`img/plates/${idx}.png`}
          alt=""
          className="w-full block"
          draggable={false}
        />
        {/* Text on top of plate */}
        <div className="absolute inset-0 flex items-center justify-center" style={{ paddingTop: '3%' }}>
          <span
            style={{
              fontFamily: '"Bebas Neue", "Arial Black", sans-serif',
              fontSize: '22px',
              fontWeight: 900,
              color: PLATE_COLORS[idx] ?? PLATE_COLORS[0],
              letterSpacing: '0.15em',
              textShadow: '0 1px 1px rgba(0,0,0,0.15)',
            }}
          >
            {vehicle.plate}
          </span>
        </div>
      </div>

      {/* Speed */}
      <div className="text-center mt-1">
        <span
          className="font-mono font-bold"
          style={{
            fontSize: '13px',
            color: '#4ade80',
            textShadow: '0 1px 4px rgba(0,0,0,0.9)',
          }}
        >
          {vehicle.speed}
          <span className="text-neutral-500 text-[9px] ml-1">MPH</span>
        </span>
      </div>

      {/* Alert */}
      {hasAlert && (
        <div className="text-center mt-0.5">
          <span
            className="text-[9px] font-bold px-1.5 py-0.5 rounded"
            style={{
              background: isStolen ? '#dc2626' : '#f59e0b',
              color: isStolen ? '#fff' : '#000',
            }}
          >
            {isStolen ? 'STOLEN' : 'BOLO'}
          </span>
        </div>
      )}
    </motion.div>
  )
}
