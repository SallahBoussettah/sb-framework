import { useEffect } from 'react'
import { AnimatePresence } from 'framer-motion'
import { useMDTStore } from './store/mdtStore'
import { useGarageStore } from './store/garageStore'
import { useALPRStore } from './store/alprStore'
import { onNuiMessage, fetchNui, isEnvBrowser, debugData } from './utils/nui'
import MDTWindow from './components/MDTWindow'
import GarageMenu from './components/GarageMenu'
import ALPROverlay from './components/ALPROverlay'
import type { OfficerData, OnDutyOfficer, Alert, PenalCodeEntry, Citizen, Vehicle, CitizenDetail, VehicleDetail, Report, ALPRVehicle, Warrant, BOLO, VehicleFlag, OfficerRoster, DutyStats } from './types'

export default function App() {
  const {
    isOpen, openMDT, closeMDT, setDutyStatus, setShiftStartTime, setOnDutyOfficers, setAlerts, addAlert, removeAlert, updateAlertResponders, setPenalCode,
    setCitizenSearchResults, setCitizenSearchLoading, setSelectedCitizen, setSelectedCitizenLoading,
    setVehicleSearchResults, setVehicleSearchLoading, setSelectedVehicle, setSelectedVehicleLoading,
    setReports, setWarrants, setBOLOs, setVehicleFlags, setOfficerRoster, setDutyStats, setAllOfficersDuty,
    updateReportField, updateReportStatus, setPage,
  } = useMDTStore()
  const { isOpen: isGarageOpen, openGarage, closeGarage } = useGarageStore()
  const { isActive: isALPRActive, showALPR, hideALPR, updateALPR } = useALPRStore()

  useEffect(() => {
    // Subscribe to NUI messages
    const unsubs = [
      onNuiMessage<{ officerData: OfficerData }>('open', (data) => {
        openMDT(data.officerData)
        // Request initial data
        fetchNui('getOfficers')
        fetchNui('getAlerts')
        fetchNui('getPenalCode')
        // If already on duty, fetch stats to get accurate shift start time
        if (data.officerData.isOnDuty) {
          fetchNui('getDutyStats')
        }
      }),

      onNuiMessage('close', () => {
        closeMDT()
      }),

      onNuiMessage<{ isOnDuty: boolean; shiftStart?: number }>('updateDuty', (data) => {
        setDutyStatus(data.isOnDuty)
        if (data.isOnDuty) {
          // If shiftStart provided (unix seconds from server), use it for timer continuity
          setShiftStartTime(data.shiftStart ? data.shiftStart * 1000 : Date.now())
        } else {
          setShiftStartTime(null)
        }
      }),

      onNuiMessage<{ officers: OnDutyOfficer[] }>('updateOfficers', (data) => {
        setOnDutyOfficers(data.officers || [])
      }),

      onNuiMessage<{ alerts: Alert[] }>('updateAlerts', (data) => {
        setAlerts(data.alerts || [])
      }),

      // Real-time alert updates from sb_alerts
      onNuiMessage<{ alert: Alert }>('newAlert', (data) => {
        addAlert(data.alert)
      }),

      onNuiMessage<{ alertId: string }>('removeAlert', (data) => {
        removeAlert(data.alertId)
      }),

      onNuiMessage<{ alertId: string; responderCount: number }>('updateResponders', (data) => {
        updateAlertResponders(data.alertId, data.responderCount)
      }),

      onNuiMessage<{ codes: PenalCodeEntry[] }>('penalCode', (data) => {
        setPenalCode(data.codes || [])
      }),

      onNuiMessage<{ searchType: string; results: Citizen[] | Vehicle[] }>('searchResults', (data) => {
        if (data.searchType === 'citizens') {
          setCitizenSearchResults(data.results as Citizen[])
          setCitizenSearchLoading(false)
        } else {
          setVehicleSearchResults(data.results as Vehicle[])
          setVehicleSearchLoading(false)
        }
      }),

      onNuiMessage<{ citizen: CitizenDetail }>('citizenDetails', (data) => {
        setSelectedCitizen(data.citizen)
        setSelectedCitizenLoading(false)
      }),

      onNuiMessage<{ vehicle: VehicleDetail }>('vehicleDetails', (data) => {
        setSelectedVehicle(data.vehicle)
        setSelectedVehicleLoading(false)
      }),

      onNuiMessage<{ reports: Report[] }>('reportsList', (data) => {
        setReports(data.reports || [])
      }),

      // Warrants & BOLOs
      onNuiMessage<{ warrants: Warrant[] }>('warrantsList', (data) => {
        setWarrants(data.warrants || [])
      }),

      onNuiMessage<{ bolos: BOLO[] }>('bolosList', (data) => {
        setBOLOs(data.bolos || [])
      }),

      onNuiMessage<{ flags: VehicleFlag[] }>('vehicleFlagsList', (data) => {
        setVehicleFlags(data.flags || [])
      }),

      // Officer Roster
      onNuiMessage<{ roster: OfficerRoster[] }>('officerRoster', (data) => {
        setOfficerRoster(data.roster || [])
      }),

      // Duty Stats
      onNuiMessage<{ stats: DutyStats }>('dutyStats', (data) => {
        setDutyStats(data.stats)
        // Backdate shift start time from server's actual clock-in
        if (data.stats.currentShiftMinutes > 0) {
          setShiftStartTime(Date.now() - data.stats.currentShiftMinutes * 60 * 1000)
        }
      }),

      onNuiMessage<{ data: any[] }>('allOfficersDuty', (msg) => {
        setAllOfficersDuty(msg.data || [])
      }),

      // Report Improvements
      onNuiMessage<{ reportId: number; field: string; items: string[] }>('reportUpdated', (data) => {
        updateReportField(data.reportId, data.field, data.items)
      }),

      onNuiMessage<{ reportId: number; status: 'open' | 'pending' | 'closed' }>('reportStatusUpdated', (data) => {
        updateReportStatus(data.reportId, data.status)
      }),

      // Citation form from /cite command
      onNuiMessage<{ targetSource: number }>('openCitationForm', () => {
        setPage('citizens')
      }),

      // Garage handlers
      onNuiMessage<{
        vehicles: any[]
        categories: any[]
        playerGrade: number
        ranks: any[]
        garageData: any
        gradeMode?: string
      }>('openGarage', (data) => {
        openGarage({
          vehicles: data.vehicles || [],
          categories: data.categories || [],
          playerGrade: data.playerGrade || 0,
          ranks: data.ranks || [],
          garageData: data.garageData,
          gradeMode: (data.gradeMode as 'exact' | 'cumulative') || 'exact',
        })
      }),

      onNuiMessage('closeGarage', () => {
        closeGarage()
      }),

      // ALPR handlers
      onNuiMessage('alprShow', () => {
        showALPR()
      }),

      onNuiMessage('alprHide', () => {
        hideALPR()
      }),

      onNuiMessage<{
        front: ALPRVehicle | null
        rear: ALPRVehicle | null
        locked: boolean
        lockedPlate: string | null
      }>('alprUpdate', (data) => {
        updateALPR(data)
      }),
    ]

    // Dev mode - show MDT automatically
    if (isEnvBrowser()) {
      debugData([
        {
          type: 'open',
          data: {
            officerData: {
              name: 'John Doe',
              rank: 'Sergeant',
              badge: '1234',
              isOnDuty: false,
              grade: 5,
            },
          },
        },
      ], 500)

      // Mock penal code
      debugData([
        {
          type: 'penalCode',
          data: {
            codes: [
              { id: 1, category: 'Traffic', title: 'Speeding', description: 'Exceeding the posted speed limit', fine: 250, jail_time: 0 },
              { id: 2, category: 'Traffic', title: 'Reckless Driving', description: 'Operating a vehicle with willful disregard for safety', fine: 500, jail_time: 5 },
              { id: 3, category: 'Misdemeanor', title: 'Disorderly Conduct', description: 'Engaging in disruptive behavior in public', fine: 500, jail_time: 5 },
              { id: 4, category: 'Felony', title: 'Armed Robbery', description: 'Robbery committed with a weapon', fine: 7500, jail_time: 45 },
            ],
          },
        },
      ], 1000)
    }

    return () => unsubs.forEach((fn) => fn())
  }, [])

  return (
    <div className="w-screen h-screen pointer-events-none overflow-hidden">
      <AnimatePresence>
        {isOpen && <MDTWindow />}
        {isGarageOpen && <GarageMenu />}
        {isALPRActive && <ALPROverlay />}
      </AnimatePresence>
    </div>
  )
}
