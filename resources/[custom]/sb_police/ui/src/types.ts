// =============================================
// Officer & Duty Types
// =============================================

export interface OfficerData {
  name: string
  rank: string
  badge: string
  isOnDuty: boolean
  grade: number
}

export interface OnDutyOfficer {
  source: number
  name: string
  rank: string
  status: 'available' | 'busy' | 'responding' | 'unavailable'
  onDuty: boolean
}

// =============================================
// Citizen Types
// =============================================

export interface Citizen {
  id: string
  citizenid: string
  firstname: string
  lastname: string
  dob?: string
  gender?: string
  phone?: string
  nationality?: string
  job?: string
  jobGrade?: string
  licenses?: {
    driver?: boolean
    weapon?: boolean
  }
  bank?: number
  wanted?: boolean
}

export interface CitizenDetail extends Citizen {
  criminalRecords: CriminalRecord[]
  citations: Citation[]
  notes: CitizenNote[]
  outstandingFines: number
  mugshot?: string
  mugshotSide?: string
}

// =============================================
// Vehicle Types
// =============================================

export interface Vehicle {
  id: string
  plate: string
  vehicle: string
  owner?: string
  ownerId?: string
  wanted?: boolean
}

export interface VehicleDetail extends Vehicle {
  class?: string
  registration?: 'valid' | 'expired' | 'none'
  insurance?: 'valid' | 'expired' | 'none'
  registeredDate?: string
  flags: VehicleFlag[]
}

export interface VehicleFlag {
  type: 'stolen' | 'bolo' | 'wanted'
  note?: string
  addedBy?: string
  addedAt?: string
}

// =============================================
// Criminal Records & Charges
// =============================================

export interface PenalCodeEntry {
  id: number
  category: string
  title: string
  description: string
  fine: number
  jail_time: number
}

export interface CriminalRecord {
  id: number
  citizenid: string
  charges: string
  fine: number
  jailTime: number
  officerId: string
  officerName: string
  paid: boolean
  amountPaid: number
  served: boolean
  createdAt: string
}

export interface Citation {
  id: number
  citizenid: string
  citizenName: string
  offense: string
  fine: number
  notes?: string
  vehiclePlate?: string
  location?: string
  officerId: string
  officerName: string
  paid: boolean
  createdAt: string
}

export interface CitizenNote {
  id: number
  note: string
  officerId: string
  officerName: string
  createdAt: string
}

export interface SelectedCharge {
  uid: string
  id: number
  title: string
  category: string
  fine: number
  jailTime: number
}

// =============================================
// Reports
// =============================================

export interface Report {
  id: number
  title: string
  description?: string
  location?: string
  authorId: string
  authorName: string
  officers: string[]
  suspects: string[]
  victims: string[]
  vehicles: string[]
  evidence: string[]
  tags: string[]
  status: 'open' | 'closed' | 'pending'
  createdAt: string
  updatedAt: string
}

// =============================================
// Warrants & BOLOs
// =============================================

export interface Warrant {
  id: number
  citizenid: string
  citizenName: string
  charges: string
  reason?: string
  priority: 'low' | 'medium' | 'high'
  status: 'active' | 'closed'
  issuedBy: string
  issuedById: string
  closedBy?: string
  closedReason?: string
  createdAt: string
  updatedAt: string
}

export interface BOLO {
  id: number
  personName: string
  description: string
  reason: string
  lastSeen?: string
  priority: 'low' | 'medium' | 'high'
  status: 'active' | 'closed'
  issuedBy: string
  issuedById: string
  closedBy?: string
  closedReason?: string
  createdAt: string
  updatedAt: string
}

// =============================================
// Officer Roster
// =============================================

export interface OfficerRoster {
  citizenid: string
  name: string
  rank: string
  grade: number
  isOnline: boolean
  isOnDuty: boolean
  source?: number
  status?: 'available' | 'busy' | 'responding' | 'unavailable'
}

// =============================================
// Duty Stats / Time Clock
// =============================================

export interface DutyRecord {
  id: number
  officerId: string
  officerName: string
  clockIn: string
  clockOut: string | null
  durationMinutes: number
}

export interface DutyStats {
  totalMinutesWeek: number
  totalMinutesMonth: number
  currentShiftMinutes: number
  records: DutyRecord[]
}

// =============================================
// Alerts / Dispatch
// =============================================

export interface Alert {
  id: string
  title: string
  location: string
  coords?: { x: number; y: number; z: number }
  priority: 'low' | 'medium' | 'high'
  caller?: string
  type?: string
  time: string
  timestamp: number
  responderCount?: number
  isAccepted?: boolean
}

// =============================================
// Page Types
// =============================================

export type PageId =
  | 'dashboard'
  | 'dispatch'
  | 'citizens'
  | 'vehicles'
  | 'reports'
  | 'penal-code'
  | 'warrants'
  | 'officers'
  | 'cameras'
  | 'federal'
  | 'clock'

// =============================================
// ALPR Types
// =============================================

export interface ALPRVehicle {
  plate: string
  name: string
  speed: number
  flags: VehicleFlag[]
  plateIndex: number
}

export interface ALPRState {
  isActive: boolean
  isLocked: boolean
  lockedPlate: string | null
  front: ALPRVehicle | null
  rear: ALPRVehicle | null
}
