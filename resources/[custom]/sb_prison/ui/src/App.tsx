import { useEffect } from 'react'
import { BookingWindow } from './components/BookingWindow'
import { useBookingStore } from './store/bookingStore'
import { onNuiMessage, fetchNui, isEnvBrowser, debugData } from './utils/nui'
import type { OfficerData, SuspectResult, SuspectProfile, BookingConfirmation, MugshotPhoto } from './types'

export default function App() {
  useEffect(() => {
    const s = useBookingStore.getState

    const unsub1 = onNuiMessage<{ officer: OfficerData; escortedId: number }>('open', (data) => {
      s().open(data.officer, data.escortedId)
    })

    const unsub2 = onNuiMessage<{ results: SuspectResult[] }>('searchResults', (data) => {
      s().setSearchResults(data.results)
    })

    const unsub3 = onNuiMessage<{ profile: SuspectProfile }>('suspectProfile', (data) => {
      s().setSelectedSuspect(data.profile)
    })

    const unsub4 = onNuiMessage<{ confirmation: BookingConfirmation }>('bookingComplete', (data) => {
      s().setBookingConfirmation(data.confirmation)
      s().setStep('confirmation')
    })

    const unsub5 = onNuiMessage('forceClose', () => {
      s().close()
    })

    const unsub6 = onNuiMessage<{ photos: MugshotPhoto[] }>('mugshotList', (data) => {
      s().setAvailableMugshots(data.photos)
    })

    return () => {
      unsub1(); unsub2(); unsub3(); unsub4(); unsub5(); unsub6()
    }
  }, [])

  // ESC key to close
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const s = useBookingStore.getState()
      if (e.key === 'Escape' && s.isOpen) {
        if (s.currentStep === 'lookup' || s.currentStep === 'confirmation') {
          fetchNui('close')
        }
      }
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [])

  // Dev mode mock data
  useEffect(() => {
    if (!isEnvBrowser()) return
    debugData([
      {
        type: 'open',
        data: {
          officer: { name: 'John Smith', citizenid: 'ABC123', badge: '1234', grade: 3 },
          escortedId: 2,
        },
      },
    ])
  }, [])

  return <BookingWindow />
}
