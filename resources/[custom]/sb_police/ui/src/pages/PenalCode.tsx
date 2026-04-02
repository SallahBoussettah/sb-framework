import { useState, useMemo } from 'react'
import { Search, Scale } from 'lucide-react'
import { motion } from 'framer-motion'
import { useMDTStore } from '../store/mdtStore'

export default function PenalCode() {
  const [searchQuery, setSearchQuery] = useState('')
  const { penalCode } = useMDTStore()

  // Group codes by category
  const groupedCodes = useMemo(() => {
    const filtered = searchQuery
      ? penalCode.filter(
          (code) =>
            code.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
            code.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
            code.category.toLowerCase().includes(searchQuery.toLowerCase())
        )
      : penalCode

    const grouped: Record<string, typeof penalCode> = {}
    filtered.forEach((code) => {
      if (!grouped[code.category]) {
        grouped[code.category] = []
      }
      grouped[code.category].push(code)
    })
    return grouped
  }, [penalCode, searchQuery])

  const categoryOrder = ['Traffic', 'Misdemeanor', 'Felony', 'Weapons', 'Drugs', 'Financial', 'Government']

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="absolute inset-0 p-6 overflow-hidden flex flex-col"
    >
      <div className="mb-5">
        <h2 className="font-heading text-2xl tracking-wider text-mdt-text-primary">Criminal Code</h2>
        <p className="text-sm text-mdt-text-secondary mt-1">Browse charges, fines, and sentences</p>
      </div>

      {/* Search */}
      <div className="max-w-md mb-5">
        <div className="relative">
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search criminal code..."
            className="w-full px-4 py-3 pr-10 bg-mdt-bg-secondary border border-mdt-border rounded-md text-sm text-mdt-text-primary placeholder:text-mdt-text-muted outline-none focus:border-mdt-accent transition-colors"
          />
          <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-[18px] h-[18px] text-mdt-text-muted" />
        </div>
      </div>

      {/* Table */}
      <div className="flex-1 bg-mdt-bg-secondary border border-mdt-border rounded-lg overflow-hidden">
        {penalCode.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-mdt-text-muted">
            <Scale className="w-16 h-16 opacity-50 mb-4" />
            <p className="text-base">Loading criminal code...</p>
          </div>
        ) : (
          <div className="h-full overflow-auto">
            <table className="w-full">
              <thead className="sticky top-0 bg-mdt-bg-tertiary z-10">
                <tr>
                  <th className="px-4 py-3.5 text-left text-[11px] font-semibold text-mdt-text-secondary uppercase tracking-wide border-b border-mdt-border">
                    Article
                  </th>
                  <th className="px-4 py-3.5 text-left text-[11px] font-semibold text-mdt-text-secondary uppercase tracking-wide border-b border-mdt-border">
                    Description
                  </th>
                  <th className="px-4 py-3.5 text-center text-[11px] font-semibold text-mdt-text-secondary uppercase tracking-wide border-b border-mdt-border w-28">
                    Fine
                  </th>
                  <th className="px-4 py-3.5 text-center text-[11px] font-semibold text-mdt-text-secondary uppercase tracking-wide border-b border-mdt-border w-28">
                    Jail Time
                  </th>
                </tr>
              </thead>
              <tbody>
                {categoryOrder
                  .filter((cat) => groupedCodes[cat])
                  .map((category) => (
                    <>
                      <tr key={`cat-${category}`} className="bg-mdt-bg-tertiary">
                        <td
                          colSpan={4}
                          className="px-4 py-2.5 text-xs font-semibold text-mdt-accent uppercase tracking-wide"
                        >
                          {category}
                        </td>
                      </tr>
                      {groupedCodes[category].map((code) => (
                        <tr
                          key={code.id}
                          className="hover:bg-mdt-bg-hover transition-colors border-b border-mdt-border/30"
                        >
                          <td className="px-4 py-3 text-sm text-mdt-text-primary font-medium">
                            {code.title}
                          </td>
                          <td className="px-4 py-3 text-sm text-mdt-text-secondary">
                            {code.description}
                          </td>
                          <td className="px-4 py-3 text-center text-sm font-semibold text-mdt-warning">
                            ${code.fine.toLocaleString()}
                          </td>
                          <td className="px-4 py-3 text-center text-sm font-semibold text-mdt-danger">
                            {code.jail_time > 0 ? `${code.jail_time} months` : '-'}
                          </td>
                        </tr>
                      ))}
                    </>
                  ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </motion.div>
  )
}
