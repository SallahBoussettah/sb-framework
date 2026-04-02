import { useState, useEffect } from 'react'
import { AlertTriangle, Shield, Car, Plus, X, ChevronRight } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { useMDTStore } from '../store/mdtStore'
import { fetchNui } from '../utils/nui'
import SearchPopup from '../components/SearchPopup'
import type { Warrant, BOLO } from '../types'

type Tab = 'warrants' | 'bolos' | 'vehicle-flags'

const priorityColors = {
  low: 'bg-mdt-text-muted/20 text-mdt-text-muted',
  medium: 'bg-mdt-warning/20 text-mdt-warning',
  high: 'bg-mdt-danger/20 text-mdt-danger',
}

export default function Warrants() {
  const [activeTab, setActiveTab] = useState<Tab>('warrants')
  const { warrants, bolos, vehicleFlags } = useMDTStore()

  useEffect(() => {
    fetchNui('getWarrants')
    fetchNui('getBOLOs')
    fetchNui('getAllVehicleFlags')
  }, [])

  const tabs: { id: Tab; label: string; icon: typeof AlertTriangle; count: number }[] = [
    { id: 'warrants', label: 'Active Warrants', icon: AlertTriangle, count: warrants.length },
    { id: 'bolos', label: 'Person BOLOs', icon: Shield, count: bolos.length },
    { id: 'vehicle-flags', label: 'Vehicle Flags', icon: Car, count: vehicleFlags.length },
  ]

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="absolute inset-0 p-6 overflow-hidden flex flex-col">
      <div className="mb-5">
        <h2 className="font-heading text-2xl tracking-wider text-mdt-text-primary">Warrants & BOLOs</h2>
        <p className="text-sm text-mdt-text-secondary mt-1">Manage active warrants, person BOLOs, and vehicle flags</p>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 mb-4">
        {tabs.map((tab) => {
          const Icon = tab.icon
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`flex items-center gap-2 px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                activeTab === tab.id
                  ? 'bg-mdt-accent/20 border border-mdt-accent text-mdt-accent'
                  : 'bg-mdt-bg-secondary border border-mdt-border text-mdt-text-secondary hover:bg-mdt-bg-hover'
              }`}
            >
              <Icon className="w-4 h-4" />
              {tab.label}
              <span className="ml-1 px-1.5 py-0.5 rounded-full text-[10px] font-bold bg-mdt-bg-tertiary">
                {tab.count}
              </span>
            </button>
          )
        })}
      </div>

      {/* Content */}
      <div className="flex-1 min-h-0 overflow-hidden">
        {activeTab === 'warrants' && <WarrantsTab />}
        {activeTab === 'bolos' && <BOLOsTab />}
        {activeTab === 'vehicle-flags' && <VehicleFlagsTab />}
      </div>
    </motion.div>
  )
}

// =============================================
// Warrants Tab
// =============================================

