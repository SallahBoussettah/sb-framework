import { X } from 'lucide-react'
import { useMDTStore } from '../store/mdtStore'
import { fetchNui } from '../utils/nui'

export default function Header() {
  const { isOnDuty, onDutyOfficers, officerData, closeMDT } = useMDTStore()

  const handleClose = () => {
    fetchNui('close')
    closeMDT()
  }

  return (
    <header className="h-16 bg-mdt-bg-primary/90 border-b border-mdt-border flex items-center justify-between px-5 shrink-0">
      {/* Left - Logo + Title */}
      <div className="flex items-center gap-3">
        <img
          src="img/lspdlogo.webp"
          alt="LSPD"
          className="w-10 h-10 object-contain"
        />
        <div>
          <h1 className="font-heading text-xl tracking-wider text-mdt-text-primary leading-none">
            LSPD MDT
          </h1>
          <span className="text-[10px] text-mdt-text-muted uppercase tracking-widest">
            {officerData?.rank || 'Officer'} Terminal
          </span>
        </div>
      </div>

      {/* Right - Officer Count + Duty + Close */}
      <div className="flex items-center gap-4">
        {/* Officer Count */}
        <div className="flex items-center gap-2 text-mdt-text-secondary text-sm">
          <i className="fa-solid fa-users text-mdt-accent text-xs" />
          <span className="font-medium">{onDutyOfficers.length} <span className="text-mdt-text-muted text-xs">on duty</span></span>
        </div>

        {/* Duty Status Badge */}
        <div
          className={`flex items-center gap-2 px-4 py-2 rounded-full text-xs font-bold uppercase tracking-wider border ${
            isOnDuty
              ? 'bg-mdt-success/10 border-mdt-success/40 glow-border-success'
              : 'bg-mdt-danger/10 border-mdt-danger/40 glow-border-danger'
          }`}
        >
          <span
            className={`w-2.5 h-2.5 rounded-full ${
              isOnDuty ? 'bg-mdt-success animate-pulse' : 'bg-mdt-danger'
            }`}
          />
          <span className="text-mdt-text-primary">
            {isOnDuty ? 'ON DUTY' : 'OFF DUTY'}
          </span>
        </div>

        {/* Close Button */}
        <button
          onClick={handleClose}
          className="w-8 h-8 flex items-center justify-center rounded-lg text-mdt-text-muted hover:bg-mdt-danger/20 hover:text-mdt-danger transition-colors"
        >
          <X className="w-5 h-5" />
        </button>
      </div>
    </header>
  )
}
