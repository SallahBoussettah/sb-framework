// =============================================
// NUI Communication Utilities
// =============================================

type NuiCallback<T = unknown> = (data: T) => void

const listeners: Map<string, Set<NuiCallback>> = new Map()

// Listen for NUI messages from the game
window.addEventListener('message', (event) => {
  const { type, ...data } = event.data
  if (!type) return

  const callbacks = listeners.get(type)
  if (callbacks) {
    callbacks.forEach((cb) => cb(data))
  }
})

/**
 * Subscribe to NUI messages of a specific type
 */
export function onNuiMessage<T = unknown>(type: string, callback: NuiCallback<T>): () => void {
  if (!listeners.has(type)) {
    listeners.set(type, new Set())
  }
  listeners.get(type)!.add(callback as NuiCallback)

  // Return unsubscribe function
  return () => {
    listeners.get(type)?.delete(callback as NuiCallback)
  }
}

/**
 * Send a message to the game client via NUI callback
 */
export async function fetchNui<T = unknown>(action: string, data: Record<string, unknown> = {}): Promise<T> {
  const resourceName = (window as unknown as { GetParentResourceName?: () => string }).GetParentResourceName?.() ?? 'sb_police'

  try {
    const response = await fetch(`https://${resourceName}/${action}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    })
    return response.json()
  } catch (error) {
    console.error(`[sb_police] NUI fetch error for ${action}:`, error)
    throw error
  }
}

/**
 * Check if we're running in the game or in dev mode
 */
export function isEnvBrowser(): boolean {
  return !(window as unknown as { invokeNative?: unknown }).invokeNative
}

/**
 * Debug mode - mock data for development
 */
export const debugData = <T>(events: { type: string; data: T }[], timer = 1000): void => {
  if (!isEnvBrowser()) return

  events.forEach((event, index) => {
    setTimeout(() => {
      window.dispatchEvent(
        new MessageEvent('message', {
          data: { type: event.type, ...event.data },
        })
      )
    }, timer * (index + 1))
  })
}
