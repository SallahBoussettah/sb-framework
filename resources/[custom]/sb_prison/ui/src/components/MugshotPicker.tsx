import { useBookingStore } from '../store/bookingStore'

export function MugshotPicker() {
  const { availableMugshots, mugshotsLoading, pickerSlot, closePicker, selectMugshot } = useBookingStore()

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/60" onClick={closePicker} />

      {/* Modal */}
      <div className="relative bg-booking-bg-primary border border-booking-border rounded-lg w-[520px] max-h-[420px] flex flex-col shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-booking-border">
          <div className="flex items-center gap-2">
            <i className="fas fa-images text-booking-accent text-sm" />
            <h3 className="text-sm font-semibold text-white">
              Select {pickerSlot === 'front' ? 'Front' : 'Side'} Photo
            </h3>
          </div>
          <button
            onClick={closePicker}
            className="text-booking-text-muted hover:text-white transition-colors"
          >
            <i className="fas fa-times text-sm" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-4">
          {mugshotsLoading ? (
            <div className="flex flex-col items-center justify-center py-12 text-booking-text-muted">
              <i className="fas fa-spinner fa-spin text-2xl mb-3" />
              <p className="text-sm">Loading photos...</p>
            </div>
          ) : availableMugshots.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-booking-text-muted">
              <i className="fas fa-camera-slash text-3xl mb-3" />
              <p className="text-sm">No photos available</p>
              <p className="text-[11px] mt-1 text-booking-text-muted/70">
                Use the Mugshot Camera station to take photos first
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-4 gap-3">
              {availableMugshots.map((photo) => (
                <button
                  key={photo.id}
                  onClick={() => selectMugshot(photo.url)}
                  className="group relative bg-booking-bg-secondary border border-booking-border rounded overflow-hidden hover:border-booking-accent transition-colors"
                >
                  <div className="aspect-[3/4] w-full">
                    <img
                      src={photo.url}
                      alt={`Photo #${photo.id}`}
                      className="w-full h-full object-cover"
                    />
                  </div>
                  <div className="absolute inset-0 bg-booking-accent/0 group-hover:bg-booking-accent/15 transition-colors flex items-center justify-center">
                    <i className="fas fa-check-circle text-white text-lg opacity-0 group-hover:opacity-100 transition-opacity drop-shadow-lg" />
                  </div>
                  <div className="px-1.5 py-1 text-center">
                    <span className="text-[10px] text-booking-text-muted">{photo.createdAt}</span>
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