function WarrantsTab() {
  const { warrants } = useMDTStore()
  const [showForm, setShowForm] = useState(false)
  const [selectedWarrant, setSelectedWarrant] = useState<Warrant | null>(null)
  const [showSearch, setShowSearch] = useState(false)
  const [closeReason, setCloseReason] = useState('')

  // Form state
  const [formCitizenId, setFormCitizenId] = useState('')
  const [formCitizenName, setFormCitizenName] = useState('')
  const [formCharges, setFormCharges] = useState('')
  const [formReason, setFormReason] = useState('')
  const [formPriority, setFormPriority] = useState<'low' | 'medium' | 'high'>('medium')

  const handleIssue = () => {
    if (!formCitizenId || !formCharges.trim()) return
    fetchNui('createWarrant', {
      citizenId: formCitizenId,
      citizenName: formCitizenName,
      charges: formCharges,
      reason: formReason,
      priority: formPriority,
    })
    setShowForm(false)
    setFormCitizenId('')
    setFormCitizenName('')
    setFormCharges('')
    setFormReason('')
    setFormPriority('medium')
    setTimeout(() => fetchNui('getWarrants'), 500)
  }

  const handleClose = () => {
    if (!selectedWarrant || !closeReason.trim()) return
    fetchNui('closeWarrant', { warrantId: selectedWarrant.id, closedReason: closeReason })
    setSelectedWarrant(null)
    setCloseReason('')
    setTimeout(() => fetchNui('getWarrants'), 500)
  }

  return (
    <div className="h-full flex gap-4">
      {/* List */}
      <div className="w-[360px] flex flex-col gap-3 shrink-0">
        <button
          onClick={() => { setShowForm(true); setSelectedWarrant(null) }}
          className="flex items-center justify-center gap-2 px-4 py-2.5 bg-mdt-accent hover:bg-mdt-accent-hover rounded-md text-sm font-semibold text-white transition-colors"
        >
          <Plus className="w-4 h-4" />
          Issue Warrant
        </button>
        <div className="flex-1 bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-y-auto">
          {warrants.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-full text-mdt-text-muted">
              <AlertTriangle className="w-10 h-10 opacity-50 mb-3" />
              <p className="text-sm">No active warrants</p>
            </div>
          ) : (
            <div className="divide-y divide-mdt-border/50">
              {warrants.map((w) => (
                <button
                  key={w.id}
                  onClick={() => { setSelectedWarrant(w); setShowForm(false) }}
                  className={`w-full flex items-start gap-3 px-4 py-3 hover:bg-mdt-bg-hover transition-colors text-left ${
                    selectedWarrant?.id === w.id ? 'bg-mdt-bg-hover' : ''
                  }`}
                >
                  <span className={`mt-0.5 px-2 py-0.5 rounded text-[10px] font-bold uppercase ${priorityColors[w.priority]}`}>
                    {w.priority}
                  </span>
                  <div className="flex-1 min-w-0">
                    <p className="text-[13px] font-semibold text-mdt-text-primary truncate">{w.citizenName}</p>
                    <p className="text-[11px] text-mdt-text-muted truncate">{w.charges}</p>
                    <p className="text-[10px] text-mdt-text-muted mt-0.5">by {w.issuedBy} &bull; {w.createdAt}</p>
                  </div>
                  <ChevronRight className="w-4 h-4 text-mdt-text-muted shrink-0 mt-1" />
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Detail / Form Panel */}
      <div className="flex-1 bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-hidden">
        <AnimatePresence mode="wait">
          {showForm ? (
            <motion.div key="form" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="h-full flex flex-col">
              <div className="flex items-center justify-between px-5 py-4 bg-mdt-bg-tertiary border-b border-mdt-border">
                <h3 className="text-lg font-semibold text-mdt-text-primary">Issue Warrant</h3>
                <button onClick={() => setShowForm(false)} className="w-8 h-8 flex items-center justify-center rounded text-mdt-text-secondary hover:bg-mdt-bg-hover"><X className="w-4 h-4" /></button>
              </div>
              <div className="flex-1 overflow-y-auto p-5 space-y-4">
                {/* Citizen Select */}
                <div>
                  <label className="block text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-2">Citizen</label>
                  {formCitizenId ? (
                    <div className="flex items-center gap-2">
                      <span className="flex-1 px-3 py-2 bg-mdt-bg-tertiary border border-mdt-border rounded text-sm text-mdt-text-primary">{formCitizenName} ({formCitizenId})</span>
                      <button onClick={() => { setFormCitizenId(''); setFormCitizenName('') }} className="text-mdt-text-muted hover:text-mdt-danger"><X className="w-4 h-4" /></button>
                    </div>
                  ) : (
                    <button onClick={() => setShowSearch(true)} className="w-full px-3 py-2 bg-mdt-bg-tertiary border border-mdt-border border-dashed rounded text-sm text-mdt-text-muted hover:border-mdt-accent hover:text-mdt-accent transition-colors">
                      Click to search citizen...
                    </button>
                  )}
                </div>
                <div>
                  <label className="block text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-2">Charges *</label>
                  <textarea value={formCharges} onChange={(e) => setFormCharges(e.target.value)} rows={3} placeholder="List charges..." className="w-full px-3 py-2 bg-mdt-bg-tertiary border border-mdt-border rounded text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors resize-none" />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-2">Reason</label>
                  <textarea value={formReason} onChange={(e) => setFormReason(e.target.value)} rows={2} placeholder="Additional details..." className="w-full px-3 py-2 bg-mdt-bg-tertiary border border-mdt-border rounded text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors resize-none" />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-2">Priority</label>
                  <div className="flex gap-2">
                    {(['low', 'medium', 'high'] as const).map((p) => (
                      <button key={p} onClick={() => setFormPriority(p)} className={`px-4 py-2 rounded text-xs font-semibold uppercase transition-colors ${formPriority === p ? priorityColors[p] + ' ring-1 ring-current' : 'bg-mdt-bg-tertiary border border-mdt-border text-mdt-text-secondary hover:bg-mdt-bg-hover'}`}>{p}</button>
                    ))}
                  </div>
                </div>
                <button onClick={handleIssue} disabled={!formCitizenId || !formCharges.trim()} className="w-full py-2.5 bg-mdt-accent hover:bg-mdt-accent-hover rounded-md text-sm font-semibold text-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed">
                  Issue Warrant
                </button>
              </div>
            </motion.div>
          ) : selectedWarrant ? (
            <motion.div key="detail" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="h-full flex flex-col">
              <div className="flex items-center justify-between px-5 py-4 bg-mdt-bg-tertiary border-b border-mdt-border">
                <div>
                  <h3 className="text-lg font-semibold text-mdt-text-primary">Warrant #{selectedWarrant.id}</h3>
                  <p className="text-xs text-mdt-text-muted">Issued {selectedWarrant.createdAt}</p>
                </div>
                <span className={`px-3 py-1 rounded text-xs font-bold uppercase ${priorityColors[selectedWarrant.priority]}`}>{selectedWarrant.priority}</span>
              </div>
              <div className="flex-1 overflow-y-auto p-5 space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-3">
                    <p className="text-[10px] font-semibold text-mdt-text-muted uppercase mb-1">Subject</p>
                    <p className="text-sm font-medium text-mdt-text-primary">{selectedWarrant.citizenName}</p>
                    <p className="text-xs text-mdt-text-muted">{selectedWarrant.citizenid}</p>
                  </div>
                  <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-3">
                    <p className="text-[10px] font-semibold text-mdt-text-muted uppercase mb-1">Issued By</p>
                    <p className="text-sm font-medium text-mdt-text-primary">{selectedWarrant.issuedBy}</p>
                  </div>
                </div>
                <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-3">
                  <p className="text-[10px] font-semibold text-mdt-text-muted uppercase mb-1">Charges</p>
                  <p className="text-sm text-mdt-text-primary">{selectedWarrant.charges}</p>
                </div>
                {selectedWarrant.reason && (
                  <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-3">
                    <p className="text-[10px] font-semibold text-mdt-text-muted uppercase mb-1">Reason</p>
                    <p className="text-sm text-mdt-text-primary">{selectedWarrant.reason}</p>
                  </div>
                )}
                <div className="border-t border-mdt-border pt-4">
                  <label className="block text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-2">Close Warrant (Reason) *</label>
                  <textarea value={closeReason} onChange={(e) => setCloseReason(e.target.value)} rows={2} placeholder="Reason for closing..." className="w-full px-3 py-2 bg-mdt-bg-tertiary border border-mdt-border rounded text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors resize-none" />
                  <button onClick={handleClose} disabled={!closeReason.trim()} className="mt-2 w-full py-2.5 bg-mdt-danger/80 hover:bg-mdt-danger rounded-md text-sm font-semibold text-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed">
                    Close Warrant
                  </button>
                </div>
              </div>
            </motion.div>
          ) : (
            <motion.div key="empty" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="flex flex-col items-center justify-center h-full text-mdt-text-muted">
              <AlertTriangle className="w-16 h-16 opacity-50 mb-4" />
              <p className="text-base">Select a warrant or issue a new one</p>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Search Popup */}
      <AnimatePresence>
        {showSearch && (
          <SearchPopup
            type="citizen"
            onSelect={(id, name) => {
              setFormCitizenId(id)
              setFormCitizenName(name)
              setShowSearch(false)
            }}
            onClose={() => setShowSearch(false)}
          />
        )}
      </AnimatePresence>
    </div>
  )
}

// =============================================
// BOLOs Tab
// =============================================

function BOLOsTab() {
  const { bolos } = useMDTStore()
  const [showForm, setShowForm] = useState(false)
  const [selectedBOLO, setSelectedBOLO] = useState<BOLO | null>(null)
  const [closeReason, setCloseReason] = useState('')

  const [formName, setFormName] = useState('')
  const [formDescription, setFormDescription] = useState('')
  const [formReason, setFormReason] = useState('')
  const [formLastSeen, setFormLastSeen] = useState('')
  const [formPriority, setFormPriority] = useState<'low' | 'medium' | 'high'>('medium')

  const handleCreate = () => {
    if (!formName.trim() || !formDescription.trim() || !formReason.trim()) return
    fetchNui('createBOLO', {
      personName: formName,
      description: formDescription,
      reason: formReason,
      lastSeen: formLastSeen,
      priority: formPriority,
    })
    setShowForm(false)
    setFormName('')
    setFormDescription('')
    setFormReason('')
    setFormLastSeen('')
    setFormPriority('medium')
    setTimeout(() => fetchNui('getBOLOs'), 500)
  }

  const handleClose = () => {
    if (!selectedBOLO || !closeReason.trim()) return
    fetchNui('closeBOLO', { boloId: selectedBOLO.id, closedReason: closeReason })
    setSelectedBOLO(null)
    setCloseReason('')
    setTimeout(() => fetchNui('getBOLOs'), 500)
  }

  return (
    <div className="h-full flex gap-4">
      <div className="w-[360px] flex flex-col gap-3 shrink-0">
        <button onClick={() => { setShowForm(true); setSelectedBOLO(null) }} className="flex items-center justify-center gap-2 px-4 py-2.5 bg-mdt-accent hover:bg-mdt-accent-hover rounded-md text-sm font-semibold text-white transition-colors">
          <Plus className="w-4 h-4" /> Create BOLO
        </button>
        <div className="flex-1 bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-y-auto">
          {bolos.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-full text-mdt-text-muted">
              <Shield className="w-10 h-10 opacity-50 mb-3" />
              <p className="text-sm">No active BOLOs</p>
            </div>
          ) : (
            <div className="divide-y divide-mdt-border/50">
              {bolos.map((b) => (
                <button key={b.id} onClick={() => { setSelectedBOLO(b); setShowForm(false) }} className={`w-full flex items-start gap-3 px-4 py-3 hover:bg-mdt-bg-hover transition-colors text-left ${selectedBOLO?.id === b.id ? 'bg-mdt-bg-hover' : ''}`}>
                  <span className={`mt-0.5 px-2 py-0.5 rounded text-[10px] font-bold uppercase ${priorityColors[b.priority]}`}>{b.priority}</span>
                  <div className="flex-1 min-w-0">
                    <p className="text-[13px] font-semibold text-mdt-text-primary truncate">{b.personName}</p>
                    <p className="text-[11px] text-mdt-text-muted truncate">{b.description}</p>
                    <p className="text-[10px] text-mdt-text-muted mt-0.5">by {b.issuedBy} &bull; {b.createdAt}</p>
                  </div>
                  <ChevronRight className="w-4 h-4 text-mdt-text-muted shrink-0 mt-1" />
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="flex-1 bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-hidden">
        <AnimatePresence mode="wait">
          {showForm ? (
            <motion.div key="form" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="h-full flex flex-col">
              <div className="flex items-center justify-between px-5 py-4 bg-mdt-bg-tertiary border-b border-mdt-border">
                <h3 className="text-lg font-semibold text-mdt-text-primary">Create BOLO</h3>
                <button onClick={() => setShowForm(false)} className="w-8 h-8 flex items-center justify-center rounded text-mdt-text-secondary hover:bg-mdt-bg-hover"><X className="w-4 h-4" /></button>
              </div>
              <div className="flex-1 overflow-y-auto p-5 space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-2">Person Name *</label>
                  <input type="text" value={formName} onChange={(e) => setFormName(e.target.value)} placeholder="Full name..." className="w-full px-3 py-2 bg-mdt-bg-tertiary border border-mdt-border rounded text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors" />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-2">Description *</label>
                  <textarea value={formDescription} onChange={(e) => setFormDescription(e.target.value)} rows={3} placeholder="Physical description, distinguishing features..." className="w-full px-3 py-2 bg-mdt-bg-tertiary border border-mdt-border rounded text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors resize-none" />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-2">Reason *</label>
                  <textarea value={formReason} onChange={(e) => setFormReason(e.target.value)} rows={2} placeholder="Why is this person being sought..." className="w-full px-3 py-2 bg-mdt-bg-tertiary border border-mdt-border rounded text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors resize-none" />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-2">Last Seen</label>
                  <input type="text" value={formLastSeen} onChange={(e) => setFormLastSeen(e.target.value)} placeholder="Location last seen..." className="w-full px-3 py-2 bg-mdt-bg-tertiary border border-mdt-border rounded text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors" />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-2">Priority</label>
                  <div className="flex gap-2">
                    {(['low', 'medium', 'high'] as const).map((p) => (
                      <button key={p} onClick={() => setFormPriority(p)} className={`px-4 py-2 rounded text-xs font-semibold uppercase transition-colors ${formPriority === p ? priorityColors[p] + ' ring-1 ring-current' : 'bg-mdt-bg-tertiary border border-mdt-border text-mdt-text-secondary hover:bg-mdt-bg-hover'}`}>{p}</button>
                    ))}
                  </div>
                </div>
                <button onClick={handleCreate} disabled={!formName.trim() || !formDescription.trim() || !formReason.trim()} className="w-full py-2.5 bg-mdt-accent hover:bg-mdt-accent-hover rounded-md text-sm font-semibold text-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed">
                  Create BOLO
                </button>
              </div>
            </motion.div>
          ) : selectedBOLO ? (
            <motion.div key="detail" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="h-full flex flex-col">
              <div className="flex items-center justify-between px-5 py-4 bg-mdt-bg-tertiary border-b border-mdt-border">
                <div>
                  <h3 className="text-lg font-semibold text-mdt-text-primary">BOLO #{selectedBOLO.id}</h3>
                  <p className="text-xs text-mdt-text-muted">Issued {selectedBOLO.createdAt}</p>
                </div>
                <span className={`px-3 py-1 rounded text-xs font-bold uppercase ${priorityColors[selectedBOLO.priority]}`}>{selectedBOLO.priority}</span>
              </div>
              <div className="flex-1 overflow-y-auto p-5 space-y-4">
                <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-3">
                  <p className="text-[10px] font-semibold text-mdt-text-muted uppercase mb-1">Person</p>
                  <p className="text-sm font-medium text-mdt-text-primary">{selectedBOLO.personName}</p>
                </div>
                <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-3">
                  <p className="text-[10px] font-semibold text-mdt-text-muted uppercase mb-1">Description</p>
                  <p className="text-sm text-mdt-text-primary">{selectedBOLO.description}</p>
                </div>
                <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-3">
                  <p className="text-[10px] font-semibold text-mdt-text-muted uppercase mb-1">Reason</p>
                  <p className="text-sm text-mdt-text-primary">{selectedBOLO.reason}</p>
                </div>
                {selectedBOLO.lastSeen && (
                  <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-3">
                    <p className="text-[10px] font-semibold text-mdt-text-muted uppercase mb-1">Last Seen</p>
                    <p className="text-sm text-mdt-text-primary">{selectedBOLO.lastSeen}</p>
                  </div>
                )}
                <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-3">
                  <p className="text-[10px] font-semibold text-mdt-text-muted uppercase mb-1">Issued By</p>
                  <p className="text-sm text-mdt-text-primary">{selectedBOLO.issuedBy}</p>
                </div>
                <div className="border-t border-mdt-border pt-4">
                  <label className="block text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-2">Close BOLO (Reason) *</label>
                  <textarea value={closeReason} onChange={(e) => setCloseReason(e.target.value)} rows={2} placeholder="Reason for closing..." className="w-full px-3 py-2 bg-mdt-bg-tertiary border border-mdt-border rounded text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors resize-none" />
                  <button onClick={handleClose} disabled={!closeReason.trim()} className="mt-2 w-full py-2.5 bg-mdt-danger/80 hover:bg-mdt-danger rounded-md text-sm font-semibold text-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed">
                    Close BOLO
                  </button>
                </div>
              </div>
            </motion.div>
          ) : (
            <motion.div key="empty" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="flex flex-col items-center justify-center h-full text-mdt-text-muted">
              <Shield className="w-16 h-16 opacity-50 mb-4" />
              <p className="text-base">Select a BOLO or create a new one</p>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  )
}

// =============================================
// Vehicle Flags Tab (Read-only)
// =============================================

function VehicleFlagsTab() {
  const { vehicleFlags } = useMDTStore()

  const flagTypeColors: Record<string, string> = {
    stolen: 'bg-mdt-danger/20 text-mdt-danger',
    bolo: 'bg-mdt-warning/20 text-mdt-warning',
    wanted: 'bg-mdt-danger/20 text-mdt-danger',
  }

  return (
    <div className="h-full bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-hidden flex flex-col">
      <div className="px-5 py-3 bg-mdt-bg-tertiary border-b border-mdt-border">
        <p className="text-xs text-mdt-text-muted">Vehicle flags are managed from the Vehicles page. This is a read-only overview.</p>
      </div>
      <div className="flex-1 overflow-y-auto">
        {vehicleFlags.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-mdt-text-muted">
            <Car className="w-10 h-10 opacity-50 mb-3" />
            <p className="text-sm">No vehicle flags</p>
          </div>
        ) : (
          <table className="w-full">
            <thead className="sticky top-0 bg-mdt-bg-tertiary">
              <tr className="text-left text-[10px] font-semibold text-mdt-text-muted uppercase tracking-wide">
                <th className="px-4 py-2.5">Plate</th>
                <th className="px-4 py-2.5">Type</th>
                <th className="px-4 py-2.5">Note</th>
                <th className="px-4 py-2.5">Added By</th>
                <th className="px-4 py-2.5">Date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-mdt-border/30">
              {vehicleFlags.map((f, i) => (
                <tr key={i} className="hover:bg-mdt-bg-hover transition-colors">
                  <td className="px-4 py-2.5 text-sm font-mono font-semibold text-mdt-text-primary">{(f as any).plate || '-'}</td>
                  <td className="px-4 py-2.5">
                    <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase ${flagTypeColors[f.type] || 'bg-mdt-bg-tertiary text-mdt-text-muted'}`}>
                      {f.type}
                    </span>
                  </td>
                  <td className="px-4 py-2.5 text-sm text-mdt-text-secondary max-w-[200px] truncate">{f.note || '-'}</td>
                  <td className="px-4 py-2.5 text-sm text-mdt-text-secondary">{f.addedBy || '-'}</td>
                  <td className="px-4 py-2.5 text-xs text-mdt-text-muted">{f.addedAt || '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
