import { useState, useEffect } from 'react'
import { Clock, Calendar, Timer, Users } from 'lucide-react'
import { motion } from 'framer-motion'
import { useMDTStore } from '../store/mdtStore'
import { fetchNui } from '../utils/nui'

type Tab = 'my-stats' | 'all-officers'

function formatDuration(minutes: number): string {
  const h = Math.floor(minutes / 60)
  const m = minutes % 60
  return `${h}h ${m}m`
}

export default function TimeClock() {
  const [activeTab, setActiveTab] = useState<Tab>('my-stats')
  const { dutyStats, officerData, isOnDuty } = useMDTStore()
  const [currentShift, setCurrentShift] = useState(dutyStats?.currentShiftMinutes ?? 0)

  const isBoss = (officerData?.grade ?? 0) >= 5

  // Fetch stats on mount AND when duty status changes
  useEffect(() => {
    fetchNui('getDutyStats')
  }, [isOnDuty])

  // Live counter for current shift
  useEffect(() => {
    if (!isOnDuty) {
      setCurrentShift(0)
      return
    }
    setCurrentShift(dutyStats?.currentShiftMinutes ?? 0)
    const interval = setInterval(() => {
      setCurrentShift((prev) => prev + 1)
    }, 60000) // Update every minute
    return () => clearInterval(interval)
  }, [isOnDuty, dutyStats?.currentShiftMinutes])

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="absolute inset-0 p-6 overflow-hidden flex flex-col">
      <div className="mb-5">
        <h2 className="font-heading text-2xl tracking-wider text-mdt-text-primary">Time Clock</h2>
        <p className="text-sm text-mdt-text-secondary mt-1">Track your duty hours and view history</p>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-3 gap-4 mb-5">
        <StatCard
          icon={Calendar}
          label="This Week"
          value={formatDuration(dutyStats?.totalMinutesWeek ?? 0)}
          color="text-mdt-accent"
          bg="bg-mdt-accent/10"
        />
        <StatCard
          icon={Clock}
          label="This Month"
          value={formatDuration(dutyStats?.totalMinutesMonth ?? 0)}
          color="text-mdt-success"
          bg="bg-mdt-success/10"
        />
        <StatCard
          icon={Timer}
          label="Current Shift"
          value={isOnDuty ? formatDuration(currentShift) : 'Off Duty'}
          color={isOnDuty ? 'text-mdt-warning' : 'text-mdt-text-muted'}
          bg={isOnDuty ? 'bg-mdt-warning/10' : 'bg-mdt-bg-secondary'}
          pulse={isOnDuty}
        />
      </div>

      {/* Tabs */}
      {isBoss && (
        <div className="flex gap-2 mb-4">
          <button
            onClick={() => setActiveTab('my-stats')}
            className={`flex items-center gap-2 px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              activeTab === 'my-stats'
                ? 'bg-mdt-accent/20 border border-mdt-accent text-mdt-accent'
                : 'bg-mdt-bg-secondary border border-mdt-border text-mdt-text-secondary hover:bg-mdt-bg-hover'
            }`}
          >
            My History
          </button>
          <button
            onClick={() => {
              setActiveTab('all-officers')
              fetchNui('getAllOfficersDuty')
            }}
            className={`flex items-center gap-2 px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              activeTab === 'all-officers'
                ? 'bg-mdt-accent/20 border border-mdt-accent text-mdt-accent'
                : 'bg-mdt-bg-secondary border border-mdt-border text-mdt-text-secondary hover:bg-mdt-bg-hover'
            }`}
          >
            <Users className="w-4 h-4" />
            All Officers
          </button>
        </div>
      )}

      {/* Content */}
      <div className="flex-1 min-h-0 overflow-hidden">
        {activeTab === 'my-stats' ? <MyHistoryTab /> : <AllOfficersTab />}
      </div>
    </motion.div>
  )
}

function StatCard({ icon: Icon, label, value, color, bg, pulse }: {
  icon: typeof Clock
  label: string
  value: string
  color: string
  bg: string
  pulse?: boolean
}) {
  return (
    <div className={`${bg} border border-mdt-border rounded-lg p-4 flex items-center gap-4`}>
      <div className={`w-12 h-12 rounded-lg flex items-center justify-center ${bg} ${color}`}>
        <Icon className="w-6 h-6" />
      </div>
      <div>
        <p className="text-xs font-semibold text-mdt-text-muted uppercase tracking-wide">{label}</p>
        <p className={`text-xl font-bold ${color} ${pulse ? 'animate-pulse' : ''}`}>{value}</p>
      </div>
    </div>
  )
}

