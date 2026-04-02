import { useBookingStore } from '../store/bookingStore'
import type { BookingStep } from '../types'

const steps: { key: BookingStep; label: string; icon: string }[] = [
  { key: 'lookup', label: 'Suspect Lookup', icon: 'fa-magnifying-glass' },
  { key: 'profile', label: 'Profile & Charges', icon: 'fa-user' },
  { key: 'arrest-file', label: 'Arrest File', icon: 'fa-file-lines' },
  { key: 'confirmation', label: 'Confirmation', icon: 'fa-check-circle' },
]

const stepOrder: BookingStep[] = ['lookup', 'profile', 'arrest-file', 'confirmation']

export function StepIndicator() {
  const { currentStep } = useBookingStore()
  const currentIndex = stepOrder.indexOf(currentStep)

  return (
    <div className="flex items-center gap-0 px-5 py-2.5 bg-booking-bg-secondary/50 border-b border-booking-border">
      {steps.map((step, i) => {
        const isActive = step.key === currentStep
        const isCompleted = i < currentIndex

        return (
          <div key={step.key} className="flex items-center flex-1">
            <div className="flex items-center gap-2 flex-1">
              <div className={`
                w-7 h-7 rounded-full flex items-center justify-center text-xs shrink-0
                ${isActive ? 'bg-booking-accent text-white' : ''}
                ${isCompleted ? 'bg-booking-success text-white' : ''}
                ${!isActive && !isCompleted ? 'bg-booking-bg-elevated text-booking-text-muted' : ''}
              `}>
                {isCompleted ? (
                  <i className="fas fa-check text-[10px]" />
                ) : (
                  <i className={`fas ${step.icon} text-[10px]`} />
                )}
              </div>
              <span className={`text-[11px] font-medium whitespace-nowrap ${
                isActive ? 'text-white' : isCompleted ? 'text-booking-success' : 'text-booking-text-muted'
              }`}>
                {step.label}
              </span>
            </div>
            {i < steps.length - 1 && (
              <div className={`h-px flex-1 mx-3 min-w-[20px] ${
                isCompleted ? 'bg-booking-success' : 'bg-booking-border'
              }`} />
            )}
          </div>
        )
      })}
    </div>
  )
}
