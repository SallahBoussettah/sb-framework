import { create } from 'zustand'
import type { AppId, PhoneData, PhoneMetadata, IncomingCallData, Contact, Message, CallRecord, BankData, JobData, PhoneSettings, GalleryPhoto, InstapicProfile, InstapicPost, InstapicStoryGroup, Notification } from '../types'

interface CallState {
  status: 'idle' | 'outgoing' | 'incoming' | 'active'
  callerName?: string
  callerNumber?: string
  callerSource?: number
  initial?: string
  ringtone?: string
  channel?: number
  muted: boolean
  speaker: boolean
  startTime?: number
  voicemail?: boolean
}

interface PeekMessage {
  senderNumber: string
  senderName?: string
  message: string
  timestamp: number
}

interface PhoneStore {
  // Visibility
  isOpen: boolean
  isBooting: boolean
  isLocked: boolean

  // Navigation
  currentApp: AppId
  navStack: AppId[]

  // Data
  metadata: PhoneMetadata | null
  isOwner: boolean
  myNumber: string
  contacts: Contact[]
  messages: Message[]
  calls: CallRecord[]
  bankData: BankData
  jobData: JobData
  settings: PhoneSettings
  gallery: GalleryPhoto[]
  instapicProfile: InstapicProfile | null
  instapicFeed: InstapicPost[]
  instapicStories: InstapicStoryGroup[]

  // Call
  callState: CallState

  // Peek (phone closed but showing notifications)
  peekCall: boolean
  peekMessage: PeekMessage | null

  // Camera
  cameraMode: boolean
  cameraCapturing: boolean
  cameraZoom: number
  cameraZoomLevels: number[]
  cameraLooking: boolean
  cameraFlash: 'off' | 'on' | 'auto'
  cameraLandscape: boolean

  // Notifications
  notifications: Notification[]

  // Config
  soundVolume: number
  keyboardSounds: boolean

  // Actions
  openPhone: (data: PhoneData, metadata: PhoneMetadata, isOwner: boolean, myNumber: string, config: { soundVolume: number, keyboardSounds: boolean }) => void
  closePhone: () => void
  minimizePhone: () => void
  setBooting: (v: boolean) => void
  setLocked: (v: boolean) => void

  navigate: (app: AppId) => void
  goBack: () => void
  goHome: () => void

  setContacts: (c: Contact[]) => void
  setMessages: (m: Message[]) => void
  setCalls: (c: CallRecord[]) => void
  setBankData: (b: BankData) => void
  setJobData: (j: JobData) => void
  setSettings: (s: PhoneSettings) => void
  setGallery: (g: GalleryPhoto[]) => void
  setInstapicProfile: (p: InstapicProfile | null) => void
  setInstapicFeed: (f: InstapicPost[]) => void
  setInstapicStories: (s: InstapicStoryGroup[]) => void
  addMessage: (m: Message) => void

  setCallState: (c: Partial<CallState>) => void
  resetCallState: () => void

  setPeekCall: (v: boolean) => void
  setPeekMessage: (m: PeekMessage | null) => void

  setCameraMode: (v: boolean) => void
  setCameraZoom: (v: number) => void
  setCameraZoomLevels: (v: number[]) => void
  setCameraLooking: (v: boolean) => void
  setCameraFlash: (v: 'off' | 'on' | 'auto') => void
  setCameraLandscape: (v: boolean) => void

  addNotification: (n: Notification) => void
  removeNotification: (id: string) => void
}

const defaultCallState: CallState = {
  status: 'idle', muted: false, speaker: false
}

