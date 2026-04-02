import { useState, useCallback } from 'react'
import { useBookingStore } from '../store/bookingStore'
import { fetchNui } from '../utils/nui'

export function SuspectLookup() {
  const { searchQuery, searchResults, searchLoading, setSearchQuery, setSearchLoading, setStep, setProfileLoading } = useBookingStore()
  const [localQuery, setLocalQuery] = useState(searchQuery)

  const handleSearch = useCallback(() => {
    const q = localQuery.trim()
    if (!q) return
    setSearchQuery(q)
    setSearchLoading(true)
    fetchNui('searchSuspect', { query: q })
  }, [localQuery, setSearchQuery, setSearchLoading])

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') handleSearch()
  }

  const handleSelect = (citizenid: string) => {
    setProfileLoading(true)
    setStep('profile')
    fetchNui('getSuspectProfile', { citizenid })
  }

  return (
    <div className="flex flex-col h-full">
      <h2 className="text-base font-semibold text-white mb-1">Suspect Lookup</h2>
      <p className="text-xs text-booking-text-secondary mb-4">Search by name or citizen ID</p>

      {/* Search bar */}
      <div className="flex gap-2 mb-4">
        <div className="flex-1 relative">
          <i className="fas fa-magnifying-glass absolute left-3 top-1/2 -translate-y-1/2 text-booking-text-muted text-xs" />
          <input
            type="text"
            value={localQuery}
            onChange={(e) => setLocalQuery(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Enter name or citizen ID..."
            className="w-full bg-booking-bg-tertiary border border-booking-border rounded px-3 py-2.5 pl-9 text-sm text-white placeholder-booking-text-muted focus:outline-none focus:border-booking-accent transition-colors"
            autoFocus
          />
        </div>
        <button
          onClick={handleSearch}
          disabled={searchLoading || !localQuery.trim()}
          className="px-5 bg-booking-accent hover:bg-booking-accent-hover disabled:opacity-50 disabled:cursor-not-allowed text-white rounded text-sm font-medium transition-colors"
        >
          {searchLoading ? (
            <i className="fas fa-spinner fa-spin" />
          ) : (
            'Search'
          )}
        </button>
      </div>

      {/* Results */}
      <div className="flex-1 overflow-y-auto">
        {searchResults.length > 0 ? (
          <div className="space-y-1.5">
            {searchResults.map((suspect) => (
              <button
                key={suspect.citizenid}
                onClick={() => handleSelect(suspect.citizenid)}
                className="w-full flex items-center gap-3 p-3 bg-booking-bg-secondary border border-booking-border rounded hover:border-booking-accent/50 hover:bg-booking-bg-hover transition-colors text-left"
              >
                <div className="w-9 h-9 rounded-full bg-booking-bg-elevated flex items-center justify-center shrink-0">
                  <i className="fas fa-user text-booking-text-muted text-sm" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-white">
                    {suspect.firstname} {suspect.lastname}
                  </p>
                  <p className="text-[11px] text-booking-text-secondary">
                    CID: {suspect.citizenid} | DOB: {suspect.dob} | {suspect.gender === 'male' ? 'Male' : 'Female'}
                  </p>
                </div>
                <i className="fas fa-chevron-right text-booking-text-muted text-xs" />
              </button>
            ))}
          </div>
        ) : searchQuery && !searchLoading ? (
          <div className="flex flex-col items-center justify-center py-12 text-booking-text-muted">
            <i className="fas fa-user-slash text-3xl mb-3" />
            <p className="text-sm">No suspects found</p>
          </div>
        ) : !searchQuery ? (
          <div className="flex flex-col items-center justify-center py-12 text-booking-text-muted">
            <i className="fas fa-search text-3xl mb-3" />
            <p className="text-sm">Search for a suspect to begin booking</p>
          </div>
        ) : null}
      </div>
    </div>
  )
}
