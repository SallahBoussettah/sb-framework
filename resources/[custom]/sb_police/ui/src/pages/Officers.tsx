import { useState, useEffect } from 'react'
import { Users, Shield, ChevronDown, Loader2 } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { useMDTStore } from '../store/mdtStore'
import { fetchNui } from '../utils/nui'
import type { OfficerRoster } from '../types'

type Tab = 'on-duty' | 'roster'

const statusColors: Record<string, { bg: string; dot: string; label: string }> = {
  available: { bg: 'bg-mdt-success/15', dot: 'bg-mdt-success', label: 'Available' },
  busy: { bg: 'bg-mdt-warning/15', dot: 'bg-mdt-warning', label: 'Busy' },
  responding: { bg: 'bg-orange-500/15', dot: 'bg-orange-500', label: 'Responding' },
  unavailable: { bg: 'bg-mdt-text-muted/15', dot: 'bg-mdt-text-muted', label: 'Unavailable' },
}

export default function Officers() {
  const [activeTab, setActiveTab] = useState<Tab>('on-duty')
  const { officerRoster, onDutyOfficers, officerData } = useMDTStore()

  useEffect(() => {
    fetchNui('getOfficerRoster')
  }, [])

  const isBoss = (officerData?.grade ?? 0) >= 5

  const tabs: { id: Tab; label: string; count: number }[] = [
    { id: 'on-duty', label: 'On Duty', count: onDutyOfficers.length },
    { id: 'roster', label: 'Full Roster', count: officerRoster.length },
  ]

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="absolute inset-0 p-6 overflow-hidden flex flex-col">
      <div className="mb-5">
        <h2 className="font-heading text-2xl tracking-wider text-mdt-text-primary">Officers</h2>
        <p className="text-sm text-mdt-text-secondary mt-1">View on-duty officers and manage the department roster</p>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 mb-4">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex items-center gap-2 px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              activeTab === tab.id
                ? 'bg-mdt-accent/20 border border-mdt-accent text-mdt-accent'
                : 'bg-mdt-bg-secondary border border-mdt-border text-mdt-text-secondary hover:bg-mdt-bg-hover'
            }`}
          >
            {tab.label}
            <span className="ml-1 px-1.5 py-0.5 rounded-full text-[10px] font-bold bg-mdt-bg-tertiary">{tab.count}</span>
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="flex-1 min-h-0 overflow-hidden">
        {activeTab === 'on-duty' && <OnDutyTab />}
        {activeTab === 'roster' && <RosterTab isBoss={isBoss} />}
      </div>
    </motion.div>
  )
}

function OnDutyTab() {
  const { onDutyOfficers, officerData } = useMDTStore()
  const [showStatusDropdown, setShowStatusDropdown] = useState(false)

  const handleStatusChange = (status: string) => {
    fetchNui('updateOfficerStatus', { status })
    setShowStatusDropdown(false)
  }

  return (
    <div className="h-full bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-hidden flex flex-col">
      <div className="px-5 py-3 bg-mdt-bg-tertiary border-b border-mdt-border flex items-center justify-between">
        <p className="text-xs text-mdt-text-muted">{onDutyOfficers.length} officer{onDutyOfficers.length !== 1 ? 's' : ''} currently on duty</p>

        {/* Own status changer */}
        <div className="relative">
          <button
            onClick={() => setShowStatusDropdown(!showStatusDropdown)}
            className="flex items-center gap-2 px-3 py-1.5 bg-mdt-bg-secondary border border-mdt-border rounded text-xs font-medium text-mdt-text-primary hover:bg-mdt-bg-hover transition-colors"
          >
            <span className="text-mdt-text-muted">My Status:</span>
            <span>{officerData?.isOnDuty ? 'On Duty' : 'Off Duty'}</span>
            <ChevronDown className="w-3 h-3" />
          </button>
          {showStatusDropdown && (
            <div className="absolute right-0 top-full mt-1 w-40 bg-mdt-bg-primary border border-mdt-border rounded-md shadow-xl z-10">
              {Object.entries(statusColors).map(([key, val]) => (
                <button
                  key={key}
                  onClick={() => handleStatusChange(key)}
                  className="w-full flex items-center gap-2 px-3 py-2 hover:bg-mdt-bg-hover transition-colors text-left"
                >
                  <span className={`w-2 h-2 rounded-full ${val.dot}`} />
                  <span className="text-xs text-mdt-text-primary">{val.label}</span>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="flex-1 overflow-y-auto">
        {onDutyOfficers.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-mdt-text-muted">
            <Users className="w-10 h-10 opacity-50 mb-3" />
            <p className="text-sm">No officers on duty</p>
          </div>
        ) : (
          <div className="divide-y divide-mdt-border/30">
            {onDutyOfficers.map((officer) => {
              const sc = statusColors[officer.status] || statusColors.available
              return (
                <div key={officer.source} className="flex items-center gap-4 px-5 py-3 hover:bg-mdt-bg-hover transition-colors">
                  <div className={`w-10 h-10 rounded-full flex items-center justify-center ${sc.bg}`}>
                    <Shield className="w-5 h-5 text-mdt-accent" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-mdt-text-primary">{officer.name}</p>
                    <p className="text-xs text-mdt-text-muted">{officer.rank}</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={`w-2.5 h-2.5 rounded-full ${sc.dot}`} />
                    <span className="text-xs font-medium text-mdt-text-secondary">{sc.label}</span>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}

function RosterTab({ isBoss }: { isBoss: boolean }) {
  const { officerRoster } = useMDTStore()
  const [selectedOfficer, setSelectedOfficer] = useState<OfficerRoster | null>(null)
  const [newGrade, setNewGrade] = useState<number>(0)
  const [confirmFire, setConfirmFire] = useState(false)
  const [actionLoading, setActionLoading] = useState(false)

  const handleSetGrade = () => {
    if (!selectedOfficer) return
    setActionLoading(true)
    fetchNui('setOfficerGrade', { citizenid: selectedOfficer.citizenid, grade: newGrade })
    setTimeout(() => {
      fetchNui('getOfficerRoster')
      setActionLoading(false)
      setSelectedOfficer(null)
    }, 1000)
  }

  const handleFire = () => {
    if (!selectedOfficer) return
    setActionLoading(true)
    fetchNui('fireOfficer', { citizenid: selectedOfficer.citizenid })
    setTimeout(() => {
      fetchNui('getOfficerRoster')
      setActionLoading(false)
      setSelectedOfficer(null)
      setConfirmFire(false)
    }, 1000)
  }

  const ranks = [
    { grade: 0, name: 'Cadet' },
    { grade: 1, name: 'Officer I' },
    { grade: 2, name: 'Officer II' },
    { grade: 3, name: 'Officer III' },
    { grade: 4, name: 'Corporal' },
    { grade: 5, name: 'Sergeant' },
    { grade: 6, name: 'Lieutenant' },
    { grade: 7, name: 'Captain' },
    { grade: 8, name: 'Commander' },
    { grade: 9, name: 'Chief of Police' },
  ]

  return (
    <div className="h-full flex gap-4">
      {/* Roster Table */}
      <div className="flex-1 bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-hidden flex flex-col">
        <div className="flex-1 overflow-y-auto">
          {officerRoster.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-full text-mdt-text-muted">
              <Users className="w-10 h-10 opacity-50 mb-3" />
              <p className="text-sm">No officers in roster</p>
            </div>
          ) : (
            <table className="w-full">
              <thead className="sticky top-0 bg-mdt-bg-tertiary">
                <tr className="text-left text-[10px] font-semibold text-mdt-text-muted uppercase tracking-wide">
                  <th className="px-4 py-2.5">Name</th>
                  <th className="px-4 py-2.5">Rank</th>
                  <th className="px-4 py-2.5">Grade</th>
                  <th className="px-4 py-2.5 text-center">Online</th>
                  <th className="px-4 py-2.5 text-center">On Duty</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-mdt-border/30">
                {officerRoster.map((officer) => (
                  <tr
                    key={officer.citizenid}
                    onClick={() => {
                      setSelectedOfficer(officer)
                      setNewGrade(officer.grade)
                      setConfirmFire(false)
                    }}
                    className={`hover:bg-mdt-bg-hover transition-colors cursor-pointer ${selectedOfficer?.citizenid === officer.citizenid ? 'bg-mdt-bg-hover' : ''}`}
                  >
                    <td className="px-4 py-2.5 text-sm font-medium text-mdt-text-primary">{officer.name}</td>
                    <td className="px-4 py-2.5 text-sm text-mdt-text-secondary">{officer.rank}</td>
                    <td className="px-4 py-2.5 text-sm text-mdt-text-muted">{officer.grade}</td>
                    <td className="px-4 py-2.5 text-center">
                      <span className={`inline-block w-2.5 h-2.5 rounded-full ${officer.isOnline ? 'bg-mdt-success' : 'bg-mdt-text-muted/30'}`} />
                    </td>
                    <td className="px-4 py-2.5 text-center">
                      {officer.isOnDuty ? (
                        <span className="px-2 py-0.5 rounded text-[10px] font-bold uppercase bg-mdt-success/20 text-mdt-success">On Duty</span>
                      ) : (
                        <span className="text-xs text-mdt-text-muted">-</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {/* Detail Panel */}
      <AnimatePresence mode="wait">
        {selectedOfficer && (
          <motion.div
            key={selectedOfficer.citizenid}
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 20 }}
            className="w-[280px] bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-hidden flex flex-col shrink-0"
          >
            <div className="px-4 py-3 bg-mdt-bg-tertiary border-b border-mdt-border">
              <h4 className="text-sm font-semibold text-mdt-text-primary">{selectedOfficer.name}</h4>
              <p className="text-xs text-mdt-text-muted">{selectedOfficer.rank} (Grade {selectedOfficer.grade})</p>
            </div>

            <div className="flex-1 overflow-y-auto p-4 space-y-4">
              {/* Info */}
              <div className="space-y-2">
                <div className="flex justify-between text-xs">
                  <span className="text-mdt-text-muted">Citizen ID</span>
                  <span className="text-mdt-text-primary font-mono">{selectedOfficer.citizenid}</span>
                </div>
                <div className="flex justify-between text-xs">
                  <span className="text-mdt-text-muted">Status</span>
                  <span className="text-mdt-text-primary">{selectedOfficer.isOnline ? (selectedOfficer.isOnDuty ? 'On Duty' : 'Online') : 'Offline'}</span>
                </div>
              </div>

              {/* Boss Actions */}
              {isBoss && (
                <div className="border-t border-mdt-border pt-4 space-y-3">
                  <p className="text-[10px] font-semibold text-mdt-text-muted uppercase tracking-wide">Management</p>

                  {/* Grade Selector */}
                  <div>
                    <label className="block text-xs text-mdt-text-secondary mb-1">Set Rank</label>
                    <select
                      value={newGrade}
                      onChange={(e) => setNewGrade(parseInt(e.target.value))}
                      className="w-full px-3 py-2 bg-mdt-bg-tertiary border border-mdt-border rounded text-sm text-mdt-text-primary outline-none focus:border-mdt-accent"
                    >
                      {ranks.map((r) => (
                        <option key={r.grade} value={r.grade}>
                          {r.grade} - {r.name}
                        </option>
                      ))}
                    </select>
                    <button
                      onClick={handleSetGrade}
                      disabled={actionLoading || newGrade === selectedOfficer.grade}
                      className="mt-2 w-full py-2 bg-mdt-accent hover:bg-mdt-accent-hover rounded text-xs font-semibold text-white transition-colors disabled:opacity-50"
                    >
                      {actionLoading ? <Loader2 className="w-3 h-3 animate-spin mx-auto" /> : 'Update Rank'}
                    </button>
                  </div>

                  {/* Fire */}
                  <div>
                    {!confirmFire ? (
                      <button
                        onClick={() => setConfirmFire(true)}
                        className="w-full py-2 bg-mdt-danger/20 hover:bg-mdt-danger/30 border border-mdt-danger/30 rounded text-xs font-semibold text-mdt-danger transition-colors"
                      >
                        Terminate Officer
                      </button>
                    ) : (
                      <div className="space-y-2">
                        <p className="text-xs text-mdt-danger font-medium">Are you sure? This cannot be undone.</p>
                        <div className="flex gap-2">
                          <button
                            onClick={handleFire}
                            disabled={actionLoading}
                            className="flex-1 py-2 bg-mdt-danger hover:bg-mdt-danger/80 rounded text-xs font-semibold text-white transition-colors disabled:opacity-50"
                          >
                            Confirm Fire
                          </button>
                          <button
                            onClick={() => setConfirmFire(false)}
                            className="flex-1 py-2 bg-mdt-bg-tertiary border border-mdt-border rounded text-xs font-semibold text-mdt-text-secondary hover:bg-mdt-bg-hover transition-colors"
                          >
                            Cancel
                          </button>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
