import { useEffect } from 'react'
import { motion } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { nuiFetch } from '../utils/nui'
import AppHeader from '../components/AppHeader'
import { Briefcase, Shield, Clock, BadgeCheck } from 'lucide-react'

export default function Job() {
  const { jobData, setJobData } = usePhoneStore()

  useEffect(() => {
    nuiFetch<any>('getJobData').then(data => {
      if (data?.title) setJobData(data)
    })
  }, [])

  const items = [
    { icon: <Briefcase size={18} />, label: 'Position', value: jobData.title, color: 'text-phone-blue' },
    { icon: <Shield size={18} />, label: 'Rank', value: jobData.rank, color: 'text-phone-purple' },
    { icon: <BadgeCheck size={18} />, label: 'Badge', value: jobData.badge || 'N/A', color: 'text-phone-yellow' },
    { icon: <Clock size={18} />, label: 'Status', value: jobData.onDuty ? 'On Duty' : 'Off Duty', color: jobData.onDuty ? 'text-phone-green' : 'text-phone-red' },
  ]

  return (
    <div className="flex flex-col h-full bg-[#0e0e0f]">
      <AppHeader title="Job" />

      <div className="px-4 space-y-4">
        {/* Header card */}
        <motion.div
          initial={{ y: 10, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          className="bg-gradient-to-br from-indigo-600/60 to-blue-800/60 rounded-2xl p-5 text-center"
        >
          <div className="w-16 h-16 rounded-full bg-white/10 flex items-center justify-center mx-auto mb-3">
            <Briefcase size={28} className="text-white" />
          </div>
          <h2 className="text-white text-xl font-bold">{jobData.title}</h2>
          <p className="text-white/60 text-sm mt-1">{jobData.department}</p>
        </motion.div>

        {/* Details */}
        <div className="bg-phone-card rounded-xl overflow-hidden divide-y divide-white/5">
          {items.map((item, i) => (
            <motion.div
              key={item.label}
              initial={{ x: -10, opacity: 0 }}
              animate={{ x: 0, opacity: 1 }}
              transition={{ delay: i * 0.05 }}
              className="flex items-center gap-3 px-4 py-3.5"
            >
              <div className={`${item.color}`}>{item.icon}</div>
              <span className="text-phone-muted text-sm flex-1">{item.label}</span>
              <span className={`text-sm font-medium ${item.color}`}>{item.value}</span>
            </motion.div>
          ))}
        </div>
      </div>
    </div>
  )
}
