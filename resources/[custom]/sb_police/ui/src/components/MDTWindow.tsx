import { motion } from 'framer-motion'
import Header from './Header'
import Sidebar from './Sidebar'
import Dashboard from '../pages/Dashboard'
import Citizens from '../pages/Citizens'
import Vehicles from '../pages/Vehicles'
import Reports from '../pages/Reports'
import PenalCode from '../pages/PenalCode'
import Warrants from '../pages/Warrants'
import Officers from '../pages/Officers'
import TimeClock from '../pages/TimeClock'
import Dispatch from '../pages/Dispatch'
import ComingSoon from '../pages/ComingSoon'
import { useMDTStore } from '../store/mdtStore'

export default function MDTWindow() {
  const { currentPage } = useMDTStore()

  const renderPage = () => {
    switch (currentPage) {
      case 'dashboard':
        return <Dashboard />
      case 'citizens':
        return <Citizens />
      case 'vehicles':
        return <Vehicles />
      case 'reports':
        return <Reports />
      case 'penal-code':
        return <PenalCode />
      case 'warrants':
        return <Warrants />
      case 'officers':
        return <Officers />
      case 'clock':
        return <TimeClock />
      case 'dispatch':
        return <Dispatch />
      case 'cameras':
        return <ComingSoon title="Security Cameras" description="Access business, vehicle, and bodycam feeds" icon="camera" />
      case 'federal':
        return <ComingSoon title="Federal Prison" description="Manage long-term inmates at Bolingbroke" icon="lock" />
      default:
        return <Dashboard />
    }
  }

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.98 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.98 }}
      transition={{ duration: 0.3, ease: 'easeOut' }}
      className="fixed inset-0 pointer-events-auto z-50 mdt-bg-image"
    >
      {/* Dark overlay — NO backdrop-filter blur */}
      <div className="absolute inset-0 bg-black/90" />

      {/* Content */}
      <div className="relative z-10 flex flex-col h-full">
        <Header />
        <div className="flex-1 flex overflow-hidden">
          <Sidebar />
          <main className="flex-1 overflow-hidden relative">
            {renderPage()}
          </main>
        </div>
      </div>
    </motion.div>
  )
}
