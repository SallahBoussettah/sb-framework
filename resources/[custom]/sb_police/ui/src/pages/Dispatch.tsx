import { useState } from 'react'
import { Radio, MapPin, Clock, Users, Navigation, Check, X, AlertTriangle } from 'lucide-react'
import { motion } from 'framer-motion'
import { useMDTStore } from '../store/mdtStore'
import { fetchNui } from '../utils/nui'
import type { Alert } from '../types'

const priorityColors = {
  high: { bg: 'bg-mdt-danger/15', text: 'text-mdt-danger', border: 'border-mdt-danger/30', badge: 'bg-mdt-danger' },
  medium: { bg: 'bg-mdt-warning/15', text: 'text-mdt-warning', border: 'border-mdt-warning/30', badge: 'bg-mdt-warning' },
  low: { bg: 'bg-mdt-accent/15', text: 'text-mdt-accent', border: 'border-mdt-accent/30', badge: 'bg-mdt-accent' },
}

function timeAgo(timestamp: number): string {
  const seconds = Math.floor((Date.now() / 1000) - timestamp)
  if (seconds < 60) return 'Just now'
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes}m ago`
  const hours = Math.floor(minutes / 60)
  return `${hours}h ${minutes % 60}m ago`
}

export default function Dispatch() {
  const { alerts, selectedAlert, setSelectedAlert, removeAlert, updateAlertAccepted } = useMDTStore()
  const [filter, setFilter] = useState<'all' | 'high' | 'medium' | 'low'>('all')

  const filteredAlerts = filter === 'all' ? alerts : alerts.filter((a) => a.priority === filter)

  const handleAccept = (alert: Alert) => {
    fetchNui('acceptAlert', { alertId: alert.id, coords: alert.coords })
    updateAlertAccepted(alert.id, true)
  }

  const handleDecline = (alertId: string) => {
    fetchNui('declineAlert', { alertId })
    removeAlert(alertId)
  }

  const handleGPS = (alert: Alert) => {
    fetchNui('setAlertGPS', { coords: alert.coords })
  }

  const handleResolve = (alertId: string) => {
    fetchNui('resolveAlert', { alertId })
    if (selectedAlert?.id === alertId) setSelectedAlert(null)
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="absolute inset-0 flex flex-col"
    >
      {/* Header */}
      <div className="px-6 pt-6 pb-4">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="font-heading text-2xl tracking-wider text-mdt-text-primary">Dispatch Center</h2>
            <p className="text-sm text-mdt-text-secondary mt-1">Active alerts and dispatch management</p>
          </div>
          <div className="flex items-center gap-2">
            {(['all', 'high', 'medium', 'low'] as const).map((f) => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${
                  filter === f
                    ? 'bg-mdt-accent/20 text-mdt-accent'
                    : 'bg-mdt-bg-tertiary text-mdt-text-secondary hover:bg-mdt-bg-hover'
                }`}
              >
                {f === 'all' ? 'All' : f.charAt(0).toUpperCase() + f.slice(1)}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 flex gap-5 px-6 pb-6 overflow-hidden">
        {/* Alert List */}
        <div className="flex-[3] overflow-y-auto space-y-2 pr-1">
          {filteredAlerts.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 text-mdt-text-muted">
              <Radio className="w-12 h-12 opacity-50 mb-3" />
              <p className="text-sm">No active alerts</p>
              <p className="text-xs mt-1">Alerts from dispatch will appear here</p>
            </div>
          ) : (
            filteredAlerts.map((alert) => {
              const colors = priorityColors[alert.priority] || priorityColors.low
              const isSelected = selectedAlert?.id === alert.id

              return (
                <div
                  key={alert.id}
                  onClick={() => setSelectedAlert(alert)}
                  className={`p-4 rounded-lg border cursor-pointer transition-all ${
                    isSelected
                      ? `${colors.bg} ${colors.border} border-2`
                      : `bg-mdt-bg-tertiary border-mdt-border hover:border-mdt-accent/30`
                  }`}
                >
                  <div className="flex items-start justify-between mb-2">
                    <div className="flex items-center gap-2.5">
                      <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase text-white ${colors.badge}`}>
                        {alert.priority}
                      </span>
                      <h4 className="text-sm font-semibold text-mdt-text-primary">{alert.title}</h4>
                    </div>
                    <span className="text-[11px] text-mdt-text-muted shrink-0">{alert.time}</span>
                  </div>

                  <div className="flex items-center gap-4 text-xs text-mdt-text-secondary mb-3">
                    <span className="flex items-center gap-1">
                      <MapPin className="w-3 h-3" />
                      {alert.location}
                    </span>
                    {alert.caller && (
                      <span className="flex items-center gap-1">
                        <Users className="w-3 h-3" />
                        {alert.caller}
                      </span>
                    )}
                    {alert.responderCount !== undefined && alert.responderCount > 0 && (
                      <span className="flex items-center gap-1 text-mdt-accent">
                        <Radio className="w-3 h-3" />
                        {alert.responderCount} responding
                      </span>
                    )}
                  </div>

                  <div className="flex items-center gap-2">
                    {!alert.isAccepted ? (
                      <>
                        <button
                          onClick={(e) => { e.stopPropagation(); handleAccept(alert) }}
                          className="flex items-center gap-1.5 px-3 py-1.5 bg-mdt-success/15 text-mdt-success border border-mdt-success/30 rounded-md text-[11px] font-semibold hover:bg-mdt-success/25 transition-colors"
                        >
                          <Check className="w-3 h-3" />
                          Accept
                        </button>
                        <button
                          onClick={(e) => { e.stopPropagation(); handleDecline(alert.id) }}
                          className="flex items-center gap-1.5 px-3 py-1.5 bg-mdt-bg-secondary text-mdt-text-secondary border border-mdt-border rounded-md text-[11px] font-semibold hover:bg-mdt-bg-hover transition-colors"
                        >
                          <X className="w-3 h-3" />
                          Decline
                        </button>
                      </>
                    ) : (
                      <span className="flex items-center gap-1.5 px-3 py-1.5 bg-mdt-success/10 text-mdt-success rounded-md text-[11px] font-semibold">
                        <Check className="w-3 h-3" />
                        Accepted
                      </span>
                    )}
                    {alert.coords && (
                      <button
                        onClick={(e) => { e.stopPropagation(); handleGPS(alert) }}
                        className="flex items-center gap-1.5 px-3 py-1.5 bg-mdt-accent/15 text-mdt-accent border border-mdt-accent/30 rounded-md text-[11px] font-semibold hover:bg-mdt-accent/25 transition-colors"
                      >
                        <Navigation className="w-3 h-3" />
                        GPS
                      </button>
                    )}
                  </div>
                </div>
              )
            })
          )}
        </div>

        {/* Detail Panel */}
        <div className="flex-[2] bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-hidden flex flex-col">
          {selectedAlert ? (
            <>
              <div className={`px-5 py-4 border-b border-mdt-border ${priorityColors[selectedAlert.priority]?.bg || ''}`}>
                <div className="flex items-center gap-2 mb-2">
                  <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase text-white ${priorityColors[selectedAlert.priority]?.badge}`}>
                    {selectedAlert.priority}
                  </span>
                  {selectedAlert.type && (
                    <span className="px-2 py-0.5 rounded bg-mdt-bg-hover text-[10px] font-medium text-mdt-text-secondary uppercase">
                      {selectedAlert.type}
                    </span>
                  )}
                </div>
                <h3 className="text-lg font-semibold text-mdt-text-primary">{selectedAlert.title}</h3>
              </div>

              <div className="flex-1 p-5 space-y-4">
                <DetailRow icon={<MapPin className="w-4 h-4" />} label="Location" value={selectedAlert.location} />
                <DetailRow icon={<Clock className="w-4 h-4" />} label="Time" value={`${selectedAlert.time} (${timeAgo(selectedAlert.timestamp)})`} />
                {selectedAlert.caller && <DetailRow icon={<Users className="w-4 h-4" />} label="Caller" value={selectedAlert.caller} />}
                <DetailRow icon={<Radio className="w-4 h-4" />} label="Responders" value={`${selectedAlert.responderCount || 0}`} />
                <DetailRow
                  icon={<Navigation className="w-4 h-4" />}
                  label="Coordinates"
                  value={selectedAlert.coords ? `${selectedAlert.coords.x.toFixed(1)}, ${selectedAlert.coords.y.toFixed(1)}` : 'Not available'}
                />
              </div>

              <div className="p-4 border-t border-mdt-border flex gap-2">
                {selectedAlert.coords && (
                  <button
                    onClick={() => handleGPS(selectedAlert)}
                    className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-mdt-accent hover:bg-mdt-accent-hover rounded-md text-xs font-semibold text-white transition-colors"
                  >
                    <Navigation className="w-4 h-4" />
                    Set GPS
                  </button>
                )}
                {!selectedAlert.isAccepted && (
                  <button
                    onClick={() => handleAccept(selectedAlert)}
                    className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-mdt-success/15 border border-mdt-success text-mdt-success rounded-md text-xs font-semibold hover:bg-mdt-success/25 transition-colors"
                  >
                    <Check className="w-4 h-4" />
                    Accept
                  </button>
                )}
                <button
                  onClick={() => handleResolve(selectedAlert.id)}
                  className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-mdt-bg-tertiary border border-mdt-border rounded-md text-xs font-semibold text-mdt-text-secondary hover:bg-mdt-bg-hover transition-colors"
                >
                  <X className="w-4 h-4" />
                  Resolve
                </button>
              </div>
            </>
          ) : (
            <div className="flex-1 flex flex-col items-center justify-center text-mdt-text-muted">
              <AlertTriangle className="w-12 h-12 opacity-30 mb-3" />
              <p className="text-sm font-medium">No Alert Selected</p>
              <p className="text-xs mt-1">Click an alert to view details</p>
            </div>
          )}
        </div>
      </div>
    </motion.div>
  )
}

function DetailRow({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div className="flex items-center gap-3">
      <span className="text-mdt-text-muted">{icon}</span>
      <div>
        <p className="text-[11px] text-mdt-text-muted uppercase">{label}</p>
        <p className="text-sm font-medium text-mdt-text-primary">{value}</p>
      </div>
    </div>
  )
}
