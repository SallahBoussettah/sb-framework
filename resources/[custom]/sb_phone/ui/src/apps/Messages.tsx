import { useState, useRef, useEffect, useMemo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { nuiFetch, notifyTextFieldFocus } from '../utils/nui'
import { soundManager } from '../utils/sound'
import { timeAgo } from '../utils/time'
import AppHeader from '../components/AppHeader'
import { Send, ArrowLeft } from 'lucide-react'

interface Conversation {
  otherNumber: string
  contactName: string | null
  lastMessage: string
  lastTime: string
  unread: number
}

export default function Messages() {
  const { messages, contacts, myNumber, setMessages } = usePhoneStore()
  const [selectedConvo, setSelectedConvo] = useState<string | null>(null)
  const [text, setText] = useState('')
  const scrollRef = useRef<HTMLDivElement>(null)

  // Build conversations list
  const conversations = useMemo<Conversation[]>(() => {
    const map = new Map<string, Conversation>()
    messages.forEach(m => {
      const other = m.sender_number === myNumber ? m.receiver_number : m.sender_number
      const existing = map.get(other)
      const isUnread = m.receiver_number === myNumber && !m.is_read
      if (!existing || new Date(m.created_at) > new Date(existing.lastTime)) {
        const contact = contacts.find(c => c.number === other)
        map.set(other, {
          otherNumber: other,
          contactName: contact?.name || null,
          lastMessage: m.message,
          lastTime: m.created_at,
          unread: (existing?.unread || 0) + (isUnread ? 1 : 0),
        })
      } else if (isUnread) {
        existing.unread++
      }
    })
    return Array.from(map.values()).sort((a, b) =>
      new Date(b.lastTime).getTime() - new Date(a.lastTime).getTime()
    )
  }, [messages, contacts, myNumber])

  // Messages for selected conversation
  const convoMessages = useMemo(() => {
    if (!selectedConvo) return []
    return messages.filter(m =>
      (m.sender_number === selectedConvo && m.receiver_number === myNumber) ||
      (m.sender_number === myNumber && m.receiver_number === selectedConvo)
    )
  }, [messages, selectedConvo, myNumber])

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [convoMessages])

  const openConvo = (number: string) => {
    setSelectedConvo(number)
    nuiFetch('markMessagesRead', { otherNumber: number })
  }

  const sendMessage = () => {
    if (!text.trim() || !selectedConvo) return
    nuiFetch('sendMessage', { receiverNumber: selectedConvo, text: text.trim() })
    soundManager.send()

    // Optimistic update
    const newMsg = {
      id: Date.now(),
      sender_number: myNumber,
      receiver_number: selectedConvo,
      message: text.trim(),
      is_read: 1,
      created_at: new Date().toISOString(),
    }
    setMessages([...messages, newMsg])
    setText('')
  }

  const contactName = (number: string) => {
    return contacts.find(c => c.number === number)?.name || number
  }

  if (selectedConvo) {
    return (
      <div className="flex flex-col h-full bg-[#0e0e0f]">
        {/* Convo header */}
        <div className="flex items-center gap-3 px-4 pt-2 pb-3 border-b border-white/5">
          <button onClick={() => { setSelectedConvo(null); notifyTextFieldFocus(false) }} className="text-phone-accent">
            <ArrowLeft size={22} />
          </button>
          <div className="w-9 h-9 rounded-full bg-phone-accent/20 flex items-center justify-center">
            <span className="text-phone-accent text-sm font-bold">{contactName(selectedConvo)[0]?.toUpperCase()}</span>
          </div>
          <div>
            <p className="text-white text-sm font-semibold">{contactName(selectedConvo)}</p>
            <p className="text-phone-dim text-[11px]">{selectedConvo}</p>
          </div>
        </div>

        {/* Messages */}
        <div ref={scrollRef} className="flex-1 overflow-y-auto px-4 py-3 space-y-2">
          {convoMessages.map((m, i) => {
            const isMine = m.sender_number === myNumber
            return (
              <motion.div
                key={m.id}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                className={`flex ${isMine ? 'justify-end' : 'justify-start'}`}
              >
                <div className={`max-w-[75%] px-3.5 py-2 rounded-2xl ${
                  isMine
                    ? 'bg-phone-accent text-white rounded-br-md'
                    : 'bg-phone-card text-white rounded-bl-md'
                }`}>
                  <p className="text-[14px] leading-snug break-words">{m.message}</p>
                  <p className={`text-[10px] mt-1 ${isMine ? 'text-white/60' : 'text-phone-dim'}`}>
                    {timeAgo(m.created_at)}
                  </p>
                </div>
              </motion.div>
            )
          })}
        </div>

        {/* Input */}
        <div className="px-3 pb-3 pt-2 border-t border-white/5">
          <div className="flex items-center gap-2 bg-phone-card rounded-full px-4 py-2">
            <input
              type="text"
              value={text}
              onChange={e => setText(e.target.value.slice(0, 256))}
              onFocus={() => notifyTextFieldFocus(true)}
              onBlur={() => notifyTextFieldFocus(false)}
              onKeyDown={e => e.key === 'Enter' && sendMessage()}
              placeholder="Message..."
              className="flex-1 bg-transparent text-white text-sm outline-none placeholder:text-phone-dim"
            />
            <button
              onClick={sendMessage}
              disabled={!text.trim()}
              className="w-8 h-8 rounded-full bg-phone-accent flex items-center justify-center disabled:opacity-40 transition-opacity"
            >
              <Send size={14} className="text-white" />
            </button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="flex flex-col h-full bg-[#0e0e0f]">
      <AppHeader title="Messages" />

      <div className="flex-1 overflow-y-auto">
        {conversations.length === 0 ? (
          <p className="text-phone-muted text-center mt-16 text-sm">No messages yet</p>
        ) : (
          conversations.map(convo => (
            <button
              key={convo.otherNumber}
              onClick={() => openConvo(convo.otherNumber)}
              className="flex items-center gap-3 w-full px-4 py-3 border-b border-white/5 text-left"
            >
              <div className="w-11 h-11 rounded-full bg-phone-accent/20 flex items-center justify-center shrink-0">
                <span className="text-phone-accent font-bold">
                  {(convo.contactName || convo.otherNumber)[0]?.toUpperCase()}
                </span>
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between">
                  <p className={`text-sm truncate ${convo.unread ? 'text-white font-semibold' : 'text-white font-medium'}`}>
                    {convo.contactName || convo.otherNumber}
                  </p>
                  <span className="text-phone-dim text-[11px] shrink-0 ml-2">{timeAgo(convo.lastTime)}</span>
                </div>
                <div className="flex items-center justify-between">
                  <p className={`text-xs truncate ${convo.unread ? 'text-white' : 'text-phone-dim'}`}>
                    {convo.lastMessage}
                  </p>
                  {convo.unread > 0 && (
                    <div className="min-w-[20px] h-[20px] rounded-full bg-phone-accent flex items-center justify-center px-1 ml-2">
                      <span className="text-white text-[10px] font-bold">{convo.unread}</span>
                    </div>
                  )}
                </div>
              </div>
            </button>
          ))
        )}
      </div>
    </div>
  )
}
