import { create } from 'zustand'
import type {
  PageId,
  OfficerData,
  OnDutyOfficer,
  Citizen,
  CitizenDetail,
  Vehicle,
  VehicleDetail,
  PenalCodeEntry,
  SelectedCharge,
  Report,
  Alert,
  Warrant,
  BOLO,
  VehicleFlag,
  OfficerRoster,
  DutyStats,
} from '../types'

interface MDTState {
  // MDT State
  isOpen: boolean
  currentPage: PageId
  officerData: OfficerData | null

  // Duty
  isOnDuty: boolean
  shiftStartTime: number | null
  onDutyOfficers: OnDutyOfficer[]

  // Alerts / Dispatch
  alerts: Alert[]
  selectedAlert: Alert | null

  // Penal Code
  penalCode: PenalCodeEntry[]

  // Citizens Search
  citizenSearchResults: Citizen[]
  citizenSearchLoading: boolean
  selectedCitizen: CitizenDetail | null
  selectedCitizenLoading: boolean

  // Vehicle Search
  vehicleSearchResults: Vehicle[]
  vehicleSearchLoading: boolean
  selectedVehicle: VehicleDetail | null
  selectedVehicleLoading: boolean

  // Charges (for adding to citizen)
  selectedCharges: SelectedCharge[]

  // Reports
  reports: Report[]
  reportsFilter: 'all' | 'open' | 'closed'
  selectedReport: Report | null
  reportEditorOpen: boolean

  // Warrants & BOLOs
  warrants: Warrant[]
  bolos: BOLO[]
  vehicleFlags: VehicleFlag[]

  // Officer Roster
  officerRoster: OfficerRoster[]

  // Duty Stats / Time Clock
  dutyStats: DutyStats | null
  allOfficersDuty: { officerName: string; totalMinutes: number; records: { clockIn: string; clockOut: string | null; durationMinutes: number }[] }[]

  // Actions
  openMDT: (officerData: OfficerData) => void
  closeMDT: () => void
  setPage: (page: PageId) => void

  setDutyStatus: (isOnDuty: boolean) => void
  setShiftStartTime: (time: number | null) => void
  setOnDutyOfficers: (officers: OnDutyOfficer[]) => void

  setAlerts: (alerts: Alert[]) => void
  addAlert: (alert: Alert) => void
  removeAlert: (alertId: string) => void
  setSelectedAlert: (alert: Alert | null) => void
  updateAlertAccepted: (alertId: string, accepted: boolean) => void
  updateAlertResponders: (alertId: string, count: number) => void
  setPenalCode: (codes: PenalCodeEntry[]) => void

  setCitizenSearchResults: (results: Citizen[]) => void
  setCitizenSearchLoading: (loading: boolean) => void
  setSelectedCitizen: (citizen: CitizenDetail | null) => void
  setSelectedCitizenLoading: (loading: boolean) => void

  setVehicleSearchResults: (results: Vehicle[]) => void
  setVehicleSearchLoading: (loading: boolean) => void
  setSelectedVehicle: (vehicle: VehicleDetail | null) => void
  setSelectedVehicleLoading: (loading: boolean) => void

  addCharge: (charge: SelectedCharge) => void
  removeCharge: (chargeUid: string) => void
  clearCharges: () => void

  setReports: (reports: Report[]) => void
  setReportsFilter: (filter: 'all' | 'open' | 'closed') => void
  setSelectedReport: (report: Report | null) => void
  setReportEditorOpen: (open: boolean) => void
  updateReportField: (reportId: number, field: string, items: string[]) => void
  updateReportStatus: (reportId: number, status: 'open' | 'pending' | 'closed') => void

  // Warrants & BOLOs
  setWarrants: (warrants: Warrant[]) => void
  setBOLOs: (bolos: BOLO[]) => void
  setVehicleFlags: (flags: VehicleFlag[]) => void

  // Officer Roster
  setOfficerRoster: (roster: OfficerRoster[]) => void

  // Duty Stats
  setDutyStats: (stats: DutyStats) => void
  setAllOfficersDuty: (data: MDTState['allOfficersDuty']) => void
}

