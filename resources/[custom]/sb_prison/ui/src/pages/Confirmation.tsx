import { useBookingStore } from '../store/bookingStore'
import { InfoRow } from '../components/InfoRow'
import { fetchNui } from '../utils/nui'

export function Confirmation() {
  const { bookingConfirmation } = useBookingStore()

  if (!bookingConfirmation) {
    return (
      <div className="flex items-center justify-center h-full">
        <i className="fas fa-spinner fa-spin text-2xl text-booking-text-muted" />
      </div>
    )
  }

  const c = bookingConfirmation
  const isShort = c.location === 'mrpd'

  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60)
    const sec = secs % 60
    return `${m}m ${sec}s`
  }

  const handleClose = () => {
    fetchNui('close')
  }

  const hasMugshots = c.mugshotFront || c.mugshotSide

  return (
    <div className="flex flex-col items-center justify-center h-full">
      {/* Success icon */}
      <div className="w-16 h-16 rounded-full bg-booking-success/15 flex items-center justify-center mb-4">
        <i className="fas fa-check-circle text-booking-success text-3xl" />
      </div>

      <h2 className="text-lg font-semibold text-white mb-1">Booking Registered</h2>
      <p className="text-xs text-booking-text-secondary mb-5">
        Suspect has been officially booked into the system
      </p>

      {/* Summary card */}
      <div className="w-[480px] bg-booking-bg-secondary border border-booking-border rounded p-5">
        <div className="flex gap-5">
          {/* Left: Info */}
          <div className="flex-1 space-y-1.5">
            <InfoRow label="Suspect" value={c.suspectName} icon="fa-user" />
            <InfoRow label="Citizen ID" value={c.citizenid} icon="fa-id-card" />
            <InfoRow
              label="Sentence"
              value={`${c.totalMonths} months (${formatTime(c.totalSeconds)})`}
              icon="fa-gavel"
              valueColor="text-booking-danger"
            />
            <InfoRow
              label="Facility"
              value={isShort ? 'MRPD Holding Cells' : 'Bolingbroke Penitentiary'}
              icon="fa-building-lock"
              valueColor={isShort ? 'text-booking-accent' : 'text-booking-warning'}
            />
          </div>

          {/* Right: Mugshots (front + side) */}
          {hasMugshots && (
            <div className="shrink-0 flex gap-2">
              {c.mugshotFront && (
                <div className="text-center">
                  <div className="w-16 h-20 bg-booking-bg-tertiary rounded border border-booking-border overflow-hidden">
                    <img src={c.mugshotFront} alt="Front" className="w-full h-full object-cover" />
                  </div>
                  <span className="text-[10px] text-booking-text-muted mt-0.5 block">Front</span>
                </div>
              )}
              {c.mugshotSide && (
                <div className="text-center">
                  <div className="w-16 h-20 bg-booking-bg-tertiary rounded border border-booking-border overflow-hidden">
                    <img src={c.mugshotSide} alt="Side" className="w-full h-full object-cover" />
                  </div>
                  <span className="text-[10px] text-booking-text-muted mt-0.5 block">Side</span>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Status message */}
        <div className={`mt-4 p-3 rounded text-xs ${
          isShort
            ? 'bg-booking-accent/10 border border-booking-accent/30 text-booking-accent'
            : 'bg-booking-warning/10 border border-booking-warning/30 text-booking-warning'
        }`}>
          <i className={`fas ${isShort ? 'fa-lock' : 'fa-truck-moving'} mr-2`} />
          {isShort
            ? 'Escort suspect to MRPD cell. Sentence timer has started.'
            : 'Suspect is ON HOLD in MRPD cell. Transport to Bolingbroke Penitentiary required.'
          }
        </div>
      </div>

      {/* Close button */}
      <button
        onClick={handleClose}
        className="mt-5 px-8 py-2.5 bg-booking-bg-elevated border border-booking-border hover:border-booking-accent/50 text-white rounded text-sm font-medium transition-colors"
      >
        Close Terminal
      </button>
    </div>
  )
}
