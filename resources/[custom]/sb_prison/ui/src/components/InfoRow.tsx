interface InfoRowProps {
  label: string
  value: string | number
  icon?: string
  valueColor?: string
}

export function InfoRow({ label, value, icon, valueColor }: InfoRowProps) {
  return (
    <div className="flex items-center justify-between py-1.5 px-3 rounded bg-booking-bg-tertiary/50">
      <span className="text-booking-text-secondary text-xs flex items-center gap-2">
        {icon && <i className={`fas ${icon} text-[10px] text-booking-text-muted`} />}
        {label}
      </span>
      <span className={`text-xs font-medium ${valueColor || 'text-white'}`}>
        {value}
      </span>
    </div>
  )
}
