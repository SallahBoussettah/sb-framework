export interface Contact {
  id: number
  name: string
  number: string
  favorite: boolean
}

export interface Message {
  id: number
  sender_number: string
  receiver_number: string
  message: string
  is_read: number
  status?: string
  created_at: string
}

export interface CallRecord {
  id: number
  caller_number: string
  receiver_number: string
  type: 'incoming' | 'outgoing' | 'missed'
  duration: number
  created_at: string
}

export interface BankData {
  cash: number
  bank: number
}

export interface JobData {
  title: string
  rank: string
  onDuty: boolean
  badge: string
  department: string
}

export interface PhoneSettings {
  wallpaper: string
  ringtone: string
  airplaneMode: boolean
  hasPasskey: boolean
}

export interface GalleryPhoto {
  id: number
  image_url: string
  created_at: string
}

export interface InstapicProfile {
  citizenid: string
  username: string
  bio: string
  follower_count: number
  following_count: number
  post_count: number
  is_following?: boolean
}

export interface InstapicPost {
  id: number
  author_citizenid: string
  author_name: string
  caption: string
  image_url: string | null
  image_gradient: string
  location: string | null
  created_at: string
  like_count: number
  comment_count: number
  user_liked: number
}

export interface InstapicComment {
  id: number
  post_id: number
  author_citizenid: string
  author_name: string
  content: string
  created_at: string
}

export interface InstapicStory {
  id: number
  author_citizenid: string
  author_name: string
  color: string
  image_url: string | null
  created_at: string
  viewed?: boolean
}

export interface InstapicStoryGroup {
  author_citizenid: string
  author_name: string
  stories: InstapicStory[]
  has_unviewed: boolean
}

export interface InstapicDM {
  id: number
  sender_citizenid: string
  receiver_citizenid: string
  message: string
  is_read: number
  created_at: string
}

export interface InstapicDMConversation {
  citizenid: string
  username: string
  last_message: string
  last_message_at: string
  unread_count: number
}

export interface PhoneData {
  contacts: Contact[]
  messages: Message[]
  calls: CallRecord[]
  bankData: BankData
  jobData: JobData
  settings: PhoneSettings
  gallery: GalleryPhoto[]
  instapic: {
    profile: InstapicProfile | null
    feed: InstapicPost[]
    stories: InstapicStoryGroup[]
  }
  isOwner: boolean
  myNumber: string
}

export interface PhoneMetadata {
  ownerCitizenid: string
  ownerName: string
  phoneNumber: string
  serial?: string
}

export interface IncomingCallData {
  callerName: string
  callerNumber: string
  callerSource: number
  initial: string
  ringtone?: string
}

export type AppId = 'home' | 'dialer' | 'messages' | 'contacts' | 'camera' | 'gallery' | 'bank' | 'job' | 'settings' | 'social'

export interface Notification {
  id: string
  title: string
  body: string
  icon?: string
  app: AppId
  timestamp: number
}
