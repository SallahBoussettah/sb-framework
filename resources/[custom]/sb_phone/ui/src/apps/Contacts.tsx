import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { nuiFetch, notifyTextFieldFocus } from '../utils/nui'
import { soundManager } from '../utils/sound'
import AppHeader from '../components/AppHeader'
import { Plus, Star, Trash2, Edit, Phone, MessageSquare, X } from 'lucide-react'
import type { Contact } from '../types'

export default function Contacts() {
  const { contacts, setContacts, navigate } = usePhoneStore()
  const [editing, setEditing] = useState<Contact | null>(null)
  const [showForm, setShowForm] = useState(false)
  const [name, setName] = useState('')
  const [number, setNumber] = useState('')
  const [search, setSearch] = useState('')

  const favorites = contacts.filter(c => c.favorite)
  const filtered = contacts.filter(c =>
    c.name.toLowerCase().includes(search.toLowerCase()) ||
    c.number.includes(search)
  )

  const openForm = (contact?: Contact) => {
    if (contact) {
      setEditing(contact)
      setName(contact.name)
      setNumber(contact.number)
    } else {
      setEditing(null)
      setName('')
      setNumber('')
    }
    setShowForm(true)
  }

  const saveContact = async () => {
    if (!name.trim() || !number.trim()) return
    const res = await nuiFetch<{ success: boolean }>('saveContact', {
      name: name.trim(),
      number: number.trim(),
      id: editing?.id || null,
    })
    if (res.success) {
      soundManager.send()
      const updated = await nuiFetch<Contact[]>('getContacts')
      if (Array.isArray(updated)) setContacts(updated)
      setShowForm(false)
    }
  }

  const deleteContact = async (id: number) => {
    await nuiFetch('deleteContact', { id })
    soundManager.delete()
    setContacts(contacts.filter(c => c.id !== id))
  }

  const toggleFavorite = async (id: number, current: boolean) => {
    await nuiFetch('toggleFavorite', { id, favorite: !current })
    setContacts(contacts.map(c => c.id === id ? { ...c, favorite: !current } : c))
  }

  return (
    <div className="flex flex-col h-full bg-[#0e0e0f]">
      <AppHeader
        title="Contacts"
        rightAction={
          <button onClick={() => openForm()} className="text-phone-accent">
            <Plus size={22} />
          </button>
        }
      />

      {/* Search */}
      <div className="px-4 mb-3">
        <input
          type="text"
          value={search}
          onChange={e => setSearch(e.target.value)}
          onFocus={() => notifyTextFieldFocus(true)}
          onBlur={() => notifyTextFieldFocus(false)}
          placeholder="Search contacts..."
          className="w-full bg-phone-card rounded-lg px-3 py-2.5 text-white text-sm outline-none placeholder:text-phone-dim"
        />
      </div>

      <div className="flex-1 overflow-y-auto px-4">
        {/* Favorites */}
        {favorites.length > 0 && !search && (
          <div className="mb-4">
            <p className="text-phone-dim text-xs font-semibold uppercase tracking-wider mb-2">Favorites</p>
            <div className="flex gap-3 overflow-x-auto pb-2">
              {favorites.map(c => (
                <button key={c.id} className="flex flex-col items-center gap-1 min-w-[60px]">
                  <div className="w-12 h-12 rounded-full bg-phone-accent/20 flex items-center justify-center">
                    <span className="text-phone-accent font-bold">{c.name[0]?.toUpperCase()}</span>
                  </div>
                  <span className="text-white text-[11px] truncate w-16 text-center">{c.name}</span>
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Contact list */}
        {filtered.length === 0 ? (
          <p className="text-phone-muted text-center mt-8 text-sm">
            {search ? 'No matches' : 'No contacts yet'}
          </p>
        ) : (
          filtered.map(c => (
            <div key={c.id} className="flex items-center gap-3 py-3 border-b border-white/5">
              <div className="w-10 h-10 rounded-full bg-phone-card flex items-center justify-center shrink-0">
                <span className="text-white font-semibold text-sm">{c.name[0]?.toUpperCase()}</span>
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-white text-sm font-medium truncate">{c.name}</p>
                <p className="text-phone-dim text-xs">{c.number}</p>
              </div>
              <div className="flex items-center gap-1">
                <button onClick={() => toggleFavorite(c.id, c.favorite)} className="p-1.5">
                  <Star size={16} className={c.favorite ? 'text-phone-yellow fill-phone-yellow' : 'text-phone-dim'} />
                </button>
                <button onClick={() => openForm(c)} className="p-1.5">
                  <Edit size={14} className="text-phone-muted" />
                </button>
                <button onClick={() => deleteContact(c.id)} className="p-1.5">
                  <Trash2 size={14} className="text-phone-red/60" />
                </button>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Add/Edit form overlay */}
      <AnimatePresence>
        {showForm && (
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 25, stiffness: 300 }}
            className="absolute inset-0 bg-phone-bg z-50 flex flex-col"
          >
            <div className="flex items-center justify-between px-4 pt-4 pb-3">
              <button onClick={() => setShowForm(false)} className="text-phone-red text-sm">Cancel</button>
              <h2 className="text-white font-semibold">{editing ? 'Edit' : 'New'} Contact</h2>
              <button onClick={saveContact} className="text-phone-accent text-sm font-semibold">Save</button>
            </div>

            <div className="px-4 space-y-4 pt-6">
              <div className="flex justify-center mb-4">
                <div className="w-20 h-20 rounded-full bg-phone-card flex items-center justify-center">
                  <span className="text-white text-3xl font-light">{name ? name[0]?.toUpperCase() : '?'}</span>
                </div>
              </div>
              <input
                type="text"
                value={name}
                onChange={e => setName(e.target.value.slice(0, 50))}
                onFocus={() => notifyTextFieldFocus(true)}
                onBlur={() => notifyTextFieldFocus(false)}
                placeholder="Name"
                className="w-full bg-phone-card rounded-lg px-4 py-3 text-white outline-none placeholder:text-phone-dim"
              />
              <input
                type="text"
                value={number}
                onChange={e => setNumber(e.target.value.slice(0, 20))}
                onFocus={() => notifyTextFieldFocus(true)}
                onBlur={() => notifyTextFieldFocus(false)}
                placeholder="Phone number"
                className="w-full bg-phone-card rounded-lg px-4 py-3 text-white outline-none placeholder:text-phone-dim"
              />
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
