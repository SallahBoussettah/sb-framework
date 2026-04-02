const isEnvBrowser = (): boolean => !(window as any).invokeNative

export async function nuiFetch<T = any>(event: string, data?: any): Promise<T> {
  if (isEnvBrowser()) {
    // Dev mode mock
    return new Promise((resolve) => {
      setTimeout(() => resolve({} as T), 100)
    })
  }

  const resp = await fetch(`https://sb_phone/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data ?? {}),
  })
  return resp.json()
}

export function onNuiMessage<T = any>(action: string, handler: (data: T) => void): () => void {
  const listener = (event: MessageEvent) => {
    if (event.data?.action === action) {
      handler(event.data as T)
    }
  }
  window.addEventListener('message', listener)
  return () => window.removeEventListener('message', listener)
}

export function closePhone(): void {
  nuiFetch('closePhone')
}

export function notifyTextFieldFocus(focused: boolean): void {
  nuiFetch('textFieldFocus', { focused })
}
