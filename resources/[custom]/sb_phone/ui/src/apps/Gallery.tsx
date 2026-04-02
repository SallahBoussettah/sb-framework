import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { nuiFetch } from '../utils/nui'
import AppHeader from '../components/AppHeader'
import { X, Trash2 } from 'lucide-react'

export default function Gallery() {
  const { gallery, setGallery } = usePhoneStore()
  const [selected, setSelected] = useState<{ id: number; url: string } | null>(null)
  const [deleting, setDeleting] = useState(false)

  const handleDelete = async () => {
    if (!selected || deleting) return
    setDeleting(true)
    const res = await nuiFetch<{ success: boolean }>('deleteGalleryPhoto', { photoId: selected.id })
    if (res?.success) {
      setGallery(gallery.filter(p => p.id !== selected.id))
      setSelected(null)
    }
    setDeleting(false)
  }

  return (
    <div className="flex flex-col h-full bg-[#0e0e0f]">
      <AppHeader title="Gallery" />

      {gallery.length === 0 ? (
        <div className="flex-1 flex items-center justify-center">
          <p className="text-phone-muted text-sm">No photos yet</p>
        </div>
      ) : (
        <div className="flex-1 overflow-y-auto px-1">
          <div className="grid grid-cols-3 gap-0.5">
            {gallery.map(photo => (
              <button
                key={photo.id}
                onClick={() => setSelected({ id: photo.id, url: photo.image_url })}
                className="aspect-square overflow-hidden"
              >
                <img
                  src={photo.image_url}
                  alt=""
                  className="w-full h-full object-cover hover:opacity-80 transition-opacity"
                />
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Fullscreen preview */}
      <AnimatePresence>
        {selected && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute inset-0 bg-black z-50 flex items-center justify-center"
          >
            <img src={selected.url} alt="" className="max-w-full max-h-full object-contain" />
            <button
              onClick={() => setSelected(null)}
              className="absolute top-4 right-4 w-10 h-10 rounded-full bg-white/10 flex items-center justify-center"
            >
              <X size={20} className="text-white" />
            </button>
            <button
              onClick={handleDelete}
              disabled={deleting}
              className="absolute bottom-6 left-1/2 -translate-x-1/2 flex items-center gap-2 px-4 py-2 rounded-full bg-red-500/80 hover:bg-red-500 transition-colors disabled:opacity-50"
            >
              <Trash2 size={16} className="text-white" />
              <span className="text-white text-xs font-medium">{deleting ? 'Deleting...' : 'Delete'}</span>
            </button>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
