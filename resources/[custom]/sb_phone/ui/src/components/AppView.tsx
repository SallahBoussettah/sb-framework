import { motion } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import PhoneApp from '../apps/PhoneApp'
import Messages from '../apps/Messages'
import Camera from '../apps/Camera'
import Gallery from '../apps/Gallery'
import Bank from '../apps/Bank'
import Job from '../apps/Job'
import SettingsApp from '../apps/Settings'
import Social from '../apps/Social'

const appComponents: Record<string, React.FC> = {
  dialer: PhoneApp,
  contacts: PhoneApp,
  messages: Messages,
  camera: Camera,
  gallery: Gallery,
  bank: Bank,
  job: Job,
  settings: SettingsApp,
  social: Social,
}

export default function AppView() {
  const { currentApp } = usePhoneStore()
  const Component = appComponents[currentApp]

  if (!Component) return null

  return (
    <motion.div
      key={currentApp === 'contacts' ? 'dialer' : currentApp}
      initial={{ x: 60, opacity: 0 }}
      animate={{ x: 0, opacity: 1 }}
      exit={{ x: -60, opacity: 0 }}
      transition={{ type: 'spring', damping: 25, stiffness: 300 }}
      className="w-full h-full"
    >
      <Component />
    </motion.div>
  )
}
