import {
  LayoutDashboard,
  MessageSquare,
  User,
  Car,
  FileText,
  Scale,
  AlertTriangle,
  Users,
  Video,
  Lock,
  Clock,
} from 'lucide-react'
import { useMDTStore } from '../store/mdtStore'
import type { PageId } from '../types'

interface NavItem {
  id: PageId
  label: string
  icon: React.ReactNode
  badge?: number
}

const navSections: { label?: string; items: NavItem[] }[] = [
  {
    items: [
      { id: 'dashboard', label: 'Dashboard', icon: <LayoutDashboard className="w-[18px] h-[18px]" /> },
      { id: 'dispatch', label: 'Dispatch', icon: <MessageSquare className="w-[18px] h-[18px]" /> },
    ],
  },
  {
    label: 'SEARCH',
    items: [
      { id: 'citizens', label: 'Citizens', icon: <User className="w-[18px] h-[18px]" /> },
      { id: 'vehicles', label: 'Vehicles', icon: <Car className="w-[18px] h-[18px]" /> },
    ],
  },
  {
    label: 'RECORDS',
    items: [
      { id: 'reports', label: 'Reports', icon: <FileText className="w-[18px] h-[18px]" /> },
      { id: 'penal-code', label: 'Criminal Code', icon: <Scale className="w-[18px] h-[18px]" /> },
      { id: 'warrants', label: 'BOLO / Warrants', icon: <AlertTriangle className="w-[18px] h-[18px]" /> },
    ],
  },
  {
    label: 'MANAGEMENT',
    items: [
      { id: 'officers', label: 'Officers', icon: <Users className="w-[18px] h-[18px]" /> },
      { id: 'cameras', label: 'Cameras', icon: <Video className="w-[18px] h-[18px]" /> },
      { id: 'federal', label: 'Federal', icon: <Lock className="w-[18px] h-[18px]" /> },
    ],
  },
]

const bottomNav: NavItem[] = [
  { id: 'clock', label: 'Time Clock', icon: <Clock className="w-[18px] h-[18px]" /> },
]

export default function Sidebar() {
  const { currentPage, setPage, alerts } = useMDTStore()

  // Add badge for dispatch if there are alerts
  const getNavItem = (item: NavItem): NavItem => {
    if (item.id === 'dispatch' && alerts.length > 0) {
      return { ...item, badge: alerts.length }
    }
    return item
  }

  return (
    <nav className="w-[220px] bg-mdt-bg-primary/60 border-r border-mdt-border flex flex-col py-3 px-2 overflow-y-auto shrink-0">
      {navSections.map((section, sectionIndex) => (
        <div key={sectionIndex}>
          {section.label && (
            <>
              <div className="h-px bg-mdt-border/50 my-3" />
              <div className="px-3 py-2 text-[10px] font-semibold text-mdt-accent uppercase tracking-wide">
                {section.label}
              </div>
            </>
          )}
          <div className="flex flex-col gap-0.5">
            {section.items.map((item) => {
              const navItem = getNavItem(item)
              const isActive = currentPage === navItem.id

              return (
                <button
                  key={navItem.id}
                  onClick={() => setPage(navItem.id)}
                  className={`relative flex items-center gap-3 px-3 py-2.5 rounded-md text-left transition-colors ${
                    isActive
                      ? 'bg-mdt-accent/15 text-mdt-accent'
                      : 'text-mdt-text-secondary hover:bg-mdt-bg-hover hover:text-mdt-text-primary'
                  }`}
                >
                  {isActive && (
                    <div className="absolute left-0 top-1/2 -translate-y-1/2 w-[3px] h-5 bg-mdt-accent rounded-r" />
                  )}
                  {navItem.icon}
                  <span className="text-[13px] font-medium">{navItem.label}</span>
                  {navItem.badge && navItem.badge > 0 && (
                    <span className="absolute right-2 min-w-[18px] h-[18px] px-1.5 bg-mdt-danger rounded-full text-[11px] font-semibold text-white flex items-center justify-center">
                      {navItem.badge}
                    </span>
                  )}
                </button>
              )
            })}
          </div>
        </div>
      ))}

      {/* Spacer */}
      <div className="flex-1" />

      {/* Bottom Nav */}
      <div className="h-px bg-mdt-border/50 my-3" />
      <div className="flex flex-col gap-0.5">
        {bottomNav.map((item) => {
          const isActive = currentPage === item.id

          return (
            <button
              key={item.id}
              onClick={() => setPage(item.id)}
              className={`relative flex items-center gap-3 px-3 py-2.5 rounded-md text-left transition-colors ${
                isActive
                  ? 'bg-mdt-accent/15 text-mdt-accent'
                  : 'text-mdt-text-secondary hover:bg-mdt-bg-hover hover:text-mdt-text-primary'
              }`}
            >
              {isActive && (
                <div className="absolute left-0 top-1/2 -translate-y-1/2 w-[3px] h-5 bg-mdt-accent rounded-r" />
              )}
              {item.icon}
              <span className="text-[13px] font-medium">{item.label}</span>
            </button>
          )
        })}
      </div>
    </nav>
  )
}
