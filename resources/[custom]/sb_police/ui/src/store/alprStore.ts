import { create } from 'zustand'
import type { ALPRVehicle } from '../types'

interface ALPRState {
  isActive: boolean
  isLocked: boolean
  lockedPlate: string | null
  front: ALPRVehicle | null
  rear: ALPRVehicle | null

  // Actions
  showALPR: () => void
  hideALPR: () => void
  updateALPR: (data: {
    front: ALPRVehicle | null
    rear: ALPRVehicle | null
    locked: boolean
    lockedPlate: string | null
  }) => void
}

export const useALPRStore = create<ALPRState>((set) => ({
  isActive: false,
  isLocked: false,
  lockedPlate: null,
  front: null,
  rear: null,

  showALPR: () => set({ isActive: true }),
  hideALPR: () => set({
    isActive: false,
    front: null,
    rear: null,
    isLocked: false,
    lockedPlate: null
  }),
  updateALPR: (data) => set({
    front: data.front,
    rear: data.rear,
    isLocked: data.locked,
    lockedPlate: data.lockedPlate,
  }),
}))
