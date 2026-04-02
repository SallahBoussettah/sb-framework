import { useEffect } from 'react'
import { motion } from 'framer-motion'
import { useGarageStore, GarageVehicle } from '../store/garageStore'
import { fetchNui } from '../utils/nui'
import {
  FaCar,
  FaCarSide,
  FaMotorcycle,
  FaHelicopter,
  FaShip,
  FaBus,
  FaShieldHalved,
  FaStar,
  FaGaugeHigh,
  FaXmark,
  FaLock,
  FaWarehouse,
} from 'react-icons/fa6'

const categoryIcons: Record<string, React.ReactNode> = {
  all: <FaCar />,
  patrol: <FaCarSide />,
  pursuit: <FaGaugeHigh />,
  motorcycle: <FaMotorcycle />,
  swat: <FaShieldHalved />,
  command: <FaStar />,
  transport: <FaBus />,
  air: <FaHelicopter />,
  marine: <FaShip />,
}

const rankColors: Record<number, string> = {
  0: 'text-gray-400',
  1: 'text-gray-400',
  2: 'text-green-400',
  3: 'text-green-400',
  4: 'text-blue-400',
  5: 'text-blue-400',
  6: 'text-purple-400',
  7: 'text-purple-400',
  8: 'text-yellow-400',
  9: 'text-red-400',
}

