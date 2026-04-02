import { create } from 'zustand'
import type { BookingStep, OfficerData, SuspectResult, SuspectProfile, CriminalRecord, BookingConfirmation, MugshotPhoto } from '../types'

interface BookingState {
  isOpen: boolean
  currentStep: BookingStep
  officerData: OfficerData | null
  escortedServerId: number | null

  // Step 1: Lookup
  searchQuery: string
  searchResults: SuspectResult[]
  searchLoading: boolean

  // Step 2: Profile
  selectedSuspect: SuspectProfile | null
  profileLoading: boolean

  // Step 3: Arrest file
  pendingRecords: CriminalRecord[]
  totalMonths: number
  totalSeconds: number
  location: 'mrpd' | 'bolingbroke'

  // Step 3: Mugshot picker
  mugshotFront: string | null
  mugshotSide: string | null
  availableMugshots: MugshotPhoto[]
  mugshotsLoading: boolean
  pickerOpen: boolean
  pickerSlot: 'front' | 'side' | null

  // Step 4: Confirmation
  bookingConfirmation: BookingConfirmation | null
  registerLoading: boolean

  // Actions
  open: (officer: OfficerData, escortedId: number) => void
  close: () => void
  reset: () => void
  setStep: (step: BookingStep) => void
  setSearchQuery: (q: string) => void
  setSearchResults: (results: SuspectResult[]) => void
  setSearchLoading: (v: boolean) => void
  setSelectedSuspect: (profile: SuspectProfile) => void
  setProfileLoading: (v: boolean) => void
  setPendingRecords: (records: CriminalRecord[], months: number, seconds: number, loc: 'mrpd' | 'bolingbroke') => void
  setBookingConfirmation: (conf: BookingConfirmation) => void
  setRegisterLoading: (v: boolean) => void
  setAvailableMugshots: (photos: MugshotPhoto[]) => void
  setMugshotsLoading: (v: boolean) => void
  openPicker: (slot: 'front' | 'side') => void
  closePicker: () => void
  selectMugshot: (url: string) => void
  clearMugshot: (slot: 'front' | 'side') => void
}

const initialState = {
  isOpen: false,
  currentStep: 'lookup' as BookingStep,
  officerData: null,
  escortedServerId: null,
  searchQuery: '',
  searchResults: [],
  searchLoading: false,
  selectedSuspect: null,
  profileLoading: false,
  pendingRecords: [],
  totalMonths: 0,
  totalSeconds: 0,
  location: 'mrpd' as const,
  mugshotFront: null as string | null,
  mugshotSide: null as string | null,
  availableMugshots: [] as MugshotPhoto[],
  mugshotsLoading: false,
  pickerOpen: false,
  pickerSlot: null as 'front' | 'side' | null,
  bookingConfirmation: null,
  registerLoading: false,
}

export const useBookingStore = create<BookingState>((set) => ({
  ...initialState,

  open: (officer, escortedId) => set({
    isOpen: true,
    currentStep: 'lookup',
    officerData: officer,
    escortedServerId: escortedId,
    searchQuery: '',
    searchResults: [],
    selectedSuspect: null,
    pendingRecords: [],
    bookingConfirmation: null,
    mugshotFront: null,
    mugshotSide: null,
    availableMugshots: [],
    pickerOpen: false,
    pickerSlot: null,
  }),

  close: () => set({ isOpen: false }),

  reset: () => set(initialState),

  setStep: (step) => set({ currentStep: step }),
  setSearchQuery: (q) => set({ searchQuery: q }),
  setSearchResults: (results) => set({ searchResults: results, searchLoading: false }),
  setSearchLoading: (v) => set({ searchLoading: v }),
  setSelectedSuspect: (profile) => set({ selectedSuspect: profile, profileLoading: false }),
  setProfileLoading: (v) => set({ profileLoading: v }),

  setPendingRecords: (records, months, seconds, loc) => set({
    pendingRecords: records,
    totalMonths: months,
    totalSeconds: seconds,
    location: loc,
  }),

  setBookingConfirmation: (conf) => set({
    bookingConfirmation: conf,
    registerLoading: false,
  }),

  setRegisterLoading: (v) => set({ registerLoading: v }),

  setAvailableMugshots: (photos) => set({ availableMugshots: photos, mugshotsLoading: false }),
  setMugshotsLoading: (v) => set({ mugshotsLoading: v }),

  openPicker: (slot) => set({ pickerOpen: true, pickerSlot: slot }),
  closePicker: () => set({ pickerOpen: false, pickerSlot: null }),

  selectMugshot: (url) => set((state) => ({
    ...(state.pickerSlot === 'front' ? { mugshotFront: url } : { mugshotSide: url }),
    pickerOpen: false,
    pickerSlot: null,
  })),

  clearMugshot: (slot) => set(slot === 'front' ? { mugshotFront: null } : { mugshotSide: null }),
}))
