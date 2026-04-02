import { usePhoneStore } from '../store/phoneStore'
import { soundManager } from '../utils/sound'

export default function HomeIndicator() {
  const { goHome, currentApp } = usePhoneStore()

  const handleTap = () => {
    if (currentApp !== 'home') {
      soundManager.tap()
      goHome()
    }
  }

  return (
    <div
      className={`flex justify-center pb-[8px] pt-[4px] ${currentApp !== 'home' ? 'bg-[#0e0e0f]' : ''}`}
      onClick={handleTap}
    >
      <div className={`w-[134px] h-[5px] rounded-full transition-colors duration-200 cursor-pointer ${
        currentApp === 'home' ? 'bg-white/20' : 'bg-white/30 hover:bg-white/50'
      }`} />
    </div>
  )
}
