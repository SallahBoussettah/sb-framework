import { useState, useEffect } from 'react'
import { User, X, Check, Search, FileText, StickyNote, Trash2, Send, Car } from 'lucide-react'
import { motion } from 'framer-motion'
import { useMDTStore } from '../store/mdtStore'
import { fetchNui, onNuiMessage } from '../utils/nui'
import type { CitizenDetail, CitizenNote } from '../types'

interface CitizenProfileProps {
  citizen: CitizenDetail
  onClose: () => void
}

type TabId = 'info' | 'records' | 'charges'

export default function CitizenProfile({ citizen, onClose }: CitizenProfileProps) {
  const [activeTab, setActiveTab] = useState<TabId>('info')
  const [chargeSearch, setChargeSearch] = useState('')
  const [newNote, setNewNote] = useState('')
  const [notes, setNotes] = useState<CitizenNote[]>(citizen.notes || [])
  const [recordsSubTab, setRecordsSubTab] = useState<'criminal' | 'citations'>('criminal')
  const { penalCode, selectedCharges, addCharge, removeCharge, clearCharges, isOnDuty } = useMDTStore()

  // Listen for notes updates from server
  useEffect(() => {
    const unsub = onNuiMessage<{ citizenId: string; notes: CitizenNote[] }>('citizenNotes', (data) => {
      if (data.citizenId === citizen.citizenid) {
        setNotes(data.notes || [])
      }
    })
    return unsub
  }, [citizen.citizenid])

  // Sync notes from citizen prop
  useEffect(() => {
    setNotes(citizen.notes || [])
  }, [citizen.notes])

  const tabs: { id: TabId; label: string }[] = [
    { id: 'info', label: 'Information' },
    { id: 'records', label: 'Records' },
    { id: 'charges', label: 'Add Charges' },
  ]

  const filteredCharges = penalCode.filter(
    (code) =>
      code.title.toLowerCase().includes(chargeSearch.toLowerCase()) ||
      code.category.toLowerCase().includes(chargeSearch.toLowerCase())
  )

  const totalFine = selectedCharges.reduce((sum, c) => sum + c.fine, 0)
  const totalJail = selectedCharges.reduce((sum, c) => sum + c.jailTime, 0)

  const handleAddCharge = (code: typeof penalCode[0]) => {
    addCharge({
      uid: `${code.id}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
      id: code.id,
      title: code.title,
      category: code.category,
      fine: code.fine,
      jailTime: code.jail_time,
    })
  }

  const handleApplyCharges = () => {
    if (selectedCharges.length === 0) return

    fetchNui('applyCharges', {
      citizenId: citizen.citizenid,
      charges: selectedCharges,
      totalFine,
      totalJail,
    })

    clearCharges()
  }

  const handleAddNote = () => {
    if (!newNote.trim()) return
    fetchNui('addCitizenNote', { citizenId: citizen.citizenid, note: newNote.trim() })
    setNewNote('')
  }

  const handleDeleteNote = (noteId: number) => {
    fetchNui('deleteCitizenNote', { noteId, citizenId: citizen.citizenid })
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="h-full flex flex-col"
    >
      {/* Header */}
      <div className="flex items-center gap-4 p-5 bg-mdt-bg-tertiary border-b border-mdt-border">
        <div className="w-16 h-16 bg-mdt-bg-hover rounded-full flex items-center justify-center overflow-hidden">
          {citizen.mugshot ? (
            <img src={citizen.mugshot} alt="Mugshot" className="w-full h-full object-cover" />
          ) : (
            <User className="w-9 h-9 text-mdt-text-muted" />
          )}
        </div>
        <div className="flex-1">
          <h3 className="font-heading text-xl tracking-wider text-mdt-text-primary">
            {citizen.firstname} {citizen.lastname}
          </h3>
          <p className="text-sm text-mdt-text-muted font-mono">{citizen.citizenid}</p>
        </div>
        {citizen.wanted && (
          <span className="px-3 py-1.5 bg-mdt-danger/20 text-mdt-danger text-xs font-bold uppercase rounded">
            WANTED
          </span>
        )}
        <button
          onClick={onClose}
          className="w-8 h-8 flex items-center justify-center rounded-md text-mdt-text-secondary hover:bg-mdt-bg-hover transition-colors"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      {/* Tabs */}
      <div className="flex gap-0 px-5 bg-mdt-bg-secondary border-b border-mdt-border">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`px-5 py-3.5 text-sm font-medium border-b-2 transition-colors ${
              activeTab === tab.id
                ? 'text-mdt-accent border-mdt-accent'
                : 'text-mdt-text-secondary border-transparent hover:text-mdt-text-primary'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto p-5">
        {activeTab === 'info' && (
          <div className="space-y-5">
            <div className="grid grid-cols-2 gap-5">
              {/* Personal Info */}
              <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
                <h4 className="text-[11px] font-semibold text-mdt-text-muted uppercase tracking-wide mb-3 pb-2 border-b border-mdt-border">
                  Personal Information
                </h4>
                <div className="space-y-2">
                  <InfoRow label="Full Name" value={`${citizen.firstname} ${citizen.lastname}`} />
                  <InfoRow label="Date of Birth" value={citizen.dob || '--'} />
                  <InfoRow label="Gender" value={citizen.gender || '--'} />
                  <InfoRow label="Phone" value={citizen.phone || '--'} />
                  <InfoRow label="Nationality" value={citizen.nationality || 'Unknown'} />
                </div>
              </div>

              {/* Employment */}
              <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
                <h4 className="text-[11px] font-semibold text-mdt-text-muted uppercase tracking-wide mb-3 pb-2 border-b border-mdt-border">
                  Employment
                </h4>
                <div className="space-y-2">
                  <InfoRow label="Occupation" value={citizen.job || 'Unemployed'} />
                  <InfoRow label="Position" value={citizen.jobGrade || '--'} />
                </div>
              </div>

              {/* Licenses */}
              <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
                <h4 className="text-[11px] font-semibold text-mdt-text-muted uppercase tracking-wide mb-3 pb-2 border-b border-mdt-border">
                  Licenses
                </h4>
                <div className="space-y-2">
                  <InfoRow
                    label="Driver's License"
                    value={citizen.licenses?.driver ? 'Valid' : 'None'}
                    valueClass={citizen.licenses?.driver ? 'text-mdt-success' : 'text-mdt-text-muted'}
                  />
                  <InfoRow
                    label="Weapon Permit"
                    value={citizen.licenses?.weapon ? 'Valid' : 'None'}
                    valueClass={citizen.licenses?.weapon ? 'text-mdt-success' : 'text-mdt-text-muted'}
                  />
                </div>
              </div>

              {/* Financial */}
              <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
                <h4 className="text-[11px] font-semibold text-mdt-text-muted uppercase tracking-wide mb-3 pb-2 border-b border-mdt-border">
                  Financial
                </h4>
                <div className="space-y-2">
                  <InfoRow label="Bank Balance" value={citizen.bank !== undefined ? `$${citizen.bank.toLocaleString()}` : '--'} />
                  <InfoRow
                    label="Outstanding Fines"
                    value={`$${(citizen.outstandingFines || 0).toLocaleString()}`}
                    valueClass={citizen.outstandingFines ? 'text-mdt-warning font-semibold' : ''}
                  />
                </div>
              </div>
            </div>

            {/* Booking Photo */}
            {citizen.mugshot && (
              <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
                <h4 className="text-[11px] font-semibold text-mdt-text-muted uppercase tracking-wide mb-3 pb-2 border-b border-mdt-border">
                  Booking Photo
                </h4>
                <div className="flex gap-4">
                  <div className="flex flex-col items-center gap-1">
                    <img src={citizen.mugshot} alt="Front" className="w-32 h-40 object-cover rounded border border-mdt-border" />
                    <span className="text-[10px] text-mdt-text-muted">Front</span>
                  </div>
                  {citizen.mugshotSide && (
                    <div className="flex flex-col items-center gap-1">
                      <img src={citizen.mugshotSide} alt="Side" className="w-32 h-40 object-cover rounded border border-mdt-border" />
                      <span className="text-[10px] text-mdt-text-muted">Side</span>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Officer Notes */}
            <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
              <h4 className="text-[11px] font-semibold text-mdt-text-muted uppercase tracking-wide mb-3 pb-2 border-b border-mdt-border flex items-center gap-2">
                <StickyNote className="w-3.5 h-3.5" />
                Officer Notes
              </h4>

              {/* Add note */}
              {isOnDuty && (
                <div className="flex gap-2 mb-3">
                  <input
                    type="text"
                    value={newNote}
                    onChange={(e) => setNewNote(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && handleAddNote()}
                    placeholder="Add a note..."
                    className="flex-1 px-3 py-2 bg-mdt-bg-secondary border border-mdt-border rounded-md text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent"
                  />
                  <button
                    onClick={handleAddNote}
                    disabled={!newNote.trim()}
                    className="px-3 py-2 bg-mdt-accent hover:bg-mdt-accent-hover rounded-md text-white transition-colors disabled:opacity-50"
                  >
                    <Send className="w-4 h-4" />
                  </button>
                </div>
              )}

              <div className="space-y-2 max-h-[200px] overflow-y-auto">
                {notes.length === 0 ? (
                  <p className="text-xs text-mdt-text-muted text-center py-4">No notes yet</p>
                ) : (
                  notes.map((note) => (
                    <div key={note.id} className="flex items-start gap-2 px-3 py-2 bg-mdt-bg-secondary rounded-md">
                      <div className="flex-1 min-w-0">
                        <p className="text-[13px] text-mdt-text-primary">{note.note}</p>
                        <p className="text-[10px] text-mdt-text-muted mt-1">
                          {note.officerName} - {note.createdAt}
                        </p>
                      </div>
                      <button
                        onClick={() => handleDeleteNote(note.id)}
                        className="w-6 h-6 flex items-center justify-center rounded text-mdt-text-muted hover:bg-mdt-danger/20 hover:text-mdt-danger transition-colors shrink-0"
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
        )}

        {activeTab === 'records' && (
          <div className="space-y-4">
            {/* Sub-tabs */}
            <div className="flex gap-2">
              <button
                onClick={() => setRecordsSubTab('criminal')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${
                  recordsSubTab === 'criminal'
                    ? 'bg-mdt-accent/15 text-mdt-accent'
                    : 'bg-mdt-bg-tertiary text-mdt-text-secondary hover:bg-mdt-bg-hover'
                }`}
              >
                <FileText className="w-3 h-3" />
                Criminal Records ({citizen.criminalRecords.length})
              </button>
              <button
                onClick={() => setRecordsSubTab('citations')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${
                  recordsSubTab === 'citations'
                    ? 'bg-mdt-accent/15 text-mdt-accent'
                    : 'bg-mdt-bg-tertiary text-mdt-text-secondary hover:bg-mdt-bg-hover'
                }`}
              >
                <Car className="w-3 h-3" />
                Citations ({(citizen.citations || []).length})
              </button>
            </div>

            {recordsSubTab === 'criminal' && (
              <div className="space-y-3">
                {citizen.criminalRecords.length === 0 ? (
                  <div className="flex flex-col items-center justify-center py-12 text-mdt-text-muted">
                    <User className="w-10 h-10 opacity-50 mb-3" />
                    <p className="text-sm">No criminal records found</p>
                  </div>
                ) : (
                  citizen.criminalRecords.map((record) => (
                    <div
                      key={record.id}
                      className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4"
                    >
                      <div className="flex justify-between items-start mb-2">
                        <div className="flex items-center gap-2">
                          <h5 className="text-sm font-semibold text-mdt-text-primary">{record.charges}</h5>
                          {record.paid && record.served ? (
                            <span className="px-2 py-0.5 rounded text-[10px] font-bold uppercase bg-mdt-success/15 text-mdt-success">
                              RESOLVED
                            </span>
                          ) : (
                            <>
                              <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase ${
                                record.paid
                                  ? 'bg-mdt-success/15 text-mdt-success'
                                  : 'bg-mdt-danger/15 text-mdt-danger'
                              }`}>
                                {record.paid ? 'PAID' : 'UNPAID'}
                              </span>
                              {record.served && (
                                <span className="px-2 py-0.5 rounded text-[10px] font-bold uppercase bg-mdt-accent/15 text-mdt-accent">
                                  TIME SERVED
                                </span>
                              )}
                            </>
                          )}
                        </div>
                        <span className="text-[11px] text-mdt-text-muted">{record.createdAt}</span>
                      </div>
                      <div className="flex gap-5 text-xs text-mdt-text-secondary">
                        {record.paid ? (
                          <span className="text-mdt-text-muted line-through">${record.fine.toLocaleString()}</span>
                        ) : (
                          <>
                            <span className="text-mdt-warning font-semibold">${record.fine.toLocaleString()}</span>
                            {record.amountPaid > 0 && (
                              <span className="text-mdt-text-muted">(${record.amountPaid.toLocaleString()} paid)</span>
                            )}
                          </>
                        )}
                        <span className={record.served ? 'text-mdt-text-muted line-through' : 'text-mdt-danger font-semibold'}>
                          {record.jailTime} months
                        </span>
                        <span className="text-mdt-accent">Officer: {record.officerName}</span>
                      </div>
                    </div>
                  ))
                )}
              </div>
            )}

            {recordsSubTab === 'citations' && (
              <div className="space-y-3">
                {(!citizen.citations || citizen.citations.length === 0) ? (
                  <div className="flex flex-col items-center justify-center py-12 text-mdt-text-muted">
                    <Car className="w-10 h-10 opacity-50 mb-3" />
                    <p className="text-sm">No citations found</p>
                  </div>
                ) : (
                  citizen.citations.map((citation) => (
                    <div
                      key={citation.id}
                      className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4"
                    >
                      <div className="flex justify-between items-start mb-2">
                        <div className="flex items-center gap-2">
                          <h5 className="text-sm font-semibold text-mdt-text-primary">{citation.offense}</h5>
                          <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase ${
                            citation.paid
                              ? 'bg-mdt-success/15 text-mdt-success'
                              : 'bg-mdt-danger/15 text-mdt-danger'
                          }`}>
                            {citation.paid ? 'PAID' : 'UNPAID'}
                          </span>
                        </div>
                        <span className="text-[11px] text-mdt-text-muted">{citation.createdAt}</span>
                      </div>
                      <div className="flex gap-5 text-xs text-mdt-text-secondary">
                        <span className="text-mdt-warning font-semibold">${citation.fine.toLocaleString()}</span>
                        {citation.vehiclePlate && (
                          <span className="text-mdt-text-secondary">Plate: {citation.vehiclePlate}</span>
                        )}
                        {citation.location && (
                          <span className="text-mdt-text-muted">{citation.location}</span>
                        )}
                        <span className="text-mdt-accent">Officer: {citation.officerName}</span>
                      </div>
                      {citation.notes && (
                        <p className="text-[11px] text-mdt-text-muted mt-2 italic">{citation.notes}</p>
                      )}
                    </div>
                  ))
                )}
              </div>
            )}
          </div>
        )}

        {activeTab === 'charges' && (
          <div className="flex gap-5 h-full">
            {/* Available Charges */}
            <div className="flex-1 flex flex-col bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
              <h4 className="text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-3">
                Select Charges
              </h4>
              <div className="relative mb-3">
                <input
                  type="text"
                  value={chargeSearch}
                  onChange={(e) => setChargeSearch(e.target.value)}
                  placeholder="Search charges..."
                  className="w-full px-3 py-2.5 pr-10 bg-mdt-bg-secondary border border-mdt-border rounded-md text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent"
                />
                <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-mdt-text-muted" />
              </div>
              <div className="flex-1 overflow-y-auto space-y-1.5">
                {filteredCharges.map((code) => {
                  const count = selectedCharges.filter((c) => c.id === code.id).length
                  return (
                    <button
                      key={code.id}
                      onClick={() => handleAddCharge(code)}
                      className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-md text-left transition-colors ${
                        count > 0
                          ? 'bg-mdt-success/15 border border-mdt-success'
                          : 'bg-mdt-bg-secondary border border-mdt-border hover:border-mdt-accent'
                      }`}
                    >
                      {count > 0 && (
                        <span className="w-5 h-5 rounded-full bg-mdt-success/30 text-mdt-success text-[10px] font-bold flex items-center justify-center shrink-0">
                          {count}
                        </span>
                      )}
                      <div className="flex-1 min-w-0">
                        <p className="text-[13px] font-medium text-mdt-text-primary">{code.title}</p>
                        <p className="text-[10px] text-mdt-text-muted uppercase">{code.category}</p>
                      </div>
                      <div className="text-right shrink-0">
                        <p className="text-xs font-semibold text-mdt-warning">${code.fine.toLocaleString()}</p>
                        <p className="text-[11px] text-mdt-danger">{code.jail_time}mo</p>
                      </div>
                    </button>
                  )
                })}
              </div>
            </div>

            {/* Selected Charges */}
            <div className="w-[300px] flex flex-col bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
              <h4 className="text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-3">
                Selected Charges
              </h4>
              <div className="flex-1 overflow-y-auto space-y-1.5 mb-4">
                {selectedCharges.length === 0 ? (
                  <div className="flex flex-col items-center justify-center py-6 text-mdt-text-muted">
                    <p className="text-xs">No charges selected</p>
                  </div>
                ) : (
                  selectedCharges.map((charge) => (
                    <div
                      key={charge.uid}
                      className="flex items-center gap-2 px-3 py-2.5 bg-mdt-bg-secondary border border-mdt-border rounded-md"
                    >
                      <div className="flex-1 min-w-0">
                        <p className="text-[13px] font-medium text-mdt-text-primary truncate">{charge.title}</p>
                      </div>
                      <button
                        onClick={() => removeCharge(charge.uid)}
                        className="w-6 h-6 flex items-center justify-center rounded text-mdt-text-muted hover:bg-mdt-danger/20 hover:text-mdt-danger transition-colors"
                      >
                        <X className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  ))
                )}
              </div>

              {/* Summary */}
              <div className="bg-mdt-bg-secondary border border-mdt-border rounded-md p-3 mb-3">
                <div className="flex justify-between py-1.5 text-sm text-mdt-text-secondary">
                  <span>Total Fine:</span>
                  <span className="font-bold text-mdt-warning">${totalFine.toLocaleString()}</span>
                </div>
                <div className="flex justify-between py-1.5 text-sm text-mdt-text-secondary">
                  <span>Total Jail Time:</span>
                  <span className="font-bold text-mdt-danger">{totalJail} months</span>
                </div>
              </div>

              {/* Actions */}
              <div className="flex gap-2">
                <button
                  onClick={clearCharges}
                  className="flex-1 px-4 py-2.5 bg-mdt-bg-tertiary border border-mdt-border rounded-md text-xs font-medium text-mdt-text-secondary hover:bg-mdt-bg-hover transition-colors"
                >
                  Clear All
                </button>
                <button
                  onClick={handleApplyCharges}
                  disabled={selectedCharges.length === 0 || !isOnDuty}
                  title={!isOnDuty ? 'Go on duty to apply charges' : ''}
                  className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-mdt-accent hover:bg-mdt-accent-hover rounded-md text-xs font-semibold text-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <Check className="w-4 h-4" />
                  Apply Charges
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </motion.div>
  )
}

function InfoRow({ label, value, valueClass = '' }: { label: string; value: string; valueClass?: string }) {
  return (
    <div className="flex justify-between items-center py-2 border-b border-mdt-border/50 last:border-0">
      <span className="text-xs text-mdt-text-secondary">{label}</span>
      <span className={`text-sm font-medium text-mdt-text-primary ${valueClass}`}>{value}</span>
    </div>
  )
}
