import { useState, useEffect, useMemo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { nuiFetch, notifyTextFieldFocus } from '../utils/nui'
import { soundManager } from '../utils/sound'
import { formatPhoneNumber, formatCallDuration, timeAgo } from '../utils/time'
import type { Contact } from '../types'
import {
  Phone, PhoneOff, PhoneMissed, PhoneIncoming, PhoneOutgoing,
  Delete, Mic, MicOff, Volume2, VolumeX, Grid3X3,
  Star, Trash2, Edit, Plus, Search, X, UserPlus, Copy, Info, Users
} from 'lucide-react'

type Tab = 'favorites' | 'recents' | 'contacts' | 'keypad'

export default function PhoneApp() {
  const {
    contacts, setContacts, calls, setCalls, callState, setCallState, resetCallState, myNumber, navigate
  } = usePhoneStore()

  const [tab, setTab] = useState<Tab>('keypad')
  const [number, setNumber] = useState('')
  const [callTimer, setCallTimer] = useState(0)
  const [showCallKeypad, setShowCallKeypad] = useState(false)

  // Contact form state
  const [showForm, setShowForm] = useState(false)
  const [editingContact, setEditingContact] = useState<Contact | null>(null)
  const [formName, setFormName] = useState('')
  const [formNumber, setFormNumber] = useState('')

  // Contact search
  const [search, setSearch] = useState('')

  // Contact detail view
  const [viewContact, setViewContact] = useState<Contact | null>(null)

  // Call timer
  useEffect(() => {
    if (callState.status !== 'active') { setCallTimer(0); return }
    const t = setInterval(() => setCallTimer(s => s + 1), 1000)
    return () => clearInterval(t)
  }, [callState.status])

  // Start ringback beep when outgoing call starts
  useEffect(() => {
    if (callState.status === 'outgoing') {
      soundManager.playRingback()
    } else if (callState.status === 'active') {
      soundManager.stopLoop()
    } else if (callState.status === 'idle') {
      soundManager.stopLoop()
    }
  }, [callState.status])

  // ==================== KEYPAD ====================
  const rawDigits = number.replace(/\D/g, '')

  const handleKey = (key: string) => {
    soundManager.dtmf(key)
    if (rawDigits.length < 10) {
      const newDigits = rawDigits + key
      setNumber(formatPhoneNumber(newDigits))
    }
  }

  const handleDelete = () => {
    const digits = rawDigits.slice(0, -1)
    setNumber(digits ? formatPhoneNumber(digits) : '')
  }

  const handleLongDelete = () => {
    setNumber('')
  }

  const handleCall = (num?: string) => {
    const callNum = num || number
    const digits = callNum.replace(/\D/g, '')
    if (digits.length < 7) return
    nuiFetch('startCall', { number: callNum })
    const contact = contacts.find(c => c.number.replace(/\D/g, '') === digits)
    setCallState({
      status: 'outgoing',
      callerName: contact?.name || formatPhoneNumber(digits),
      callerNumber: callNum,
      initial: contact?.name?.[0]?.toUpperCase() || callNum[0] || '?',
    })
  }

  const handleEndCall = () => {
    nuiFetch('endCall')
    resetCallState()
    soundManager.callEnd()
  }

  const handleMute = () => {
    const muted = !callState.muted
    nuiFetch('toggleCallMute', { muted })
    setCallState({ muted })
  }

  const handleSpeaker = () => {
    const speaker = !callState.speaker
    nuiFetch('toggleCallSpeaker', { speaker })
    setCallState({ speaker })
  }

  const handleCopyNumber = () => {
    if (rawDigits.length > 0) {
      nuiFetch('copyToClipboard', { text: number })
    }
  }

  const handleAddContactFromKeypad = () => {
    setEditingContact(null)
    setFormName('')
    setFormNumber(number)
    setShowForm(true)
  }

  // ==================== CONTACTS ====================
  const favorites = useMemo(() => contacts.filter(c => c.favorite), [contacts])

  const filteredContacts = useMemo(() => {
    if (!search) return [...contacts].sort((a, b) => a.name.localeCompare(b.name))
    const q = search.toLowerCase()
    return contacts.filter(c =>
      c.name.toLowerCase().includes(q) || c.number.includes(q)
    ).sort((a, b) => a.name.localeCompare(b.name))
  }, [contacts, search])

  // Group contacts alphabetically
  const groupedContacts = useMemo(() => {
    const groups: Record<string, Contact[]> = {}
    filteredContacts.forEach(c => {
      const letter = c.name[0]?.toUpperCase() || '#'
      if (!groups[letter]) groups[letter] = []
      groups[letter].push(c)
    })
    return Object.entries(groups).sort(([a], [b]) => a.localeCompare(b))
  }, [filteredContacts])

  const openForm = (contact?: Contact) => {
    if (contact) {
      setEditingContact(contact)
      setFormName(contact.name)
      setFormNumber(contact.number)
    } else {
      setEditingContact(null)
      setFormName('')
      setFormNumber('')
    }
    setShowForm(true)
  }

  const saveContact = async () => {
    if (!formName.trim() || !formNumber.trim()) return
    const res = await nuiFetch<{ success: boolean }>('saveContact', {
      name: formName.trim(),
      number: formNumber.trim(),
      id: editingContact?.id || null,
    })
    if (res?.success) {
      soundManager.send()
      const updated = await nuiFetch<Contact[]>('getContacts')
      if (Array.isArray(updated)) setContacts(updated)
      setShowForm(false)
      setViewContact(null)
    }
  }

  const deleteContact = async (id: number) => {
    await nuiFetch('deleteContact', { id })
    soundManager.delete()
    setContacts(contacts.filter(c => c.id !== id))
    setViewContact(null)
  }

  const toggleFavorite = async (id: number, current: boolean) => {
    await nuiFetch('toggleFavorite', { id, favorite: !current })
    const updated = contacts.map(c => c.id === id ? { ...c, favorite: !current } : c)
    setContacts(updated)
    if (viewContact?.id === id) setViewContact({ ...viewContact, favorite: !current })
  }

  // ==================== RECENTS ====================
  const clearHistory = () => {
    nuiFetch('clearCallHistory')
    setCalls([])
  }

  // Lookup contact name from number
  const getContactName = (num: string) => {
    const digits = num.replace(/\D/g, '')
    const c = contacts.find(c => c.number.replace(/\D/g, '') === digits)
    return c?.name
  }

  // ==================== ACTIVE CALL SCREEN ====================
  if (callState.status === 'active' || callState.status === 'outgoing') {
    return (
      <div className="flex flex-col h-full bg-[#0e0e0f] items-center pt-12 pb-6 relative">
        {/* Caller info */}
        <div className="w-20 h-20 rounded-full bg-phone-accent/20 flex items-center justify-center mb-3">
          <span className="text-phone-accent text-3xl font-bold">
            {(callState.initial || callState.callerName?.[0] || '?').toUpperCase()}
          </span>
        </div>
        <h2 className="text-white text-xl font-semibold">{callState.callerName || number}</h2>
        <p className="text-phone-muted text-sm mt-1">
          {callState.status === 'outgoing' ? 'Calling...' :
           callState.voicemail ? `Voicemail · ${formatCallDuration(callTimer)}` :
           formatCallDuration(callTimer)}
        </p>

        <div className="flex-1" />

        {/* In-call keypad overlay */}
        <AnimatePresence>
          {showCallKeypad && (
            <motion.div
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 30 }}
              className="absolute inset-x-0 top-[180px] flex flex-col items-center"
            >
              <div className="grid grid-cols-3 gap-2">
                {['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'].map(key => (
                  <button
                    key={key}
                    onClick={() => soundManager.dtmf(key)}
                    className="w-[64px] h-[64px] rounded-full bg-white/10 flex items-center justify-center text-white text-xl font-light active:bg-white/25"
                  >
                    {key}
                  </button>
                ))}
              </div>
              <button onClick={() => setShowCallKeypad(false)} className="mt-3 text-phone-accent text-sm">
                Hide
              </button>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Call controls */}
        <div className="grid grid-cols-3 gap-6 mb-8">
          <button onClick={handleMute} className="flex flex-col items-center gap-2">
            <div className={`w-14 h-14 rounded-full flex items-center justify-center transition-colors ${callState.muted ? 'bg-white' : 'bg-white/10'}`}>
              {callState.muted ? <MicOff size={24} className="text-black" /> : <Mic size={24} className="text-white" />}
            </div>
            <span className={`text-xs ${callState.muted ? 'text-white' : 'text-phone-muted'}`}>Mute</span>
          </button>
          <button onClick={() => setShowCallKeypad(!showCallKeypad)} className="flex flex-col items-center gap-2">
            <div className={`w-14 h-14 rounded-full flex items-center justify-center transition-colors ${showCallKeypad ? 'bg-white' : 'bg-white/10'}`}>
              <Grid3X3 size={24} className={showCallKeypad ? 'text-black' : 'text-white'} />
            </div>
            <span className={`text-xs ${showCallKeypad ? 'text-white' : 'text-phone-muted'}`}>Keypad</span>
          </button>
          <button onClick={handleSpeaker} className="flex flex-col items-center gap-2">
            <div className={`w-14 h-14 rounded-full flex items-center justify-center transition-colors ${callState.speaker ? 'bg-white' : 'bg-white/10'}`}>
              {callState.speaker ? <Volume2 size={24} className="text-black" /> : <VolumeX size={24} className="text-white" />}
            </div>
            <span className={`text-xs ${callState.speaker ? 'text-white' : 'text-phone-muted'}`}>Speaker</span>
          </button>
        </div>

        {/* End call */}
        <button onClick={handleEndCall} className="w-16 h-16 rounded-full bg-phone-red flex items-center justify-center active:scale-95 transition-transform">
          <PhoneOff size={28} className="text-white" />
        </button>
      </div>
    )
  }

  // ==================== CONTACT DETAIL VIEW ====================
  if (viewContact) {
    return (
      <div className="flex flex-col h-full bg-[#0e0e0f]">
        {/* Header */}
        <div className="flex items-center justify-between px-4 pt-2 pb-3 min-h-[44px] border-b border-white/5">
          <button onClick={() => setViewContact(null)} className="text-phone-accent text-[15px] flex items-center gap-0.5">
            <span>‹</span> <span>Back</span>
          </button>
          <button onClick={() => openForm(viewContact)} className="text-phone-accent text-[15px]">Edit</button>
        </div>

        {/* Contact card */}
        <div className="flex flex-col items-center pt-8 pb-6">
          <div className="w-24 h-24 rounded-full bg-phone-card flex items-center justify-center mb-3">
            <span className="text-white text-4xl font-light">{viewContact.name[0]?.toUpperCase()}</span>
          </div>
          <h2 className="text-white text-xl font-semibold">{viewContact.name}</h2>
          <p className="text-phone-muted text-sm mt-1">{viewContact.number}</p>
        </div>

        {/* Actions */}
        <div className="flex justify-center gap-8 pb-6">
          <button onClick={() => handleCall(viewContact.number)} className="flex flex-col items-center gap-1.5">
            <div className="w-12 h-12 rounded-full bg-phone-green/20 flex items-center justify-center">
              <Phone size={20} className="text-phone-green" />
            </div>
            <span className="text-phone-green text-[11px]">Call</span>
          </button>
          <button onClick={() => { navigate('messages'); }} className="flex flex-col items-center gap-1.5">
            <div className="w-12 h-12 rounded-full bg-phone-blue/20 flex items-center justify-center">
              <span className="text-phone-blue text-lg">💬</span>
            </div>
            <span className="text-phone-blue text-[11px]">Message</span>
          </button>
          <button onClick={() => toggleFavorite(viewContact.id, viewContact.favorite)} className="flex flex-col items-center gap-1.5">
            <div className="w-12 h-12 rounded-full bg-phone-yellow/20 flex items-center justify-center">
              <Star size={20} className={viewContact.favorite ? 'text-phone-yellow fill-phone-yellow' : 'text-phone-yellow'} />
            </div>
            <span className="text-phone-yellow text-[11px]">{viewContact.favorite ? 'Unfavorite' : 'Favorite'}</span>
          </button>
        </div>

        {/* Info rows */}
        <div className="mx-4 bg-phone-card rounded-xl overflow-hidden divide-y divide-white/5">
          <div className="px-4 py-3.5">
            <p className="text-phone-dim text-[11px] uppercase tracking-wider mb-1">Phone</p>
            <p className="text-phone-accent text-sm">{viewContact.number}</p>
          </div>
        </div>

        <div className="flex-1" />

        {/* Delete */}
        <div className="px-4 pb-6">
          <button
            onClick={() => deleteContact(viewContact.id)}
            className="w-full py-3 bg-phone-red/10 rounded-xl text-phone-red text-sm font-medium"
          >
            Delete Contact
          </button>
        </div>
      </div>
    )
  }

  // ==================== MAIN PHONE UI ====================
  return (
    <div className="flex flex-col h-full bg-[#0e0e0f]">
      {/* Content area */}
      <div className="flex-1 overflow-hidden flex flex-col">
        {/* ========= TAB: FAVORITES ========= */}
        {tab === 'favorites' && (
          <div className="flex-1 overflow-y-auto">
            <div className="px-4 pt-3 pb-2">
              <h1 className="text-white text-[28px] font-bold">Favorites</h1>
            </div>
            {favorites.length === 0 ? (
              <div className="flex flex-col items-center justify-center pt-20">
                <Star size={40} className="text-phone-dim/30 mb-3" />
                <p className="text-phone-muted text-sm">No favorites yet</p>
                <p className="text-phone-dim text-xs mt-1">Mark contacts as favorites for quick access</p>
              </div>
            ) : (
              <div className="px-4 space-y-0">
                {favorites.map(c => (
                  <button
                    key={c.id}
                    onClick={() => setViewContact(c)}
                    className="flex items-center gap-3 w-full py-3 border-b border-white/5 active:bg-white/5 rounded"
                  >
                    <div className="w-10 h-10 rounded-full bg-phone-accent/20 flex items-center justify-center shrink-0">
                      <span className="text-phone-accent font-bold">{c.name[0]?.toUpperCase()}</span>
                    </div>
                    <div className="flex-1 text-left min-w-0">
                      <p className="text-white text-[15px] font-medium truncate">{c.name}</p>
                      <p className="text-phone-dim text-xs">{c.number}</p>
                    </div>
                    <button
                      onClick={(e) => { e.stopPropagation(); handleCall(c.number) }}
                      className="w-8 h-8 rounded-full bg-phone-green/15 flex items-center justify-center shrink-0"
                    >
                      <Phone size={14} className="text-phone-green" />
                    </button>
                  </button>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ========= TAB: RECENTS ========= */}
        {tab === 'recents' && (
          <div className="flex-1 overflow-y-auto">
            <div className="flex items-center justify-between px-4 pt-3 pb-2">
              <h1 className="text-white text-[28px] font-bold">Recents</h1>
              {calls.length > 0 && (
                <button onClick={clearHistory} className="text-phone-accent text-[15px]">Clear</button>
              )}
            </div>
            {calls.length === 0 ? (
              <div className="flex flex-col items-center justify-center pt-20">
                <Phone size={40} className="text-phone-dim/30 mb-3" />
                <p className="text-phone-muted text-sm">No recent calls</p>
              </div>
            ) : (
              <div className="px-4">
                {calls.map(call => {
                  const isOutgoing = call.type === 'outgoing'
                  const isMissed = call.type === 'missed'
                  const otherNumber = call.caller_number === myNumber ? call.receiver_number : call.caller_number
                  const contactName = getContactName(otherNumber)

                  return (
                    <div
                      key={call.id}
                      className="flex items-center gap-3 py-3 border-b border-white/5"
                    >
                      <button
                        onClick={() => { setNumber(otherNumber); setTab('keypad') }}
                        className="flex items-center gap-3 flex-1 min-w-0"
                      >
                        <div className={`shrink-0 ${
                          isMissed ? 'text-phone-red' : isOutgoing ? 'text-white' : 'text-white'
                        }`}>
                          {isMissed ? <PhoneMissed size={16} /> :
                           isOutgoing ? <PhoneOutgoing size={16} /> :
                           <PhoneIncoming size={16} />}
                        </div>
                        <div className="flex-1 text-left min-w-0">
                          <p className={`text-[15px] font-medium truncate ${isMissed ? 'text-phone-red' : 'text-white'}`}>
                            {contactName || otherNumber}
                          </p>
                          <p className="text-phone-dim text-xs">
                            {call.type}{call.duration > 0 ? ` · ${formatCallDuration(call.duration)}` : ''}
                          </p>
                        </div>
                      </button>
                      <span className="text-phone-dim text-xs shrink-0">{timeAgo(call.created_at)}</span>
                      <button
                        onClick={() => handleCall(otherNumber)}
                        className="w-8 h-8 flex items-center justify-center shrink-0"
                      >
                        <Phone size={16} className="text-phone-accent" />
                      </button>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        )}

        {/* ========= TAB: CONTACTS ========= */}
        {tab === 'contacts' && (
          <div className="flex-1 overflow-y-auto flex flex-col">
            <div className="flex items-center justify-between px-4 pt-3 pb-2">
              <h1 className="text-white text-[28px] font-bold">Contacts</h1>
              <button onClick={() => openForm()} className="w-8 h-8 rounded-full bg-phone-accent/15 flex items-center justify-center">
                <Plus size={18} className="text-phone-accent" />
              </button>
            </div>

            {/* Search */}
            <div className="px-4 mb-2">
              <div className="flex items-center bg-phone-card rounded-lg px-3 py-2 gap-2">
                <Search size={14} className="text-phone-dim shrink-0" />
                <input
                  type="text"
                  value={search}
                  onChange={e => setSearch(e.target.value)}
                  onFocus={() => notifyTextFieldFocus(true)}
                  onBlur={() => notifyTextFieldFocus(false)}
                  placeholder="Search"
                  className="flex-1 bg-transparent text-white text-sm outline-none placeholder:text-phone-dim"
                />
                {search && (
                  <button onClick={() => setSearch('')}>
                    <X size={14} className="text-phone-dim" />
                  </button>
                )}
              </div>
            </div>

            {/* Contact list grouped by letter */}
            <div className="flex-1 overflow-y-auto px-4">
              {filteredContacts.length === 0 ? (
                <div className="flex flex-col items-center justify-center pt-16">
                  <p className="text-phone-muted text-sm">{search ? 'No matches' : 'No contacts yet'}</p>
                </div>
              ) : (
                groupedContacts.map(([letter, group]) => (
                  <div key={letter}>
                    <p className="text-phone-dim text-xs font-bold uppercase tracking-wider py-1.5 sticky top-0 bg-[#0e0e0f]">{letter}</p>
                    {group.map(c => (
                      <button
                        key={c.id}
                        onClick={() => setViewContact(c)}
                        className="flex items-center gap-3 w-full py-2.5 border-b border-white/5 active:bg-white/5 rounded"
                      >
                        <div className="w-9 h-9 rounded-full bg-phone-card flex items-center justify-center shrink-0">
                          <span className="text-white font-semibold text-sm">{c.name[0]?.toUpperCase()}</span>
                        </div>
                        <div className="flex-1 text-left min-w-0">
                          <p className="text-white text-[15px] truncate">{c.name}</p>
                        </div>
                        {c.favorite && (
                          <Star size={12} className="text-phone-yellow fill-phone-yellow shrink-0" />
                        )}
                      </button>
                    ))}
                  </div>
                ))
              )}
            </div>
          </div>
        )}

        {/* ========= TAB: KEYPAD ========= */}
        {tab === 'keypad' && (
          <div className="flex flex-col items-center flex-1 justify-end pb-3">
            {/* Number display */}
            <div className="min-h-[56px] flex items-center justify-center px-6 w-full relative">
              <p className={`text-white font-light tracking-wide text-center ${
                rawDigits.length > 7 ? 'text-[26px]' : 'text-[32px]'
              }`}>
                {number || ''}
              </p>
            </div>

            {/* Action row under number */}
            {rawDigits.length > 0 && (
              <div className="flex items-center justify-center gap-4 mb-2">
                {rawDigits.length >= 7 && !contacts.find(c => c.number.replace(/\D/g, '') === rawDigits) && (
                  <button
                    onClick={handleAddContactFromKeypad}
                    className="flex items-center gap-1.5 text-phone-accent text-xs"
                  >
                    <UserPlus size={13} />
                    <span>Add Contact</span>
                  </button>
                )}
                <button
                  onClick={handleCopyNumber}
                  className="flex items-center gap-1.5 text-phone-muted text-xs"
                >
                  <Copy size={12} />
                  <span>Copy</span>
                </button>
              </div>
            )}

            {/* Keypad grid */}
            <div className="grid grid-cols-3 gap-x-6 gap-y-3">
              {[
                { key: '1', sub: '' },
                { key: '2', sub: 'A B C' },
                { key: '3', sub: 'D E F' },
                { key: '4', sub: 'G H I' },
                { key: '5', sub: 'J K L' },
                { key: '6', sub: 'M N O' },
                { key: '7', sub: 'P Q R S' },
                { key: '8', sub: 'T U V' },
                { key: '9', sub: 'W X Y Z' },
                { key: '*', sub: '' },
                { key: '0', sub: '+' },
                { key: '#', sub: '' },
              ].map(({ key, sub }) => (
                <button
                  key={key}
                  onClick={() => handleKey(key)}
                  className="w-[72px] h-[72px] rounded-full bg-phone-card flex flex-col items-center justify-center text-white active:bg-phone-elevated transition-colors"
                >
                  <span className="text-[26px] font-light leading-none">{key}</span>
                  {sub && <span className="text-[9px] tracking-[3px] text-phone-dim mt-0.5 uppercase">{sub}</span>}
                </button>
              ))}
            </div>

            {/* Call / Delete buttons */}
            <div className="flex items-center gap-8 mt-3">
              <div className="w-16" />
              <button
                onClick={() => handleCall()}
                disabled={rawDigits.length < 7}
                className="w-16 h-16 rounded-full bg-phone-green flex items-center justify-center disabled:opacity-40 transition-all active:scale-95"
              >
                <Phone size={28} className="text-white" />
              </button>
              <button
                onClick={handleDelete}
                onContextMenu={(e) => { e.preventDefault(); handleLongDelete() }}
                className={`w-16 h-16 flex items-center justify-center transition-opacity ${number ? 'opacity-100' : 'opacity-0 pointer-events-none'}`}
              >
                <Delete size={24} className="text-phone-muted" />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* ========= BOTTOM TAB BAR ========= */}
      <div className="bg-[#0e0e0f] border-t border-white/5">
        <div className="flex justify-around py-1.5">
          {([
            { id: 'favorites' as Tab, icon: Star, label: 'Favorites' },
            { id: 'recents' as Tab, icon: Phone, label: 'Recents' },
            { id: 'contacts' as Tab, icon: Users, label: 'Contacts' },
            { id: 'keypad' as Tab, icon: Grid3X3, label: 'Keypad' },
          ] as const).map(t => {
            const Icon = t.icon
            const isActive = tab === t.id
            return (
              <button
                key={t.id}
                onClick={() => { soundManager.tap(); setTab(t.id) }}
                className="flex flex-col items-center gap-0.5 min-w-[60px] py-1"
              >
                <Icon size={22} className={isActive ? 'text-phone-accent' : 'text-phone-dim'} fill={isActive && t.id === 'favorites' ? 'currentColor' : 'none'} />
                <span className={`text-[10px] ${isActive ? 'text-phone-accent' : 'text-phone-dim'}`}>{t.label}</span>
              </button>
            )
          })}
        </div>
      </div>

      {/* ========= ADD/EDIT CONTACT FORM OVERLAY ========= */}
      <AnimatePresence>
        {showForm && (
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 25, stiffness: 300 }}
            className="absolute inset-0 bg-[#0e0e0f] z-50 flex flex-col"
          >
            <div className="flex items-center justify-between px-4 pt-4 pb-3 border-b border-white/5">
              <button onClick={() => setShowForm(false)} className="text-phone-accent text-[15px]">Cancel</button>
              <h2 className="text-white font-semibold">{editingContact ? 'Edit Contact' : 'New Contact'}</h2>
              <button
                onClick={saveContact}
                disabled={!formName.trim() || !formNumber.trim()}
                className="text-phone-accent text-[15px] font-semibold disabled:opacity-40"
              >
                Done
              </button>
            </div>

            <div className="px-4 pt-8 space-y-4">
              <div className="flex justify-center mb-4">
                <div className="w-24 h-24 rounded-full bg-phone-card flex items-center justify-center">
                  <span className="text-white text-4xl font-light">{formName ? formName[0]?.toUpperCase() : '?'}</span>
                </div>
              </div>
              <div className="bg-phone-card rounded-xl overflow-hidden divide-y divide-white/5">
                <input
                  type="text"
                  value={formName}
                  onChange={e => setFormName(e.target.value.slice(0, 50))}
                  onFocus={() => notifyTextFieldFocus(true)}
                  onBlur={() => notifyTextFieldFocus(false)}
                  placeholder="First name"
                  className="w-full px-4 py-3.5 text-white text-[15px] bg-transparent outline-none placeholder:text-phone-dim"
                />
                <input
                  type="text"
                  value={formNumber}
                  onChange={e => setFormNumber(e.target.value.slice(0, 20))}
                  onFocus={() => notifyTextFieldFocus(true)}
                  onBlur={() => notifyTextFieldFocus(false)}
                  placeholder="Phone number"
                  className="w-full px-4 py-3.5 text-white text-[15px] bg-transparent outline-none placeholder:text-phone-dim"
                />
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