export const useMDTStore = create<MDTState>((set) => ({
  // Initial State
  isOpen: false,
  currentPage: 'dashboard',
  officerData: null,

  isOnDuty: false,
  shiftStartTime: null,
  onDutyOfficers: [],

  alerts: [],
  selectedAlert: null,
  penalCode: [],

  citizenSearchResults: [],
  citizenSearchLoading: false,
  selectedCitizen: null,
  selectedCitizenLoading: false,

  vehicleSearchResults: [],
  vehicleSearchLoading: false,
  selectedVehicle: null,
  selectedVehicleLoading: false,

  selectedCharges: [],

  reports: [],
  reportsFilter: 'all',
  selectedReport: null,
  reportEditorOpen: false,

  warrants: [],
  bolos: [],
  vehicleFlags: [],

  officerRoster: [],

  dutyStats: null,
  allOfficersDuty: [],

  // Actions
  openMDT: (officerData) =>
    set({
      isOpen: true,
      officerData,
      isOnDuty: officerData.isOnDuty,
      currentPage: 'dashboard',
    }),

  closeMDT: () =>
    set({
      isOpen: false,
      selectedCitizen: null,
      selectedVehicle: null,
      selectedCharges: [],
    }),

  setPage: (page) => set({ currentPage: page }),

  setDutyStatus: (isOnDuty) => set({ isOnDuty }),
  setShiftStartTime: (time) => set({ shiftStartTime: time }),
  setOnDutyOfficers: (officers) => set({ onDutyOfficers: officers }),

  setAlerts: (alerts) => set({ alerts }),
  addAlert: (alert) =>
    set((state) => ({
      alerts: [alert, ...state.alerts].slice(0, 50),
    })),
  removeAlert: (alertId) =>
    set((state) => ({
      alerts: state.alerts.filter((a) => a.id !== alertId),
      selectedAlert: state.selectedAlert?.id === alertId ? null : state.selectedAlert,
    })),
  setSelectedAlert: (alert) => set({ selectedAlert: alert }),
  updateAlertAccepted: (alertId, accepted) =>
    set((state) => ({
      alerts: state.alerts.map((a) => (a.id === alertId ? { ...a, isAccepted: accepted } : a)),
      selectedAlert: state.selectedAlert?.id === alertId ? { ...state.selectedAlert, isAccepted: accepted } : state.selectedAlert,
    })),
  updateAlertResponders: (alertId, count) =>
    set((state) => ({
      alerts: state.alerts.map((a) => (a.id === alertId ? { ...a, responderCount: count } : a)),
      selectedAlert: state.selectedAlert?.id === alertId ? { ...state.selectedAlert, responderCount: count } : state.selectedAlert,
    })),
  setPenalCode: (codes) => set({ penalCode: codes }),

  setCitizenSearchResults: (results) => set({ citizenSearchResults: results }),
  setCitizenSearchLoading: (loading) => set({ citizenSearchLoading: loading }),
  setSelectedCitizen: (citizen) => set({ selectedCitizen: citizen }),
  setSelectedCitizenLoading: (loading) => set({ selectedCitizenLoading: loading }),

  setVehicleSearchResults: (results) => set({ vehicleSearchResults: results }),
  setVehicleSearchLoading: (loading) => set({ vehicleSearchLoading: loading }),
  setSelectedVehicle: (vehicle) => set({ selectedVehicle: vehicle }),
  setSelectedVehicleLoading: (loading) => set({ selectedVehicleLoading: loading }),

  addCharge: (charge) =>
    set((state) => ({
      selectedCharges: [...state.selectedCharges, charge],
    })),

  removeCharge: (chargeUid) =>
    set((state) => ({
      selectedCharges: state.selectedCharges.filter((c) => c.uid !== chargeUid),
    })),

  clearCharges: () => set({ selectedCharges: [] }),

  setReports: (reports) => set({ reports }),
  setReportsFilter: (filter) => set({ reportsFilter: filter }),
  setSelectedReport: (report) => set({ selectedReport: report }),
  setReportEditorOpen: (open) => set({ reportEditorOpen: open }),

  updateReportField: (reportId, field, items) =>
    set((state) => {
      const updatedReports = state.reports.map((r) => {
        if (r.id !== reportId) return r
        return { ...r, [field]: items }
      })
      const updatedSelected = state.selectedReport?.id === reportId
        ? { ...state.selectedReport, [field]: items }
        : state.selectedReport
      return { reports: updatedReports, selectedReport: updatedSelected }
    }),

  updateReportStatus: (reportId, status) =>
    set((state) => {
      const updatedReports = state.reports.map((r) =>
        r.id === reportId ? { ...r, status } : r
      )
      const updatedSelected = state.selectedReport?.id === reportId
        ? { ...state.selectedReport, status }
        : state.selectedReport
      return { reports: updatedReports, selectedReport: updatedSelected }
    }),

  setWarrants: (warrants) => set({ warrants }),
  setBOLOs: (bolos) => set({ bolos }),
  setVehicleFlags: (flags) => set({ vehicleFlags: flags }),

  setOfficerRoster: (roster) => set({ officerRoster: roster }),

  setDutyStats: (stats) => set({ dutyStats: stats }),
  setAllOfficersDuty: (data) => set({ allOfficersDuty: data }),
}))
