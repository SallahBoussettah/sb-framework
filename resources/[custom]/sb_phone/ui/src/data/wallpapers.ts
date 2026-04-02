export interface WallpaperDef {
  id: string
  label: string
  /** CSS gradient string or image URL (relative to html/ output) */
  background: string
  /** true if background is a CSS gradient, false if image URL */
  isGradient: boolean
}

export const wallpapers: WallpaperDef[] = [
  {
    id: 'midnight',
    label: 'Midnight',
    background: 'linear-gradient(145deg, #0a0a0f 0%, #1a1a2e 30%, #16213e 60%, #0f3460 85%, #1a1a2e 100%)',
    isGradient: true,
  },
  {
    id: 'sunset',
    label: 'Sunset',
    background: 'linear-gradient(160deg, #1a0a2e 0%, #2d1b69 20%, #d63031 45%, #ee5a24 65%, #f9ca24 90%)',
    isGradient: true,
  },
  {
    id: 'ocean',
    label: 'Ocean',
    background: 'linear-gradient(170deg, #0a1628 0%, #0d3b66 25%, #1a759f 50%, #34a0a4 70%, #52b788 100%)',
    isGradient: true,
  },
  {
    id: 'aurora',
    label: 'Aurora',
    background: 'linear-gradient(150deg, #0a0a1a 0%, #1b0a3c 15%, #2d1b69 30%, #1a6b3c 50%, #34d399 70%, #0a3c2a 85%, #0a0a1a 100%)',
    isGradient: true,
  },
  {
    id: 'neon',
    label: 'Neon City',
    background: 'linear-gradient(165deg, #0a0a14 0%, #1a0a2e 15%, #ff006e 35%, #8338ec 55%, #3a0ca3 75%, #0a0a14 100%)',
    isGradient: true,
  },
  {
    id: 'earth',
    label: 'Earth',
    background: 'radial-gradient(circle at 55% 45%, #1a4a7a 0%, #0a2a4a 25%, #1a6b5a 40%, #0a1a2a 60%, #000 80%)',
    isGradient: true,
  },
  {
    id: 'dark-abstract',
    label: 'Dark',
    background: 'linear-gradient(135deg, #0a0a0a 0%, #1a1a2e 30%, #2a1a3e 50%, #1a1a2e 70%, #0a0a0a 100%)',
    isGradient: true,
  },
  {
    id: 'los-santos',
    label: 'Los Santos',
    background: 'linear-gradient(170deg, #0a0a14 0%, #1a1a3e 15%, #2a3a5e 30%, #ff6b35 50%, #e74c3c 60%, #1a1a2e 75%, #0a0a0f 100%)',
    isGradient: true,
  },
]

export function getWallpaperById(id: string): WallpaperDef | undefined {
  return wallpapers.find(w => w.id === id)
}

/** Get CSS background value for a wallpaper ID, with fallback.
 *  Handles legacy 'default' → 'midnight' mapping. */
export function getWallpaperBackground(id: string): string {
  const lookupId = id === 'default' ? 'midnight' : id
  const wp = getWallpaperById(lookupId)
  if (!wp) return wallpapers[0].background
  return wp.background
}