export default function GarageMenu() {
  const {
    isOpen,
    vehicles,
    categories,
    playerGrade,
    ranks,
    gradeMode,
    selectedCategory,
    selectedVehicle,
    closeGarage,
    setSelectedCategory,
    setSelectedVehicle,
  } = useGarageStore()

  const meetsGrade = (vehicleGrade: number) =>
    gradeMode === 'exact' ? playerGrade === vehicleGrade : playerGrade >= vehicleGrade

  // Handle ESC key to close
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) {
        closeGarage()
        fetchNui('closeGarage', {})
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [isOpen, closeGarage])

  if (!isOpen) return null

  // In exact mode: only show vehicles matching player grade (others are hidden entirely)
  // In cumulative mode: show all vehicles (ones above grade shown as locked)
  const gradeFilteredVehicles =
    gradeMode === 'exact'
      ? vehicles.filter((v) => v.grade === playerGrade)
      : vehicles

  const filteredVehicles =
    selectedCategory === 'all'
      ? gradeFilteredVehicles
      : gradeFilteredVehicles.filter((v) => v.category === selectedCategory)

  const getRankName = (grade: number) => {
    const rank = ranks.find((r) => r.grade === grade)
    return rank ? rank.name : `Grade ${grade}`
  }

  const getCategoryName = (catId: string) => {
    const cat = categories.find((c) => c.id === catId)
    return cat ? cat.label : catId
  }

  const handleClose = () => {
    closeGarage()
    fetchNui('closeGarage', {})
  }

  const handleSpawn = () => {
    if (!selectedVehicle || !meetsGrade(selectedVehicle.grade)) return

    fetchNui('spawnVehicle', {
      model: selectedVehicle.model,
      label: selectedVehicle.label,
      category: selectedVehicle.category,
    })

    closeGarage()
  }

  const playerRank = ranks.find((r) => r.grade === playerGrade)

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 pointer-events-auto"
      onClick={handleClose}
    >
      <motion.div
        initial={{ scale: 0.95, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        exit={{ scale: 0.95, opacity: 0 }}
        transition={{ type: 'spring', damping: 25, stiffness: 300 }}
        className="w-[1000px] h-[600px] bg-mdt-bg-primary rounded-2xl overflow-hidden flex flex-col shadow-2xl border border-mdt-border"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="bg-mdt-bg-secondary px-6 py-4 border-b border-mdt-border flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-xl bg-mdt-accent/20 flex items-center justify-center text-mdt-accent text-xl">
              <FaWarehouse />
            </div>
            <div>
              <h1 className="text-xl font-semibold text-mdt-text-primary">Police Garage</h1>
              <p className="text-sm text-mdt-text-secondary">
                Rank: {playerRank?.name || 'Unknown'} (Grade {playerGrade})
              </p>
            </div>
          </div>
          <button
            onClick={handleClose}
            className="w-10 h-10 rounded-lg bg-mdt-bg-tertiary hover:bg-mdt-danger/20 border border-mdt-border hover:border-mdt-danger/30 text-mdt-text-secondary hover:text-mdt-danger transition-all flex items-center justify-center"
          >
            <FaXmark />
          </button>
        </div>

        {/* Body */}
        <div className="flex flex-1 overflow-hidden">
          {/* Categories Sidebar */}
          <div className="w-[200px] bg-mdt-bg-secondary/50 p-3 border-r border-mdt-border overflow-y-auto">
            <div className="text-[10px] font-semibold text-mdt-text-muted uppercase tracking-wider px-3 mb-2">
              Categories
            </div>
            {categories.map((cat) => {
              const count =
                cat.id === 'all'
                  ? gradeFilteredVehicles.length
                  : gradeFilteredVehicles.filter((v) => v.category === cat.id).length

              return (
                <button
                  key={cat.id}
                  onClick={() => setSelectedCategory(cat.id)}
                  className={`w-full px-3 py-2.5 rounded-lg text-left text-sm font-medium transition-all flex items-center gap-3 mb-1 ${
                    selectedCategory === cat.id
                      ? 'bg-mdt-accent/20 text-mdt-accent border border-mdt-accent/30'
                      : 'text-mdt-text-secondary hover:bg-mdt-bg-hover hover:text-mdt-text-primary'
                  }`}
                >
                  <span className="text-base">{categoryIcons[cat.id] || <FaCar />}</span>
                  <span className="flex-1">{cat.label}</span>
                  <span
                    className={`text-xs px-2 py-0.5 rounded ${
                      selectedCategory === cat.id
                        ? 'bg-mdt-accent/30 text-mdt-accent'
                        : 'bg-mdt-bg-tertiary text-mdt-text-muted'
                    }`}
                  >
                    {count}
                  </span>
                </button>
              )
            })}
          </div>

          {/* Vehicle Grid */}
          <div className="flex-1 p-5 overflow-y-auto">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-base font-semibold text-mdt-text-primary">
                {categories.find((c) => c.id === selectedCategory)?.label || 'All Vehicles'}
              </h2>
              <span className="text-sm text-mdt-text-muted">
                {filteredVehicles.length} vehicle{filteredVehicles.length !== 1 ? 's' : ''}
              </span>
            </div>

            {filteredVehicles.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-[300px] text-mdt-text-muted">
                <FaCar className="text-4xl mb-3 opacity-30" />
                <p>No vehicles in this category</p>
              </div>
            ) : (
              <div className="grid grid-cols-3 gap-3">
                {filteredVehicles.map((vehicle) => (
                  <VehicleCard
                    key={vehicle.model}
                    vehicle={vehicle}
                    isLocked={!meetsGrade(vehicle.grade)}
                    isSelected={selectedVehicle?.model === vehicle.model}
                    rankName={getRankName(vehicle.grade)}
                    onSelect={() => {
                      if (meetsGrade(vehicle.grade)) {
                        setSelectedVehicle(vehicle)
                      }
                    }}
                  />
                ))}
              </div>
            )}
          </div>

          {/* Preview Panel */}
          <div className="w-[260px] bg-mdt-bg-secondary/50 p-5 border-l border-mdt-border flex flex-col">
            {!selectedVehicle ? (
              <div className="flex-1 flex flex-col items-center justify-center text-mdt-text-muted">
                <FaCar className="text-4xl mb-3 opacity-30" />
                <p className="text-sm">Select a vehicle</p>
              </div>
            ) : (
              <>
                <div className="h-[120px] rounded-xl bg-mdt-bg-tertiary flex items-center justify-center mb-4 border border-mdt-border">
                  <span className="text-4xl text-mdt-accent">
                    {categoryIcons[selectedVehicle.category] || <FaCar />}
                  </span>
                </div>

                <h3 className="text-lg font-semibold text-mdt-text-primary mb-1">
                  {selectedVehicle.label}
                </h3>
                <p className="text-sm text-mdt-text-secondary mb-4">
                  {getCategoryName(selectedVehicle.category)}
                </p>

                <div className="flex-1 space-y-0">
                  <div className="flex justify-between py-3 border-b border-mdt-border">
                    <span className="text-sm text-mdt-text-secondary">Required Rank</span>
                    <span className={`text-sm font-semibold ${rankColors[selectedVehicle.grade]}`}>
                      {getRankName(selectedVehicle.grade)}
                    </span>
                  </div>
                  <div className="flex justify-between py-3 border-b border-mdt-border">
                    <span className="text-sm text-mdt-text-secondary">Category</span>
                    <span className="text-sm font-semibold text-mdt-text-primary">
                      {getCategoryName(selectedVehicle.category)}
                    </span>
                  </div>
                  <div className="flex justify-between py-3">
                    <span className="text-sm text-mdt-text-secondary">Spawn Code</span>
                    <span className="text-sm font-mono text-mdt-text-muted">
                      {selectedVehicle.model}
                    </span>
                  </div>
                </div>

                <button
                  onClick={handleSpawn}
                  disabled={!meetsGrade(selectedVehicle.grade)}
                  className="w-full py-3.5 rounded-xl bg-mdt-accent hover:bg-mdt-accent-hover disabled:bg-mdt-bg-tertiary disabled:text-mdt-text-muted text-white font-semibold transition-all flex items-center justify-center gap-2 mt-4"
                >
                  <FaCar />
                  Spawn Vehicle
                </button>
              </>
            )}
          </div>
        </div>
      </motion.div>
    </motion.div>
  )
}

