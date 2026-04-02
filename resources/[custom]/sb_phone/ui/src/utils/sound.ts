class SoundManager {
  private ctx: AudioContext | null = null
  private volume: number = 0.3
  private keyboardSounds: boolean = true
  private audioElements: Map<string, HTMLAudioElement> = new Map()
  private loopInterval: ReturnType<typeof setTimeout> | null = null
  private loopAudio: HTMLAudioElement | null = null
  private activeAudio: HTMLAudioElement | null = null // for voicemail/busy that can be stopped

  init(volume: number, keyboardSounds: boolean) {
    this.volume = volume
    this.keyboardSounds = keyboardSounds
    this.ctx = new AudioContext()
  }

  private playTone(frequency: number, duration: number, type: OscillatorType = 'sine', vol?: number) {
    if (!this.ctx) return
    const osc = this.ctx.createOscillator()
    const gain = this.ctx.createGain()
    osc.type = type
    osc.frequency.value = frequency
    gain.gain.value = vol ?? this.volume * 0.3
    osc.connect(gain)
    gain.connect(this.ctx.destination)
    osc.start()
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + duration)
    osc.stop(this.ctx.currentTime + duration)
  }

  // Play an MP3 file once, returns the audio element
  playFile(file: string, vol?: number): HTMLAudioElement {
    const audio = new Audio(`./audio/${file}`)
    audio.volume = vol ?? this.volume
    audio.play().catch(() => {})
    return audio
  }

  // Play an MP3 file with a gap between repeats (not seamless loop)
  playWithGap(file: string, gapMs: number, vol?: number) {
    this.stopLoop()
    const playOnce = () => {
      const audio = new Audio(`./audio/${file}`)
      audio.volume = vol ?? this.volume
      audio.play().catch(() => {})
      this.loopAudio = audio
      audio.addEventListener('ended', () => {
        // After audio finishes, wait gapMs then play again
        this.loopInterval = setTimeout(() => {
          if (this.loopInterval !== null) playOnce()
        }, gapMs)
      })
    }
    playOnce()
  }

  // Stop any looping/repeating audio
  stopLoop() {
    if (this.loopInterval !== null) {
      clearTimeout(this.loopInterval)
      this.loopInterval = null
    }
    if (this.loopAudio) {
      this.loopAudio.pause()
      this.loopAudio.currentTime = 0
      this.loopAudio = null
    }
  }

  // Stop active one-shot audio (voicemail/busy)
  stopActive() {
    if (this.activeAudio) {
      this.activeAudio.pause()
      this.activeAudio.currentTime = 0
      this.activeAudio = null
    }
  }

  // Stop everything
  stopAll() {
    this.stopLoop()
    this.stopActive()
  }

  // Play ringtone by name (repeating with gap)
  playRingtone(name: string) {
    this.playWithGap(`ringtones/${name || 'default'}.mp3`, 1500)
  }

  // Call ringback beep (what caller hears while waiting) — beep, 1.5s pause, beep
  playRingback() {
    this.playWithGap('beep.mp3', 1500, this.volume * 0.6)
  }

  // Busy tone (one-shot)
  playBusy() {
    this.playFile('busy.mp3', this.volume * 0.8)
  }

  // Voicemail/unavailable — stoppable, calls onEnd when audio finishes naturally
  playVoicemail(onEnd?: () => void): HTMLAudioElement {
    this.stopActive()
    const audio = this.playFile('unavailable.mp3', this.volume * 0.8)
    this.activeAudio = audio
    audio.addEventListener('ended', () => {
      if (this.activeAudio === audio) {
        this.activeAudio = null
        if (onEnd) onEnd()
      }
    })
    return audio
  }

  // Invalid number
  playInvalid() {
    this.playFile('invalid.mp3', this.volume * 0.8)
  }

  tap() {
    if (!this.keyboardSounds) return
    this.playTone(1200, 0.05, 'sine', 0.05)
  }

  key() {
    if (!this.keyboardSounds) return
    this.playTone(1000, 0.08, 'sine', 0.08)
  }

  // DTMF-style keypad tones (dual frequency like real phones)
  dtmf(key: string) {
    if (!this.ctx) return
    const freqs: Record<string, [number, number]> = {
      '1': [697, 1209], '2': [697, 1336], '3': [697, 1477],
      '4': [770, 1209], '5': [770, 1336], '6': [770, 1477],
      '7': [852, 1209], '8': [852, 1336], '9': [852, 1477],
      '*': [941, 1209], '0': [941, 1336], '#': [941, 1477],
    }
    const pair = freqs[key]
    if (!pair) return
    const dur = 0.12
    const vol = 0.06
    for (const f of pair) {
      const osc = this.ctx.createOscillator()
      const gain = this.ctx.createGain()
      osc.type = 'sine'
      osc.frequency.value = f
      gain.gain.value = vol
      osc.connect(gain)
      gain.connect(this.ctx.destination)
      osc.start()
      gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + dur)
      osc.stop(this.ctx.currentTime + dur)
    }
  }

  send() { this.playTone(880, 0.1, 'sine', 0.15) }
  receive() { this.playTone(660, 0.15, 'sine', 0.12) }
  notification() { this.playTone(800, 0.2, 'triangle', 0.2) }
  lock() { this.playTone(500, 0.08, 'sine', 0.1) }
  unlock() { this.playTone(700, 0.08, 'sine', 0.1) }
  delete() { this.playTone(300, 0.1, 'sine', 0.1) }
  callEnd() {
    this.stopAll()
    this.playTone(400, 0.3, 'sine', 0.15)
  }
  callConnect() {
    this.stopAll()
    this.playTone(600, 0.1, 'sine', 0.15)
    setTimeout(() => this.playTone(800, 0.1, 'sine', 0.15), 100)
  }
  shutter() {
    this.playTone(1500, 0.05, 'square', 0.1)
    setTimeout(() => this.playTone(1200, 0.08, 'square', 0.08), 50)
  }
}

export const soundManager = new SoundManager()
