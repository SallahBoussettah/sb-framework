import { useState } from 'react'
import { Search, Car, Loader2, User, Eye, AlertTriangle, Flag } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { useMDTStore } from '../store/mdtStore'
import { fetchNui } from '../utils/nui'
import type { VehicleDetail } from '../types'

export default function Vehicles() {
  const [searchQuery, setSearchQuery] = useState('')
  const {
    vehicleSearchResults,
    vehicleSearchLoading,
    setVehicleSearchLoading,
    selectedVehicle,
    setSelectedVehicle,
    selectedVehicleLoading,
    setSelectedVehicleLoading,
    setPage,
  } = useMDTStore()

  const handleSearch = () => {
    if (!searchQuery.trim()) return

    setVehicleSearchLoading(true)
    fetchNui('searchVehicles', { query: searchQuery.trim().toUpperCase() })
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearch()
    }
  }

  const handleSelectVehicle = (plate: string) => {
    setSelectedVehicleLoading(true)
    fetchNui('getVehicleDetails', { plate })
  }

  const handleCloseProfile = () => {
    setSelectedVehicle(null)
  }

  const handleViewOwner = (ownerId: string | undefined) => {
    if (!ownerId) return
    // Switch to citizens page and search for owner
    setPage('citizens')
    fetchNui('searchCitizens', { query: ownerId })
  }

  const handleMarkStolen = () => {
    if (!selectedVehicle) return
    fetchNui('markVehicleStolen', { plate: selectedVehicle.plate })
  }

  const handleAddBOLO = () => {
    if (!selectedVehicle) return
    fetchNui('addVehicleBOLO', { plate: selectedVehicle.plate })
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="absolute inset-0 p-6 overflow-hidden flex flex-col"
    >
      <div className="mb-5">
        <h2 className="font-heading text-2xl tracking-wider text-mdt-text-primary">Vehicle Search</h2>
        <p className="text-sm text-mdt-text-secondary mt-1">Search vehicles by license plate</p>
      </div>

      <div className="flex-1 flex gap-5 min-h-0">
        {/* Search Sidebar */}
        <div className="w-[320px] flex flex-col gap-3 shrink-0">
          {/* Search Box */}
          <div className="flex gap-2">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value.toUpperCase())}
              onKeyDown={handleKeyDown}
              placeholder="Enter license plate..."
              className="flex-1 px-4 py-3 bg-mdt-bg-secondary border border-mdt-border rounded-md text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors font-mono uppercase"
            />
            <button
              onClick={handleSearch}
              disabled={vehicleSearchLoading}
              className="w-11 h-11 bg-mdt-accent hover:bg-mdt-accent-hover rounded-md flex items-center justify-center text-white transition-colors disabled:opacity-50"
            >
              {vehicleSearchLoading ? (
                <Loader2 className="w-[18px] h-[18px] animate-spin" />
              ) : (
                <Search className="w-[18px] h-[18px]" />
              )}
            </button>
          </div>

          {/* Results */}
          <div className="flex-1 bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-y-auto">
            {vehicleSearchResults.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-full text-mdt-text-muted">
                <Car className="w-10 h-10 opacity-50 mb-3" />
                <p className="text-sm">Search for a vehicle</p>
              </div>
            ) : (
              <div className="divide-y divide-mdt-border/50">
                {vehicleSearchResults.map((vehicle) => (
                  <button
                    key={vehicle.id}
                    onClick={() => handleSelectVehicle(vehicle.plate)}
                    className={`w-full flex items-center gap-3 px-4 py-3 hover:bg-mdt-bg-hover transition-colors text-left ${
                      selectedVehicle?.plate === vehicle.plate ? 'bg-mdt-bg-hover' : ''
                    }`}
                  >
                    <div className="w-9 h-9 bg-mdt-bg-tertiary rounded-lg flex items-center justify-center">
                      <Car className="w-5 h-5 text-mdt-text-muted" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-[13px] font-bold text-mdt-text-primary font-mono tracking-wide">
                        {vehicle.plate}
                      </p>
                      <p className="text-[11px] text-mdt-text-muted">{vehicle.vehicle}</p>
                    </div>
                    {vehicle.wanted && (
                      <span className="px-2 py-1 bg-mdt-danger/20 text-mdt-danger text-[10px] font-bold uppercase rounded">
                        WANTED
                      </span>
                    )}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Detail Panel */}
        <div className="flex-1 bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-hidden">
          <AnimatePresence mode="wait">
            {selectedVehicleLoading ? (
              <motion.div
                key="loading"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="flex flex-col items-center justify-center h-full text-mdt-text-muted"
              >
                <Loader2 className="w-10 h-10 animate-spin mb-3" />
                <p className="text-sm">Loading vehicle details...</p>
              </motion.div>
            ) : selectedVehicle ? (
              <VehicleProfile
                key="profile"
                vehicle={selectedVehicle}
                onClose={handleCloseProfile}
                onViewOwner={handleViewOwner}
                onMarkStolen={handleMarkStolen}
                onAddBOLO={handleAddBOLO}
              />
            ) : (
              <motion.div
                key="empty"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="flex flex-col items-center justify-center h-full text-mdt-text-muted"
              >
                <Car className="w-16 h-16 opacity-50 mb-4" />
                <p className="text-base">Select a vehicle to view details</p>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </motion.div>
  )
}

interface VehicleProfileProps {
  vehicle: VehicleDetail
  onClose: () => void
  onViewOwner: (ownerId: string | undefined) => void
  onMarkStolen: () => void
  onAddBOLO: () => void
}

function VehicleProfile({ vehicle, onClose, onViewOwner, onMarkStolen, onAddBOLO }: VehicleProfileProps) {
  const getStatusClass = (status: string | undefined) => {
    switch (status) {
      case 'valid':
        return 'text-mdt-success'
      case 'expired':
        return 'text-mdt-danger'
      default:
        return 'text-mdt-text-muted'
    }
  }

  const getStatusText = (status: string | undefined) => {
    switch (status) {
      case 'valid':
        return 'Valid'
      case 'expired':
        return 'Expired'
      default:
        return 'None'
    }
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
        <div className="w-16 h-16 bg-mdt-bg-hover rounded-xl flex items-center justify-center">
          <Car className="w-9 h-9 text-mdt-text-muted" />
        </div>
        <div className="flex-1">
          <h3 className="text-xl font-bold text-mdt-text-primary font-mono tracking-wide">
            {vehicle.plate}
          </h3>
          <p className="text-sm text-mdt-text-muted">{vehicle.vehicle}</p>
        </div>
        {vehicle.flags.map((flag) => (
          <span
            key={flag.type}
            className={`px-3 py-1.5 text-xs font-bold uppercase rounded ${
              flag.type === 'stolen'
                ? 'bg-mdt-danger/20 text-mdt-danger'
                : flag.type === 'bolo'
                ? 'bg-mdt-warning/20 text-mdt-warning'
                : 'bg-mdt-accent/20 text-mdt-accent'
            }`}
          >
            {flag.type}
          </span>
        ))}
        <button
          onClick={onClose}
          className="w-8 h-8 flex items-center justify-center rounded-md text-mdt-text-secondary hover:bg-mdt-bg-hover transition-colors"
        >
          <span className="text-lg">&times;</span>
        </button>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto p-5">
        <div className="grid grid-cols-2 gap-5">
          {/* Vehicle Info */}
          <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
            <h4 className="text-[11px] font-semibold text-mdt-text-muted uppercase tracking-wide mb-3 pb-2 border-b border-mdt-border">
              Vehicle Information
            </h4>
            <div className="space-y-2">
              <InfoRow label="License Plate" value={vehicle.plate} valueClass="font-mono font-bold tracking-wide" />
              <InfoRow label="Model" value={vehicle.vehicle} />
              <InfoRow label="Class" value={vehicle.class || 'Unknown'} />
              <InfoRow label="State" value="San Andreas" />
            </div>
          </div>

          {/* Registration */}
          <div className="bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
            <h4 className="text-[11px] font-semibold text-mdt-text-muted uppercase tracking-wide mb-3 pb-2 border-b border-mdt-border">
              Registration
            </h4>
            <div className="space-y-2">
              <InfoRow
                label="Status"
                value={getStatusText(vehicle.registration)}
                valueClass={getStatusClass(vehicle.registration)}
              />
              <InfoRow
                label="Insurance"
                value={getStatusText(vehicle.insurance)}
                valueClass={getStatusClass(vehicle.insurance)}
              />
              <InfoRow label="Registered" value={vehicle.registeredDate || '--'} />
            </div>
          </div>

          {/* Owner */}
          <div className="col-span-2 bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
            <h4 className="text-[11px] font-semibold text-mdt-text-muted uppercase tracking-wide mb-3 pb-2 border-b border-mdt-border">
              Owner Information
            </h4>
            <div className="flex items-center gap-3.5 p-3.5 bg-mdt-bg-secondary border border-mdt-border rounded-lg">
              <div className="w-11 h-11 bg-mdt-bg-hover rounded-full flex items-center justify-center">
                <User className="w-6 h-6 text-mdt-text-muted" />
              </div>
              <div className="flex-1">
                <p className="text-sm font-semibold text-mdt-text-primary">{vehicle.owner || 'Unknown'}</p>
                <p className="text-[11px] text-mdt-text-muted font-mono">{vehicle.ownerId || '--'}</p>
              </div>
              <button
                onClick={() => onViewOwner(vehicle.ownerId)}
                disabled={!vehicle.ownerId}
                className="flex items-center gap-2 px-3 py-2 bg-mdt-bg-tertiary border border-mdt-border rounded-md text-xs font-medium text-mdt-text-secondary hover:bg-mdt-bg-hover hover:text-mdt-text-primary transition-colors disabled:opacity-50"
              >
                <Eye className="w-4 h-4" />
                View Profile
              </button>
            </div>
          </div>

          {/* Flags & Actions */}
          <div className="col-span-2 bg-mdt-bg-tertiary border border-mdt-border rounded-lg p-4">
            <h4 className="text-[11px] font-semibold text-mdt-text-muted uppercase tracking-wide mb-3 pb-2 border-b border-mdt-border">
              Flags & Actions
            </h4>
            {vehicle.flags.length === 0 ? (
              <p className="text-sm text-mdt-text-muted italic py-2">No active flags</p>
            ) : (
              <div className="flex flex-wrap gap-2 mb-4">
                {vehicle.flags.map((flag, index) => (
                  <div
                    key={index}
                    className={`px-3 py-1.5 rounded text-xs font-semibold ${
                      flag.type === 'stolen'
                        ? 'bg-mdt-danger/20 text-mdt-danger'
                        : 'bg-mdt-warning/20 text-mdt-warning'
                    }`}
                  >
                    {flag.type.toUpperCase()}
                    {flag.note && <span className="font-normal ml-2">- {flag.note}</span>}
                  </div>
                ))}
              </div>
            )}
            <div className="flex gap-2.5 pt-3 border-t border-mdt-border">
              <button
                onClick={onMarkStolen}
                className="flex items-center gap-2 px-4 py-2.5 bg-mdt-bg-secondary border border-mdt-border rounded-md text-xs font-medium text-mdt-text-secondary hover:bg-mdt-danger/10 hover:border-mdt-danger/50 hover:text-mdt-danger transition-colors"
              >
                <AlertTriangle className="w-4 h-4" />
                Mark Stolen
              </button>
              <button
                onClick={onAddBOLO}
                className="flex items-center gap-2 px-4 py-2.5 bg-mdt-bg-secondary border border-mdt-border rounded-md text-xs font-medium text-mdt-text-secondary hover:bg-mdt-warning/10 hover:border-mdt-warning/50 hover:text-mdt-warning transition-colors"
              >
                <Flag className="w-4 h-4" />
                Add BOLO
              </button>
            </div>
          </div>
        </div>
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
