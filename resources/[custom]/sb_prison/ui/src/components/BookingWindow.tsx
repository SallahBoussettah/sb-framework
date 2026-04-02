import { motion, AnimatePresence } from 'framer-motion'
import { useBookingStore } from '../store/bookingStore'
import { Header } from './Header'
import { StepIndicator } from './StepIndicator'
import { SuspectLookup } from '../pages/SuspectLookup'
import { SuspectProfile } from '../pages/SuspectProfile'
import { ArrestFile } from '../pages/ArrestFile'
import { Confirmation } from '../pages/Confirmation'

export function BookingWindow() {
  const { isOpen, currentStep } = useBookingStore()

  if (!isOpen) return null

  const renderStep = () => {
    switch (currentStep) {
      case 'lookup': return <SuspectLookup />
      case 'profile': return <SuspectProfile />
      case 'arrest-file': return <ArrestFile />
      case 'confirmation': return <Confirmation />
    }
  }

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          className="fixed inset-0 flex items-center justify-center z-50"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
        >
          {/* Dark overlay */}
          <div className="absolute inset-0 bg-black/70" />

          {/* Terminal window */}
          <motion.div
            className="relative w-[900px] h-[620px] bg-booking-bg-primary border border-booking-border rounded-lg overflow-hidden flex flex-col shadow-2xl"
            initial={{ scale: 0.95, y: 20 }}
            animate={{ scale: 1, y: 0 }}
            exit={{ scale: 0.95, y: 20 }}
            transition={{ duration: 0.25, ease: 'easeOut' }}
          >
            <Header />
            <StepIndicator />
            <div className="flex-1 overflow-y-auto p-5">
              <AnimatePresence mode="wait">
                <motion.div
                  key={currentStep}
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -20 }}
                  transition={{ duration: 0.2 }}
                  className="h-full"
                >
                  {renderStep()}
                </motion.div>
              </AnimatePresence>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
