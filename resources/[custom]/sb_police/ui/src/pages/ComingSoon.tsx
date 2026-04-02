import { MessageSquare, AlertTriangle, Users, Video, Lock, Clock } from 'lucide-react'
import { motion } from 'framer-motion'

interface ComingSoonProps {
  title: string
  description: string
  icon: 'dispatch' | 'alert' | 'users' | 'camera' | 'lock' | 'clock'
}

const icons = {
  dispatch: MessageSquare,
  alert: AlertTriangle,
  users: Users,
  camera: Video,
  lock: Lock,
  clock: Clock,
}

export default function ComingSoon({ title, description, icon }: ComingSoonProps) {
  const Icon = icons[icon]

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="absolute inset-0 flex flex-col items-center justify-center text-center p-6"
    >
      <Icon className="w-20 h-20 text-mdt-text-muted opacity-30 mb-6" />
      <h2 className="font-heading text-3xl tracking-wider text-mdt-text-secondary mb-2">{title}</h2>
      <p className="text-lg font-semibold text-mdt-accent uppercase tracking-widest mb-4">Coming Soon</p>
      <p className="text-sm text-mdt-text-muted max-w-md">{description}</p>
    </motion.div>
  )
}
