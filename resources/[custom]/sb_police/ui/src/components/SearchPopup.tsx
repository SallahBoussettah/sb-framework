import { useState } from 'react'
import { Search, X, Loader2 } from 'lucide-react'
import { motion } from 'framer-motion'
import { fetchNui } from '../utils/nui'
import { onNuiMessage } from '../utils/nui'
import { useEffect } from 'react'

interface SearchResult {
  id: string
  name: string
  extra?: string
}

interface SearchPopupProps {
  type: 'citizen' | 'vehicle'
  onSelect: (id: string, name: string) => void
  onClose: () => void
}

export default function SearchPopup({ type, onSelect, onClose }: SearchPopupProps) {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<SearchResult[]>([])
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    const unsub = onNuiMessage<{ searchType: string; results: any[] }>('searchResults', (data) => {
      if (type === 'citizen' && data.searchType === 'citizens') {
        setResults(
          (data.results || []).map((r: any) => ({
            id: r.citizenid || r.id,
            name: `${r.firstname} ${r.lastname}`,
            extra: r.citizenid,
          }))
        )
        setLoading(false)
      } else if (type === 'vehicle' && data.searchType === 'vehicles') {
        setResults(
          (data.results || []).map((r: any) => ({
            id: r.plate || r.id,
            name: r.plate,
            extra: `${r.vehicle} - ${r.owner || 'Unknown'}`,
          }))
        )
        setLoading(false)
      }
    })
    return unsub
  }, [type])

  const handleSearch = () => {
    if (!query.trim()) return
    setLoading(true)
    if (type === 'citizen') {
      fetchNui('searchCitizens', { query: query.trim() })
    } else {
      fetchNui('searchVehicles', { query: query.trim() })
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') handleSearch()
    if (e.key === 'Escape') onClose()
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50"
      onClick={onClose}
    >
      <motion.div
        initial={{ scale: 0.95, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        exit={{ scale: 0.95, opacity: 0 }}
        className="w-[420px] max-h-[500px] bg-mdt-bg-primary border border-mdt-border rounded-lg shadow-2xl flex flex-col overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-mdt-border bg-mdt-bg-tertiary">
          <h3 className="text-sm font-semibold text-mdt-text-primary">
            Search {type === 'citizen' ? 'Citizens' : 'Vehicles'}
          </h3>
          <button
            onClick={onClose}
            className="w-7 h-7 flex items-center justify-center rounded text-mdt-text-secondary hover:bg-mdt-bg-hover transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Search Input */}
        <div className="flex gap-2 p-3">
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(type === 'vehicle' ? e.target.value.toUpperCase() : e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={type === 'citizen' ? 'Search by name or ID...' : 'Search by plate...'}
            className="flex-1 px-3 py-2 bg-mdt-bg-secondary border border-mdt-border rounded text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors"
            autoFocus
          />
          <button
            onClick={handleSearch}
            disabled={loading}
            className="w-9 h-9 bg-mdt-accent hover:bg-mdt-accent-hover rounded flex items-center justify-center text-white transition-colors disabled:opacity-50"
          >
            {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Search className="w-4 h-4" />}
          </button>
        </div>

        {/* Results */}
        <div className="flex-1 overflow-y-auto px-3 pb-3 min-h-0">
          {results.length === 0 ? (
            <div className="flex items-center justify-center h-20 text-mdt-text-muted text-sm">
              {loading ? 'Searching...' : query ? 'No results found' : 'Enter a search term'}
            </div>
          ) : (
            <div className="space-y-1">
              {results.map((r) => (
                <button
                  key={r.id}
                  onClick={() => onSelect(r.id, r.name)}
                  className="w-full flex items-center gap-3 px-3 py-2.5 bg-mdt-bg-secondary hover:bg-mdt-bg-hover border border-mdt-border rounded text-left transition-colors"
                >
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-mdt-text-primary truncate">{r.name}</p>
                    {r.extra && (
                      <p className="text-xs text-mdt-text-muted truncate">{r.extra}</p>
                    )}
                  </div>
                  <span className="text-xs text-mdt-accent font-medium shrink-0">Select</span>
                </button>
              ))}
            </div>
          )}
        </div>
      </motion.div>
    </motion.div>
  )
}
