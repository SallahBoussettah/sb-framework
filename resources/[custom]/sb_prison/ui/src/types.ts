export interface OfficerData {
  name: string
  citizenid: string
  badge: string
  grade: number
}

export interface SuspectResult {
  citizenid: string
  firstname: string
  lastname: string
  dob: string
  gender: string
}

export interface CriminalRecord {
  id: number
  charges: string
  jail_time: number
  fine: number
  officer_name: string
  created_at: string
  served: boolean
}

export interface SuspectProfile {
  citizenid: string
  firstname: string
  lastname: string
  dob: string
  gender: string
  phone: string
  job: string
  records: CriminalRecord[]
}

export interface MugshotPhoto {
  id: number
  url: string
  createdAt: string
}

export interface BookingConfirmation {
  sentenceId: number
  suspectName: string
  citizenid: string
  totalMonths: number
  totalSeconds: number
  location: 'mrpd' | 'bolingbroke'
  charges: string
  mugshotFront: string | null
  mugshotSide: string | null
}

export type BookingStep = 'lookup' | 'profile' | 'arrest-file' | 'confirmation'
