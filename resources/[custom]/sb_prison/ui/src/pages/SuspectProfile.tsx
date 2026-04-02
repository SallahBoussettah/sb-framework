import { useBookingStore } from '../store/bookingStore'
import { InfoRow } from '../components/InfoRow'

export function SuspectProfile() {
  const { selectedSuspect, profileLoading, setStep, setPendingRecords } = useBookingStore()

  if (profileLoading || !selectedSuspect) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center text-booking-text-muted">
          <i className="fas fa-spinner fa-spin text-2xl mb-3" />
          <p className="text-sm">Loading suspect profile...</p>
        </div>
      </div>
    )
  }

  const s = selectedSuspect
  const pendingRecords = s.records.filter(r => !r.served && r.jail_time > 0)
  const totalMonths = pendingRecords.reduce((sum, r) => sum + r.jail_time, 0)
  const totalSeconds = totalMonths * 30 // Config.MonthToSeconds = 30
  const location: 'mrpd' | 'bolingbroke' = totalSeconds < 900 ? 'mrpd' : 'bolingbroke'

  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60)
    const sec = secs % 60
    return `${m}m ${sec}s`
  }

  const handleCreateArrestFile = () => {
    setPendingRecords(pendingRecords, totalMonths, totalSeconds, location)
    setStep('arrest-file')
  }

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center gap-2 mb-4">
        <button
          onClick={() => setStep('lookup')}
          className="text-booking-text-secondary hover:text-white transition-colors"
        >
          <i className="fas fa-arrow-left text-sm" />
        </button>
        <h2 className="text-base font-semibold text-white">Suspect Profile</h2>
      </div>

      <div className="flex gap-5 flex-1 min-h-0">
        {/* Left: Personal Info */}
        <div className="w-[280px] shrink-0 space-y-2">
          <div className="bg-booking-bg-secondary border border-booking-border rounded p-4">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-12 h-12 rounded-full bg-booking-bg-elevated flex items-center justify-center">
                <i className="fas fa-user text-booking-text-muted text-xl" />
              </div>
              <div>
                <p className="text-sm font-semibold text-white">{s.firstname} {s.lastname}</p>
                <p className="text-[11px] text-booking-text-secondary">CID: {s.citizenid}</p>
              </div>
            </div>
            <div className="space-y-1">
              <InfoRow label="Date of Birth" value={s.dob} icon="fa-cake-candles" />
              <InfoRow label="Gender" value={s.gender === 'male' ? 'Male' : 'Female'} icon="fa-venus-mars" />
              <InfoRow label="Phone" value={s.phone || 'N/A'} icon="fa-phone" />
              <InfoRow label="Occupation" value={s.job || 'Unemployed'} icon="fa-briefcase" />
            </div>
          </div>

          {/* Sentence Summary */}
          <div className="bg-booking-bg-secondary border border-booking-border rounded p-4">
            <h3 className="text-xs font-semibold text-booking-text-secondary uppercase mb-2">Pending Sentence</h3>
            <div className="space-y-1">
              <InfoRow
                label="Total Months"
                value={totalMonths > 0 ? `${totalMonths} months` : 'None'}
                icon="fa-clock"
                valueColor={totalMonths > 0 ? 'text-booking-danger' : 'text-booking-success'}
              />
              <InfoRow
                label="Real Time"
                value={totalMonths > 0 ? formatTime(totalSeconds) : 'N/A'}
                icon="fa-hourglass-half"
              />
              <InfoRow
                label="Location"
                value={totalMonths > 0 ? (location === 'mrpd' ? 'MRPD Cells' : 'Bolingbroke') : 'N/A'}
                icon="fa-building-lock"
                valueColor={location === 'bolingbroke' ? 'text-booking-warning' : 'text-booking-accent'}
              />
            </div>
          </div>
        </div>

        {/* Right: Criminal Records */}
        <div className="flex-1 flex flex-col min-h-0">
          <h3 className="text-xs font-semibold text-booking-text-secondary uppercase mb-2">Criminal Records</h3>
          <div className="flex-1 overflow-y-auto space-y-1">
            {s.records.length > 0 ? (
              <table className="w-full text-xs">
                <thead>
                  <tr className="text-booking-text-muted border-b border-booking-border">
                    <th className="text-left py-2 px-2 font-medium">Charges</th>
                    <th className="text-center py-2 px-2 font-medium w-16">Jail</th>
                    <th className="text-center py-2 px-2 font-medium w-16">Fine</th>
                    <th className="text-left py-2 px-2 font-medium w-24">Officer</th>
                    <th className="text-center py-2 px-2 font-medium w-14">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {s.records.map((rec) => (
                    <tr
                      key={rec.id}
                      className={`border-b border-booking-border/50 ${
                        !rec.served && rec.jail_time > 0 ? 'bg-booking-danger/5' : ''
                      }`}
                    >
                      <td className="py-2 px-2 text-white">{rec.charges}</td>
                      <td className="py-2 px-2 text-center text-booking-danger">{rec.jail_time}mo</td>
                      <td className="py-2 px-2 text-center text-booking-warning">${rec.fine}</td>
                      <td className="py-2 px-2 text-booking-text-secondary">{rec.officer_name}</td>
                      <td className="py-2 px-2 text-center">
                        {rec.served ? (
                          <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] bg-booking-success/15 text-booking-success">
                            <i className="fas fa-check text-[8px]" /> Served
                          </span>
                        ) : rec.jail_time > 0 ? (
                          <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] bg-booking-danger/15 text-booking-danger">
                            Pending
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] bg-booking-bg-elevated text-booking-text-muted">
                            N/A
                          </span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <div className="flex flex-col items-center justify-center py-8 text-booking-text-muted">
                <i className="fas fa-file-circle-check text-2xl mb-2" />
                <p className="text-sm">No criminal records</p>
              </div>
            )}
          </div>

          {/* Action */}
          <div className="pt-3 mt-auto">
            <button
              onClick={handleCreateArrestFile}
              disabled={pendingRecords.length === 0}
              className="w-full py-2.5 bg-booking-accent hover:bg-booking-accent-hover disabled:opacity-40 disabled:cursor-not-allowed text-white rounded text-sm font-medium transition-colors flex items-center justify-center gap-2"
            >
              <i className="fas fa-file-lines text-xs" />
              Create Arrest File
            </button>
            {pendingRecords.length === 0 && (
              <p className="text-[11px] text-booking-danger text-center mt-1">
                No pending charges with jail time
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
