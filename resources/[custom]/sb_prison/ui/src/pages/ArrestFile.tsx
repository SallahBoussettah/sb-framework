import { useBookingStore } from '../store/bookingStore'
import { MugshotPicker } from '../components/MugshotPicker'
import { InfoRow } from '../components/InfoRow'
import { fetchNui } from '../utils/nui'

export function ArrestFile() {
  const {
    selectedSuspect, pendingRecords, totalMonths, totalSeconds, location,
    registerLoading, setRegisterLoading,
    mugshotFront, mugshotSide, pickerOpen,
    openPicker, setMugshotsLoading,
  } = useBookingStore()

  if (!selectedSuspect) return null

  const s = selectedSuspect

  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60)
    const sec = secs % 60
    return `${m}m ${sec}s`
  }

  const handleOpenPicker = (slot: 'front' | 'side') => {
    setMugshotsLoading(true)
    fetchNui('getMugshots')
    openPicker(slot)
  }

  const handleRegister = () => {
    setRegisterLoading(true)
    fetchNui('registerBooking', {
      citizenid: s.citizenid,
      totalMonths,
      totalSeconds,
      location,
      charges: pendingRecords.map(r => r.charges + ' (' + r.jail_time + 'mo)').join(', '),
      recordIds: pendingRecords.map(r => r.id),
      mugshotFront,
      mugshotSide,
    })
  }

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center gap-2 mb-4">
        <button
          onClick={() => useBookingStore.getState().setStep('profile')}
          className="text-booking-text-secondary hover:text-white transition-colors"
        >
          <i className="fas fa-arrow-left text-sm" />
        </button>
        <h2 className="text-base font-semibold text-white">Arrest File</h2>
        <span className="text-xs text-booking-text-secondary ml-2">
          {s.firstname} {s.lastname} ({s.citizenid})
        </span>
      </div>

      <div className="flex gap-5 flex-1 min-h-0">
        {/* Left: Charges + Summary */}
        <div className="flex-1 flex flex-col min-h-0">
          <h3 className="text-xs font-semibold text-booking-text-secondary uppercase mb-2">Charges to Process</h3>
          <div className="flex-1 overflow-y-auto mb-3">
            <table className="w-full text-xs">
              <thead>
                <tr className="text-booking-text-muted border-b border-booking-border">
                  <th className="text-left py-2 px-2 font-medium">Charge</th>
                  <th className="text-center py-2 px-2 font-medium w-20">Jail Time</th>
                </tr>
              </thead>
              <tbody>
                {pendingRecords.map((rec) => (
                  <tr key={rec.id} className="border-b border-booking-border/50">
                    <td className="py-2 px-2 text-white">{rec.charges}</td>
                    <td className="py-2 px-2 text-center text-booking-danger">{rec.jail_time} months</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Sentence summary */}
          <div className="bg-booking-bg-secondary border border-booking-border rounded p-3 space-y-1">
            <h3 className="text-xs font-semibold text-booking-text-secondary uppercase mb-1">Sentence Summary</h3>
            <InfoRow
              label="Total Sentence"
              value={`${totalMonths} months`}
              icon="fa-gavel"
              valueColor="text-booking-danger"
            />
            <InfoRow
              label="Real Time"
              value={formatTime(totalSeconds)}
              icon="fa-hourglass-half"
            />
            <InfoRow
              label="Facility"
              value={location === 'mrpd' ? 'MRPD Holding Cells' : 'Bolingbroke Penitentiary'}
              icon="fa-building-lock"
              valueColor={location === 'bolingbroke' ? 'text-booking-warning' : 'text-booking-accent'}
            />
          </div>
        </div>

        {/* Right: Mugshot Slots (Front + Side) */}
        <div className="w-[260px] shrink-0 flex flex-col">
          <h3 className="text-xs font-semibold text-booking-text-secondary uppercase mb-2">Mugshots</h3>

          <div className="bg-booking-bg-secondary border border-booking-border rounded p-4 flex-1 flex flex-col">
            <div className="flex gap-3 justify-center flex-1">
              {/* Front slot */}
              <div className="flex flex-col items-center">
                <span className="text-[10px] text-booking-text-muted uppercase mb-1.5 font-medium">Front</span>
                <button
                  onClick={() => handleOpenPicker('front')}
                  className={`w-24 h-32 rounded border-2 border-dashed transition-colors overflow-hidden flex items-center justify-center ${
                    mugshotFront
                      ? 'border-booking-success bg-booking-bg-tertiary'
                      : 'border-booking-border hover:border-booking-accent bg-booking-bg-tertiary'
                  }`}
                >
                  {mugshotFront ? (
                    <img src={mugshotFront} alt="Front" className="w-full h-full object-cover" />
                  ) : (
                    <div className="text-center text-booking-text-muted">
                      <i className="fas fa-plus text-lg mb-1 block" />
                      <span className="text-[10px]">Select</span>
                    </div>
                  )}
                </button>
                {mugshotFront && (
                  <button
                    onClick={() => useBookingStore.getState().clearMugshot('front')}
                    className="text-[10px] text-booking-danger hover:text-red-400 mt-1 transition-colors"
                  >
                    Remove
                  </button>
                )}
              </div>

              {/* Side slot */}
              <div className="flex flex-col items-center">
                <span className="text-[10px] text-booking-text-muted uppercase mb-1.5 font-medium">Side</span>
                <button
                  onClick={() => handleOpenPicker('side')}
                  className={`w-24 h-32 rounded border-2 border-dashed transition-colors overflow-hidden flex items-center justify-center ${
                    mugshotSide
                      ? 'border-booking-success bg-booking-bg-tertiary'
                      : 'border-booking-border hover:border-booking-accent bg-booking-bg-tertiary'
                  }`}
                >
                  {mugshotSide ? (
                    <img src={mugshotSide} alt="Side" className="w-full h-full object-cover" />
                  ) : (
                    <div className="text-center text-booking-text-muted">
                      <i className="fas fa-plus text-lg mb-1 block" />
                      <span className="text-[10px]">Select</span>
                    </div>
                  )}
                </button>
                {mugshotSide && (
                  <button
                    onClick={() => useBookingStore.getState().clearMugshot('side')}
                    className="text-[10px] text-booking-danger hover:text-red-400 mt-1 transition-colors"
                  >
                    Remove
                  </button>
                )}
              </div>
            </div>

            <p className="text-[10px] text-booking-text-muted/70 text-center mt-3">
              Click a slot to pick from available photos
            </p>
          </div>

          {/* Register button */}
          <button
            onClick={handleRegister}
            disabled={registerLoading}
            className="mt-3 w-full py-2.5 bg-booking-success hover:bg-green-600 disabled:opacity-40 disabled:cursor-not-allowed text-white rounded text-sm font-medium transition-colors flex items-center justify-center gap-2"
          >
            {registerLoading ? (
              <>
                <i className="fas fa-spinner fa-spin text-xs" />
                Registering...
              </>
            ) : (
              <>
                <i className="fas fa-check-circle text-xs" />
                Register & Sentence
              </>
            )}
          </button>
          {!mugshotFront && !mugshotSide && (
            <p className="text-[10px] text-booking-warning text-center mt-1">
              No mugshots attached — registration still allowed
            </p>
          )}
        </div>
      </div>

      {/* Mugshot picker modal */}
      {pickerOpen && <MugshotPicker />}
    </div>
  )
}
