interface AppIconProps {
  gradient: string
  icon: React.ReactNode
  size?: number
  shadow?: string
}

export default function AppIcon({ gradient, icon, size = 56, shadow }: AppIconProps) {
  const radius = size >= 56 ? 13 : 12

  return (
    <div
      className="relative flex items-center justify-center"
      style={{
        width: size,
        height: size,
        borderRadius: radius,
        background: gradient,
        boxShadow: shadow
          ? `0 2px 8px ${shadow}, 0 4px 16px rgba(0,0,0,0.3)`
          : '0 2px 8px rgba(0,0,0,0.3), 0 4px 16px rgba(0,0,0,0.2)',
      }}
    >
      {/* Gloss overlay — safe, no backdrop-filter */}
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          borderRadius: radius,
          background: 'linear-gradient(180deg, rgba(255,255,255,0.22) 0%, rgba(255,255,255,0.08) 40%, transparent 50%)',
        }}
      />
      {/* Inner border for depth */}
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          borderRadius: radius,
          boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.15), inset 0 -1px 0 rgba(0,0,0,0.15)',
        }}
      />
      {/* Icon */}
      <div className="relative z-10 text-white flex items-center justify-center">
        {icon}
      </div>
    </div>
  )
}
