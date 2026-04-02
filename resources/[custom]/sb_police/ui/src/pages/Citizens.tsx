import { useState } from 'react'
import { Search, User, Loader2 } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { useMDTStore } from '../store/mdtStore'
import { fetchNui } from '../utils/nui'
import CitizenProfile from '../components/CitizenProfile'

export default function Citizens() {
  const [searchQuery, setSearchQuery] = useState('')
  const {
    citizenSearchResults,
    citizenSearchLoading,
    setCitizenSearchLoading,
    selectedCitizen,
    setSelectedCitizen,
    selectedCitizenLoading,
    setSelectedCitizenLoading,
  } = useMDTStore()

  const handleSearch = () => {
    if (!searchQuery.trim()) return

    setCitizenSearchLoading(true)
    fetchNui('searchCitizens', { query: searchQuery.trim() })
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearch()
    }
  }

  const handleSelectCitizen = (citizenId: string) => {
    setSelectedCitizenLoading(true)
    fetchNui('getCitizenDetails', { id: citizenId })
  }

  const handleCloseProfile = () => {
    setSelectedCitizen(null)
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="absolute inset-0 p-6 overflow-hidden flex flex-col"
    >
      <div className="mb-5">
        <h2 className="font-heading text-2xl tracking-wider text-mdt-text-primary">Citizen Search</h2>
        <p className="text-sm text-mdt-text-secondary mt-1">Search for citizens in the database</p>
      </div>

      <div className="flex-1 flex gap-5 min-h-0">
        {/* Search Sidebar */}
        <div className="w-[320px] flex flex-col gap-3 shrink-0">
          {/* Search Box */}
          <div className="flex gap-2">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Search by name or ID..."
              className="flex-1 px-4 py-3 bg-mdt-bg-secondary border border-mdt-border rounded-md text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors"
            />
            <button
              onClick={handleSearch}
              disabled={citizenSearchLoading}
              className="w-11 h-11 bg-mdt-accent hover:bg-mdt-accent-hover rounded-md flex items-center justify-center text-white transition-colors disabled:opacity-50"
            >
              {citizenSearchLoading ? (
                <Loader2 className="w-[18px] h-[18px] animate-spin" />
              ) : (
                <Search className="w-[18px] h-[18px]" />
              )}
            </button>
          </div>

          {/* Results */}
          <div className="flex-1 bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-y-auto">
            {citizenSearchResults.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-full text-mdt-text-muted">
                <Search className="w-10 h-10 opacity-50 mb-3" />
                <p className="text-sm">Search for a citizen</p>
              </div>
            ) : (
              <div className="divide-y divide-mdt-border/50">
                {citizenSearchResults.map((citizen) => (
                  <button
                    key={citizen.id}
                    onClick={() => handleSelectCitizen(citizen.id)}
                    className={`w-full flex items-center gap-3 px-4 py-3 hover:bg-mdt-bg-hover transition-colors text-left ${
                      selectedCitizen?.id === citizen.id ? 'bg-mdt-bg-hover' : ''
                    }`}
                  >
                    <div className="w-9 h-9 bg-mdt-bg-tertiary rounded-full flex items-center justify-center">
                      <User className="w-5 h-5 text-mdt-text-muted" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-[13px] font-semibold text-mdt-text-primary">
                        {citizen.firstname} {citizen.lastname}
                      </p>
                      <p className="text-[11px] text-mdt-text-muted">ID: {citizen.citizenid}</p>
                    </div>
                    {citizen.wanted && (
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
            {selectedCitizenLoading ? (
              <motion.div
                key="loading"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="flex flex-col items-center justify-center h-full text-mdt-text-muted"
              >
                <Loader2 className="w-10 h-10 animate-spin mb-3" />
                <p className="text-sm">Loading profile...</p>
              </motion.div>
            ) : selectedCitizen ? (
              <CitizenProfile key="profile" citizen={selectedCitizen} onClose={handleCloseProfile} />
            ) : (
              <motion.div
                key="empty"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="flex flex-col items-center justify-center h-full text-mdt-text-muted"
              >
                <User className="w-16 h-16 opacity-50 mb-4" />
                <p className="text-base">Select a citizen to view their profile</p>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </motion.div>
  )
}
