import { fetchNui } from '../utils/nui'
import { useBookingStore } from '../store/bookingStore'

export function Header() {
  const { officerData } = useBookingStore()

  const handleClose = () => {
    fetchNui('close')
  }

  return (
    <div className="flex items-center justify-between px-5 py-3 bg-booking-bg-secondary border-b border-booking-border">
      <div className="flex items-center gap-3">
        <i className="fas fa-shield-halved text-booking-accent text-lg" />
        <div>
          <h1 className="text-sm font-semibold text-white tracking-wide uppercase font-display text-[16px]">
            LSPD Booking Terminal
          </h1>
          {officerData && (
            <p className="text-[11px] text-booking-text-secondary">
              Officer: {officerData.name} | Badge #{officerData.badge}
            </p>
          )}
        </div>
      </div>
      <button
        onClick={handleClose}
        className="w-8 h-8 flex items-center justify-center rounded hover:bg-booking-danger/20 text-booking-text-secondary hover:text-booking-danger transition-colors"
      >
        <i className="fas fa-xmark text-sm" />
      </button>
    </div>
  )
}