export const usePhoneStore = create<PhoneStore>((set, get) => ({
  isOpen: false,
  isBooting: false,
  isLocked: true,
  currentApp: 'home',
  navStack: [],
  metadata: null,
  isOwner: true,
  myNumber: '',
  contacts: [],
  messages: [],
  calls: [],
  bankData: { cash: 0, bank: 0 },
  jobData: { title: 'Unemployed', rank: 'None', onDuty: false, badge: '', department: '' },
  settings: { wallpaper: 'default', ringtone: 'default', airplaneMode: false, hasPasskey: false },
  gallery: [],
  instapicProfile: null as InstapicProfile | null,
  instapicFeed: [],
  instapicStories: [],
  callState: defaultCallState,
  cameraMode: false,
  cameraCapturing: false,
  cameraZoom: 1.0,
  cameraZoomLevels: [1.0],
  cameraLooking: false,
  cameraFlash: 'off',
  cameraLandscape: false,
  peekCall: false,
  peekMessage: null,
  notifications: [],
  soundVolume: 0.3,
  keyboardSounds: true,

  openPhone: (data, metadata, isOwner, myNumber, config) => set({
    isOpen: true,
    isBooting: true,
    metadata,
    isOwner,
    myNumber,
    contacts: data.contacts,
    messages: data.messages,
    calls: data.calls,
    bankData: data.bankData,
    jobData: data.jobData,
    settings: data.settings,
    gallery: data.gallery,
    instapicProfile: data.instapic.profile,
    instapicFeed: data.instapic.feed,
    instapicStories: data.instapic.stories,
    soundVolume: config.soundVolume,
    keyboardSounds: config.keyboardSounds,
  }),

  closePhone: () => set({
    isOpen: false,
    isBooting: false,
    isLocked: true,
    currentApp: 'home',
    navStack: [],
    peekCall: false,
    peekMessage: null,
  }),

  minimizePhone: () => set({
    isOpen: false,
    isBooting: false,
    peekCall: true,
  }),

  setBooting: (v) => set({ isBooting: v }),
  setLocked: (v) => set({ isLocked: v }),

  navigate: (app) => {
    const { currentApp, navStack } = get()
    if (app === currentApp) return
    set({ currentApp: app, navStack: [...navStack, currentApp] })
  },

  goBack: () => {
    const { navStack } = get()
    if (navStack.length === 0) { set({ currentApp: 'home' }); return }
    const prev = navStack[navStack.length - 1]
    set({ currentApp: prev, navStack: navStack.slice(0, -1) })
  },

  goHome: () => set({ currentApp: 'home', navStack: [] }),

  setContacts: (c) => set({ contacts: c }),
  setMessages: (m) => set({ messages: m }),
  setCalls: (c) => set({ calls: c }),
  setBankData: (b) => set({ bankData: b }),
  setJobData: (j) => set({ jobData: j }),
  setSettings: (s) => set({ settings: s }),
  setGallery: (g) => set({ gallery: g }),
  setInstapicProfile: (p) => set({ instapicProfile: p }),
  setInstapicFeed: (f) => set({ instapicFeed: f }),
  setInstapicStories: (s) => set({ instapicStories: s }),
  addMessage: (m) => set(state => ({ messages: [...state.messages, m] })),

  setCallState: (c) => set(state => ({ callState: { ...state.callState, ...c } })),
  resetCallState: () => set({ callState: defaultCallState, peekCall: false }),

  setCameraMode: (v) => set({ cameraMode: v, ...(v ? {} : { cameraFlash: 'off', cameraLandscape: false }) }),
  setCameraZoom: (v) => set({ cameraZoom: v }),
  setCameraZoomLevels: (v) => set({ cameraZoomLevels: v }),
  setCameraLooking: (v) => set({ cameraLooking: v }),
  setCameraFlash: (v) => set({ cameraFlash: v }),
  setCameraLandscape: (v) => set({ cameraLandscape: v }),
  setPeekCall: (v) => set({ peekCall: v }),
  setPeekMessage: (m) => set({ peekMessage: m }),

  addNotification: (n) => set(state => ({ notifications: [n, ...state.notifications].slice(0, 50) })),
  removeNotification: (id) => set(state => ({ notifications: state.notifications.filter(n => n.id !== id) })),
}))
