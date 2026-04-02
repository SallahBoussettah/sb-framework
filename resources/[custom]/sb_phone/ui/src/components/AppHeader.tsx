import { usePhoneStore } from '../store/phoneStore'
import { soundManager } from '../utils/sound'
import { ChevronLeft } from 'lucide-react'

interface Props {
  title: string
  rightAction?: React.ReactNode
}

export default function AppHeader({ title, rightAction }: Props) {
  const { goBack } = usePhoneStore()

  const handleBack = () => {
    soundManager.tap()
    goBack()
  }

  return (
    <div className="flex items-center justify-between px-4 pt-2 pb-3 min-h-[44px] bg-[#0e0e0f] border-b border-white/5 relative">
      <button onClick={handleBack} className="flex items-center gap-0.5 text-phone-accent z-10">
        <ChevronLeft size={22} />
        <span className="text-[15px]">Back</span>
      </button>
      <h1 className="text-white text-[17px] font-semibold absolute inset-0 flex items-center justify-center pointer-events-none">{title}</h1>
      <div className="min-w-[60px] flex justify-end z-10">{rightAction}</div>
    </div>
  )
}