function MyHistoryTab() {
  const { dutyStats } = useMDTStore()
  const records = dutyStats?.records ?? []

  return (
    <div className="h-full bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-hidden flex flex-col">
      <div className="flex-1 overflow-y-auto">
        {records.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-mdt-text-muted">
            <Clock className="w-10 h-10 opacity-50 mb-3" />
            <p className="text-sm">No duty records found</p>
          </div>
        ) : (
          <table className="w-full">
            <thead className="sticky top-0 bg-mdt-bg-tertiary">
              <tr className="text-left text-[10px] font-semibold text-mdt-text-muted uppercase tracking-wide">
                <th className="px-4 py-2.5">Date</th>
                <th className="px-4 py-2.5">Clock In</th>
                <th className="px-4 py-2.5">Clock Out</th>
                <th className="px-4 py-2.5">Duration</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-mdt-border/30">
              {records.map((r) => (
                <tr key={r.id} className="hover:bg-mdt-bg-hover transition-colors">
                  <td className="px-4 py-2.5 text-sm text-mdt-text-primary">
                    {r.clockIn ? new Date(r.clockIn).toLocaleDateString() : '-'}
                  </td>
                  <td className="px-4 py-2.5 text-sm text-mdt-text-secondary">
                    {r.clockIn ? new Date(r.clockIn).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '-'}
                  </td>
                  <td className="px-4 py-2.5 text-sm text-mdt-text-secondary">
                    {r.clockOut ? new Date(r.clockOut).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : (
                      <span className="px-2 py-0.5 rounded text-[10px] font-bold uppercase bg-mdt-success/20 text-mdt-success">Active</span>
                    )}
                  </td>
                  <td className="px-4 py-2.5 text-sm font-medium text-mdt-text-primary">
                    {r.clockOut ? formatDuration(r.durationMinutes) : '-'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}

function AllOfficersTab() {
  const { allOfficersDuty } = useMDTStore()

  return (
    <div className="h-full bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-hidden flex flex-col">
      <div className="px-5 py-3 bg-mdt-bg-tertiary border-b border-mdt-border">
        <p className="text-xs text-mdt-text-muted">Duty hours for all officers in the last 7 days</p>
      </div>
      <div className="flex-1 overflow-y-auto">
        {allOfficersDuty.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-mdt-text-muted">
            <Users className="w-10 h-10 opacity-50 mb-3" />
            <p className="text-sm">No duty records found</p>
          </div>
        ) : (
          <div className="divide-y divide-mdt-border/50">
            {allOfficersDuty.map((officer, idx) => (
              <OfficerDutyBlock key={idx} data={officer} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

function OfficerDutyBlock({ data }: { data: { officerName: string; totalMinutes: number; records: { clockIn: string; clockOut: string | null; durationMinutes: number }[] } }) {
  const [expanded, setExpanded] = useState(false)

  return (
    <div>
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full flex items-center justify-between px-5 py-3 hover:bg-mdt-bg-hover transition-colors"
      >
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-full bg-mdt-accent/15 flex items-center justify-center">
            <Users className="w-4 h-4 text-mdt-accent" />
          </div>
          <span className="text-sm font-semibold text-mdt-text-primary">{data.officerName}</span>
        </div>
        <div className="flex items-center gap-3">
          <span className="text-sm font-bold text-mdt-accent">{formatDuration(data.totalMinutes)}</span>
          <span className={`text-mdt-text-muted transition-transform ${expanded ? 'rotate-180' : ''}`}>
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" /></svg>
          </span>
        </div>
      </button>
      {expanded && (
        <div className="px-5 pb-3">
          <table className="w-full">
            <thead>
              <tr className="text-[10px] font-semibold text-mdt-text-muted uppercase tracking-wide text-left">
                <th className="px-2 py-1">Clock In</th>
                <th className="px-2 py-1">Clock Out</th>
                <th className="px-2 py-1">Duration</th>
              </tr>
            </thead>
            <tbody>
              {data.records.map((r, i) => (
                <tr key={i} className="text-xs text-mdt-text-secondary">
                  <td className="px-2 py-1">{r.clockIn ? new Date(r.clockIn).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '-'}</td>
                  <td className="px-2 py-1">{r.clockOut ? new Date(r.clockOut).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : <span className="text-mdt-success font-medium">Active</span>}</td>
                  <td className="px-2 py-1 font-medium">{r.clockOut ? formatDuration(r.durationMinutes) : '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
