interface MugshotPreviewProps {
  urls: string[]
  size?: 'sm' | 'md'
}

export function MugshotPreview({ urls, size = 'md' }: MugshotPreviewProps) {
  const imgSize = size === 'sm' ? 'w-16 h-20' : 'w-24 h-32'

  if (urls.length === 0) {
    return (
      <div className="flex items-center justify-center text-booking-text-muted py-4">
        <i className="fas fa-camera text-lg mr-2" />
        <span className="text-xs">No photos taken</span>
      </div>
    )
  }

  return (
    <div className="flex items-start gap-2 flex-wrap">
      {urls.map((url, i) => (
        <div key={i} className="text-center">
          <div className={`${imgSize} bg-booking-bg-tertiary rounded border border-booking-border overflow-hidden`}>
            <img src={url} alt={`Photo ${i + 1}`} className="w-full h-full object-cover" />
          </div>
          <span className="text-[10px] text-booking-text-muted mt-0.5 block">#{i + 1}</span>
        </div>
      ))}
    </div>
  )
}
