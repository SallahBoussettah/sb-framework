import { useState, useEffect } from 'react'
import { Search, FileText, Plus, Loader2, X, Save, UserPlus } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { useMDTStore } from '../store/mdtStore'
import { fetchNui } from '../utils/nui'
import SearchPopup from '../components/SearchPopup'
import type { Report } from '../types'

export default function Reports() {
  const [searchQuery, setSearchQuery] = useState('')
  const {
    reports,
    reportsFilter,
    setReportsFilter,
    selectedReport,
    setSelectedReport,
    reportEditorOpen,
    setReportEditorOpen,
  } = useMDTStore()

  // Load reports on mount
  useEffect(() => {
    fetchNui('filterReports', { filter: reportsFilter })
  }, [reportsFilter])

  const filteredReports = searchQuery
    ? reports.filter(
        (r) =>
          r.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
          r.authorName.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : reports

  const handleCreateReport = () => {
    fetchNui('createReport')
  }

  const handleSelectReport = (report: Report) => {
    setSelectedReport(report)
    setReportEditorOpen(true)
  }

  const handleCloseEditor = () => {
    setReportEditorOpen(false)
    setSelectedReport(null)
  }

  const filters: { id: 'all' | 'open' | 'closed'; label: string }[] = [
    { id: 'all', label: 'All' },
    { id: 'open', label: 'Open' },
    { id: 'closed', label: 'Closed' },
  ]

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="absolute inset-0 p-6 overflow-hidden flex flex-col"
    >
      <div className="flex items-center justify-between mb-5">
        <div>
          <h2 className="font-heading text-2xl tracking-wider text-mdt-text-primary">Incident Reports</h2>
          <p className="text-sm text-mdt-text-secondary mt-1">View and create incident reports</p>
        </div>
        <button
          onClick={handleCreateReport}
          className="flex items-center gap-2 px-4 py-2.5 bg-mdt-accent hover:bg-mdt-accent-hover rounded-md text-sm font-semibold text-white transition-colors"
        >
          <Plus className="w-4 h-4" />
          New Report
        </button>
      </div>

      <div className="flex-1 flex gap-5 min-h-0">
        {/* Reports List */}
        <div className="w-[320px] flex flex-col gap-3 shrink-0">
          {/* Search */}
          <div className="flex gap-2">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search reports..."
              className="flex-1 px-4 py-3 bg-mdt-bg-secondary border border-mdt-border rounded-md text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors"
            />
            <button className="w-11 h-11 bg-mdt-accent hover:bg-mdt-accent-hover rounded-md flex items-center justify-center text-white transition-colors">
              <Search className="w-[18px] h-[18px]" />
            </button>
          </div>

          {/* Filters */}
          <div className="flex gap-2">
            {filters.map((filter) => (
              <button
                key={filter.id}
                onClick={() => setReportsFilter(filter.id)}
                className={`px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
                  reportsFilter === filter.id
                    ? 'bg-mdt-accent/20 border border-mdt-accent text-mdt-accent'
                    : 'bg-mdt-bg-tertiary border border-mdt-border text-mdt-text-secondary hover:bg-mdt-bg-hover'
                }`}
              >
                {filter.label}
              </button>
            ))}
          </div>

          {/* Results */}
          <div className="flex-1 bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-y-auto">
            {filteredReports.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-full text-mdt-text-muted">
                <FileText className="w-10 h-10 opacity-50 mb-3" />
                <p className="text-sm">No reports found</p>
              </div>
            ) : (
              <div className="divide-y divide-mdt-border/50">
                {filteredReports.map((report) => (
                  <button
                    key={report.id}
                    onClick={() => handleSelectReport(report)}
                    className={`w-full flex items-start gap-3 px-4 py-3 hover:bg-mdt-bg-hover transition-colors text-left ${
                      selectedReport?.id === report.id ? 'bg-mdt-bg-hover' : ''
                    }`}
                  >
                    <div
                      className={`w-9 h-9 rounded-lg flex items-center justify-center shrink-0 ${
                        report.status === 'open'
                          ? 'bg-mdt-success/15 text-mdt-success'
                          : report.status === 'pending'
                          ? 'bg-mdt-warning/15 text-mdt-warning'
                          : 'bg-mdt-bg-tertiary text-mdt-text-muted'
                      }`}
                    >
                      <FileText className="w-5 h-5" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-[13px] font-semibold text-mdt-text-primary truncate">
                        #{report.id} - {report.title}
                      </p>
                      <p className="text-[11px] text-mdt-text-muted">
                        by {report.authorName} &bull; {report.createdAt}
                      </p>
                    </div>
                    <span
                      className={`px-2 py-0.5 rounded text-[10px] font-semibold uppercase shrink-0 ${
                        report.status === 'open'
                          ? 'bg-mdt-success/15 text-mdt-success'
                          : report.status === 'pending'
                          ? 'bg-mdt-warning/15 text-mdt-warning'
                          : 'bg-mdt-bg-tertiary text-mdt-text-muted'
                      }`}
                    >
                      {report.status}
                    </span>
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Report Editor / Detail */}
        <div className="flex-1 bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-hidden">
          <AnimatePresence mode="wait">
            {reportEditorOpen && selectedReport ? (
              <ReportEditor
                key={`editor-${selectedReport.id}`}
                report={selectedReport}
                onClose={handleCloseEditor}
              />
            ) : (
              <motion.div
                key="empty"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="flex flex-col items-center justify-center h-full text-mdt-text-muted"
              >
                <FileText className="w-16 h-16 opacity-50 mb-4" />
                <p className="text-base">Select a report to view details</p>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </motion.div>
  )
}

interface ReportEditorProps {
  report: Report
  onClose: () => void
}

function ReportEditor({ report, onClose }: ReportEditorProps) {
  const [title, setTitle] = useState(report.title)
  const [description, setDescription] = useState(report.description || '')
  const [isSaving, setIsSaving] = useState(false)
  const { officerData, updateReportStatus } = useMDTStore()

  // Search popup state
  const [searchPopup, setSearchPopup] = useState<{ type: 'citizen' | 'vehicle'; field: 'suspects' | 'victims' | 'vehicles' } | null>(null)
  const [evidenceInput, setEvidenceInput] = useState('')

  const handleSave = async () => {
    setIsSaving(true)
    await fetchNui('updateReport', {
      id: report.id,
      title,
      description,
    })
    setIsSaving(false)
  }

  const handleAddSuspect = (citizenId: string, name: string) => {
    fetchNui('addReportSuspect', { reportId: report.id, citizenId, citizenName: name })
    setSearchPopup(null)
  }

  const handleAddVictim = (_citizenId: string, name: string) => {
    void _citizenId
    fetchNui('addReportVictim', { reportId: report.id, citizenName: name })
    setSearchPopup(null)
  }

  const handleAddVehicle = (_plateId: string, name: string) => {
    void _plateId
    fetchNui('addReportVehicle', { reportId: report.id, plate: name })
    setSearchPopup(null)
  }

  const handleAddEvidence = () => {
    if (!evidenceInput.trim()) return
    fetchNui('addReportEvidence', { reportId: report.id, text: evidenceInput.trim() })
    setEvidenceInput('')
  }

  const handleAddSelf = () => {
    if (!officerData) return
    fetchNui('addReportOfficer', { reportId: report.id, officerName: officerData.name })
  }

  const handleRemoveItem = (field: string, index: number) => {
    fetchNui('removeReportItem', { reportId: report.id, fieldName: field, index: index + 1 }) // Lua is 1-indexed
  }

  const handleStatusChange = (status: 'open' | 'pending' | 'closed') => {
    fetchNui('updateReportStatus', { reportId: report.id, status })
    updateReportStatus(report.id, status)
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="h-full flex flex-col"
    >
      {/* Header */}
      <div className="flex items-center justify-between px-5 py-4 bg-mdt-bg-tertiary border-b border-mdt-border">
        <div>
          <h3 className="text-lg font-semibold text-mdt-text-primary">
            Report #{report.id}
          </h3>
          <p className="text-xs text-mdt-text-muted">
            Created by {report.authorName} on {report.createdAt}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={handleSave}
            disabled={isSaving}
            className="flex items-center gap-2 px-4 py-2 bg-mdt-accent hover:bg-mdt-accent-hover rounded-md text-xs font-semibold text-white transition-colors disabled:opacity-50"
          >
            {isSaving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
            Save
          </button>
          <button
            onClick={onClose}
            className="w-8 h-8 flex items-center justify-center rounded-md text-mdt-text-secondary hover:bg-mdt-bg-hover transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto p-5">
        <div className="space-y-5">
          {/* Title */}
          <div>
            <label className="block text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-2">
              Report Title
            </label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full px-4 py-3 bg-mdt-bg-tertiary border border-mdt-border rounded-md text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors"
            />
          </div>

          {/* Description */}
          <div>
            <label className="block text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-2">
              Description
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={6}
              className="w-full px-4 py-3 bg-mdt-bg-tertiary border border-mdt-border rounded-md text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors resize-none"
              placeholder="Enter incident details..."
            />
          </div>

          {/* Involved Parties */}
          <div className="grid grid-cols-2 gap-4">
            {/* Suspects */}
            <ReportItemList
              label="Suspects"
              items={report.suspects}
              onAdd={() => setSearchPopup({ type: 'citizen', field: 'suspects' })}
              onRemove={(i) => handleRemoveItem('suspects', i)}
            />

            {/* Victims */}
            <ReportItemList
              label="Victims"
              items={report.victims}
              onAdd={() => setSearchPopup({ type: 'citizen', field: 'victims' })}
              onRemove={(i) => handleRemoveItem('victims', i)}
            />

            {/* Vehicles */}
            <ReportItemList
              label="Vehicles"
              items={report.vehicles}
              onAdd={() => setSearchPopup({ type: 'vehicle', field: 'vehicles' })}
              onRemove={(i) => handleRemoveItem('vehicles', i)}
            />

            {/* Officers */}
            <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
              <div className="flex items-center justify-between mb-3">
                <h4 className="text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide">
                  Officers ({report.officers.length})
                </h4>
                <div className="flex gap-1">
                  <button
                    onClick={handleAddSelf}
                    title="Add Self"
                    className="w-6 h-6 flex items-center justify-center rounded bg-mdt-accent/20 text-mdt-accent hover:bg-mdt-accent/30 transition-colors"
                  >
                    <UserPlus className="w-3 h-3" />
                  </button>
                </div>
              </div>
              {report.officers.length === 0 ? (
                <p className="text-sm text-mdt-text-muted italic">No officers added</p>
              ) : (
                <div className="space-y-1.5">
                  {report.officers.map((item, i) => (
                    <div key={i} className="flex items-center justify-between group">
                      <span className="text-sm text-mdt-text-primary">{item}</span>
                      <button
                        onClick={() => handleRemoveItem('officers', i)}
                        className="w-5 h-5 flex items-center justify-center rounded text-mdt-text-muted hover:text-mdt-danger hover:bg-mdt-danger/10 opacity-0 group-hover:opacity-100 transition-all"
                      >
                        <X className="w-3 h-3" />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Evidence */}
          <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
            <div className="flex items-center justify-between mb-3">
              <h4 className="text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide">
                Evidence ({report.evidence.length})
              </h4>
            </div>
            {report.evidence.length > 0 && (
              <div className="space-y-1.5 mb-3">
                {report.evidence.map((item, i) => (
                  <div key={i} className="flex items-center justify-between group">
                    <span className="text-sm text-mdt-text-primary">{item}</span>
                    <button
                      onClick={() => handleRemoveItem('evidence', i)}
                      className="w-5 h-5 flex items-center justify-center rounded text-mdt-text-muted hover:text-mdt-danger hover:bg-mdt-danger/10 opacity-0 group-hover:opacity-100 transition-all"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </div>
                ))}
              </div>
            )}
            <div className="flex gap-2">
              <input
                type="text"
                value={evidenceInput}
                onChange={(e) => setEvidenceInput(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleAddEvidence()}
                placeholder="Add evidence entry..."
                className="flex-1 px-3 py-2 bg-mdt-bg-secondary border border-mdt-border rounded text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors"
              />
              <button
                onClick={handleAddEvidence}
                disabled={!evidenceInput.trim()}
                className="px-3 py-2 bg-mdt-accent hover:bg-mdt-accent-hover rounded text-xs font-semibold text-white transition-colors disabled:opacity-50"
              >
                Add
              </button>
            </div>
          </div>

          {/* Status */}
          <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
            <h4 className="text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide mb-3">
              Status
            </h4>
            <div className="flex gap-2">
              {(['open', 'pending', 'closed'] as const).map((status) => (
                <button
                  key={status}
                  onClick={() => handleStatusChange(status)}
                  className={`px-4 py-2 rounded-md text-xs font-semibold uppercase transition-colors ${
                    report.status === status
                      ? status === 'open'
                        ? 'bg-mdt-success text-white'
                        : status === 'pending'
                        ? 'bg-mdt-warning text-white'
                        : 'bg-mdt-text-muted text-white'
                      : 'bg-mdt-bg-secondary border border-mdt-border text-mdt-text-secondary hover:bg-mdt-bg-hover'
                  }`}
                >
                  {status}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Search Popup */}
      <AnimatePresence>
        {searchPopup && (
          <SearchPopup
            type={searchPopup.type}
            onSelect={(id, name) => {
              if (searchPopup.field === 'suspects') handleAddSuspect(id, name)
              else if (searchPopup.field === 'victims') handleAddVictim(id, name)
              else if (searchPopup.field === 'vehicles') handleAddVehicle(id, name)
            }}
            onClose={() => setSearchPopup(null)}
          />
        )}
      </AnimatePresence>
    </motion.div>
  )
}

// Reusable list component for report sections
function ReportItemList({ label, items, onAdd, onRemove }: {
  label: string
  items: string[]
  onAdd: () => void
  onRemove: (index: number) => void
}) {
  return (
    <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
      <div className="flex items-center justify-between mb-3">
        <h4 className="text-xs font-semibold text-mdt-text-secondary uppercase tracking-wide">
          {label} ({items.length})
        </h4>
        <button
          onClick={onAdd}
          className="w-6 h-6 flex items-center justify-center rounded bg-mdt-accent/20 text-mdt-accent hover:bg-mdt-accent/30 transition-colors"
        >
          <Plus className="w-3 h-3" />
        </button>
      </div>
      {items.length === 0 ? (
        <p className="text-sm text-mdt-text-muted italic">No {label.toLowerCase()} added</p>
      ) : (
        <div className="space-y-1.5">
          {items.map((item, i) => (
            <div key={i} className="flex items-center justify-between group">
              <span className="text-sm text-mdt-text-primary">{item}</span>
              <button
                onClick={() => onRemove(i)}
                className="w-5 h-5 flex items-center justify-center rounded text-mdt-text-muted hover:text-mdt-danger hover:bg-mdt-danger/10 opacity-0 group-hover:opacity-100 transition-all"
              >
                <X className="w-3 h-3" />
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
