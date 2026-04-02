import { create } from 'zustand'

export interface GarageVehicle {
  model: string
  label: string
  grade: number
  category: string
  image?: string
}

export interface VehicleCategory {
  id: string
  label: string
  icon: string
}

export interface Rank {
  grade: number
  name: string
  salary: number
}

export type GradeMode = 'exact' | 'cumulative'

interface GarageState {
  isOpen: boolean
  vehicles: GarageVehicle[]
  categories: VehicleCategory[]
  playerGrade: number
  ranks: Rank[]
  gradeMode: GradeMode
  garageData: {
    garageId: string
    spawnPoints: Array<{ coords: { x: number; y: number; z: number }; heading: number }>
    label: string
  } | null

  selectedCategory: string
  selectedVehicle: GarageVehicle | null

  // Actions
  openGarage: (data: {
    vehicles: GarageVehicle[]
    categories: VehicleCategory[]
    playerGrade: number
    ranks: Rank[]
    garageData: any
    gradeMode?: GradeMode
  }) => void
  closeGarage: () => void
  setSelectedCategory: (category: string) => void
  setSelectedVehicle: (vehicle: GarageVehicle | null) => void
}

export const useGarageStore = create<GarageState>((set) => ({
  isOpen: false,
  vehicles: [],
  categories: [],
  playerGrade: 0,
  ranks: [],
  gradeMode: 'exact',
  garageData: null,
  selectedCategory: 'all',
  selectedVehicle: null,

  openGarage: (data) =>
    set({
      isOpen: true,
      vehicles: data.vehicles,
      categories: data.categories,
      playerGrade: data.playerGrade,
      ranks: data.ranks,
      gradeMode: data.gradeMode || 'exact',
      garageData: data.garageData,
      selectedCategory: 'all',
      selectedVehicle: null,
    }),

  closeGarage: () =>
    set({
      isOpen: false,
      selectedVehicle: null,
    }),

  setSelectedCategory: (category) =>
    set({
      selectedCategory: category,
      selectedVehicle: null,
    }),

  setSelectedVehicle: (vehicle) => set({ selectedVehicle: vehicle }),
}))
