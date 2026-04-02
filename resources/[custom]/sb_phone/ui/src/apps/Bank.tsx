import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { nuiFetch, notifyTextFieldFocus } from '../utils/nui'
import { soundManager } from '../utils/sound'
import AppHeader from '../components/AppHeader'
import { CreditCard, Send, RefreshCw, DollarSign, Wallet } from 'lucide-react'

export default function Bank() {
  const { bankData, setBankData } = usePhoneStore()
  const [showTransfer, setShowTransfer] = useState(false)
  const [targetPhone, setTargetPhone] = useState('')
  const [amount, setAmount] = useState('')
  const [status, setStatus] = useState<'idle' | 'sending' | 'success' | 'error'>('idle')
  const [errorMsg, setErrorMsg] = useState('')

  const refresh = async () => {
    const data = await nuiFetch<{ cash: number; bank: number }>('getBankData')
    if (data) setBankData(data)
  }

  const transfer = async () => {
    const amt = parseInt(amount)
    if (!targetPhone.trim() || isNaN(amt) || amt < 1) return

    setStatus('sending')
    const res = await nuiFetch<{ success: boolean; message?: string; newBalance?: { cash: number; bank: number } }>('transferMoney', {
      targetPhone: targetPhone.trim(),
      amount: amt,
    })

    if (res.success && res.newBalance) {
      setStatus('success')
      setBankData(res.newBalance)
      soundManager.send()
      setTimeout(() => {
        setShowTransfer(false)
        setStatus('idle')
        setTargetPhone('')
        setAmount('')
      }, 1500)
    } else {
      setStatus('error')
      setErrorMsg(res.message || 'Transfer failed')
      setTimeout(() => setStatus('idle'), 2000)
    }
  }

  const formatMoney = (n: number) => '$' + n.toLocaleString()

  return (
    <div className="flex flex-col h-full bg-[#0e0e0f]">
      <AppHeader
        title="Wallet"
        rightAction={
          <button onClick={refresh}>
            <RefreshCw size={18} className="text-phone-accent" />
          </button>
        }
      />

      <div className="px-4 space-y-4 flex-1">
        {/* Balance card */}
        <motion.div
          initial={{ y: 10, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          className="bg-gradient-to-br from-phone-accent/80 to-orange-700 rounded-2xl p-5 relative overflow-hidden"
        >
          <div className="absolute top-0 right-0 w-32 h-32 bg-white/5 rounded-full -translate-y-8 translate-x-8" />
          <div className="flex items-center gap-2 mb-4">
            <CreditCard size={18} className="text-white/70" />
            <span className="text-white/70 text-xs font-medium uppercase tracking-wider">Bank Account</span>
          </div>
          <p className="text-white text-4xl font-bold">{formatMoney(bankData.bank)}</p>
          <div className="flex items-center gap-2 mt-4">
            <Wallet size={14} className="text-white/60" />
            <span className="text-white/60 text-sm">Cash: {formatMoney(bankData.cash)}</span>
          </div>
        </motion.div>

        {/* Transfer section */}
        {!showTransfer ? (
          <button
            onClick={() => setShowTransfer(true)}
            className="w-full bg-phone-card rounded-xl p-4 flex items-center gap-3 active:bg-phone-elevated transition-colors"
          >
            <div className="w-10 h-10 rounded-full bg-phone-accent/20 flex items-center justify-center">
              <Send size={18} className="text-phone-accent" />
            </div>
            <div className="text-left">
              <p className="text-white text-sm font-medium">Transfer Money</p>
              <p className="text-phone-dim text-xs">Send to phone number</p>
            </div>
          </button>
        ) : (
          <motion.div
            initial={{ y: 10, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            className="bg-phone-card rounded-xl p-4 space-y-3"
          >
            <p className="text-white text-sm font-semibold">Transfer</p>
            <input
              type="text"
              value={targetPhone}
              onChange={e => setTargetPhone(e.target.value)}
              onFocus={() => notifyTextFieldFocus(true)}
              onBlur={() => notifyTextFieldFocus(false)}
              placeholder="Recipient phone number"
              className="w-full bg-phone-bg rounded-lg px-3 py-2.5 text-white text-sm outline-none placeholder:text-phone-dim"
            />
            <div className="relative">
              <DollarSign size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-phone-dim" />
              <input
                type="number"
                value={amount}
                onChange={e => setAmount(e.target.value)}
                onFocus={() => notifyTextFieldFocus(true)}
                onBlur={() => notifyTextFieldFocus(false)}
                placeholder="Amount"
                min={1}
                className="w-full bg-phone-bg rounded-lg pl-8 pr-3 py-2.5 text-white text-sm outline-none placeholder:text-phone-dim"
              />
            </div>

            {status === 'error' && (
              <p className="text-phone-red text-xs">{errorMsg}</p>
            )}
            {status === 'success' && (
              <p className="text-phone-green text-xs">Transfer complete!</p>
            )}

            <div className="flex gap-2">
              <button
                onClick={() => { setShowTransfer(false); setStatus('idle') }}
                className="flex-1 py-2.5 rounded-lg bg-phone-bg text-phone-muted text-sm"
              >
                Cancel
              </button>
              <button
                onClick={transfer}
                disabled={status === 'sending'}
                className="flex-1 py-2.5 rounded-lg bg-phone-accent text-white text-sm font-semibold disabled:opacity-50"
              >
                {status === 'sending' ? 'Sending...' : 'Send'}
              </button>
            </div>
          </motion.div>
        )}
      </div>
    </div>
  )
}