function VehicleCard({
  vehicle,
  isLocked,
  isSelected,
  rankName,
  onSelect,
}: {
  vehicle: GarageVehicle
  isLocked: boolean
  isSelected: boolean
  rankName: string
  onSelect: () => void
}) {
  return (
    <div
      onClick={onSelect}
      className={`p-4 rounded-xl border transition-all relative overflow-hidden ${
        isLocked
          ? 'opacity-40 cursor-not-allowed bg-mdt-bg-secondary border-mdt-border'
          : isSelected
          ? 'bg-mdt-accent/10 border-mdt-accent cursor-pointer'
          : 'bg-mdt-bg-secondary border-mdt-border hover:border-mdt-accent/50 hover:bg-mdt-bg-tertiary cursor-pointer'
      }`}
    >
      {!isLocked && (
        <div
          className={`absolute top-0 left-0 right-0 h-0.5 bg-gradient-to-r from-mdt-accent to-purple-500 transition-opacity ${
            isSelected ? 'opacity-100' : 'opacity-0'
          }`}
        />
      )}

      <div
        className={`w-10 h-10 rounded-lg flex items-center justify-center mb-3 ${
          isSelected ? 'bg-mdt-accent/20 text-mdt-accent' : 'bg-mdt-bg-tertiary text-mdt-text-muted'
        }`}
      >
        {categoryIcons[vehicle.category] || <FaCar />}
      </div>

      <h4 className="text-sm font-semibold text-mdt-text-primary mb-1 truncate">{vehicle.label}</h4>

      <div className="flex items-center gap-1">
        <span
          className={`text-xs px-2 py-0.5 rounded flex items-center gap-1 ${
            isLocked ? 'bg-mdt-danger/20 text-mdt-danger' : 'bg-mdt-bg-tertiary'
          } ${rankColors[vehicle.grade]}`}
        >
          {isLocked && <FaLock className="text-[10px]" />}
          {rankName}
        </span>
      </div>
    </div>
  )
}
