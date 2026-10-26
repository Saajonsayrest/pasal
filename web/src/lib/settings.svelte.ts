// Look and language of this browser. Saved in localStorage (these are not secrets).

export type Lang = 'en' | 'ne'
export type Theme = 'light' | 'dark' | 'black'

export const SEEDS = ['#1f8a63', '#2563eb', '#7c4ddb', '#dc2f55', '#e0731a', '#0e8f9e', '#4b5563']

const KEY = 'pasal-settings'

interface Saved {
  lang: Lang
  theme: Theme
  seed: string
  bsDates: boolean
}

const DEFAULTS: Saved = { lang: 'en', theme: 'light', seed: SEEDS[0], bsDates: true }

function read(): Saved {
  try {
    return { ...DEFAULTS, ...(JSON.parse(localStorage.getItem(KEY) ?? '{}') as Partial<Saved>) }
  } catch {
    return { ...DEFAULTS }
  }
}

class Settings {
  lang = $state<Lang>(DEFAULTS.lang)
  theme = $state<Theme>(DEFAULTS.theme)
  seed = $state(DEFAULTS.seed)
  /** Show the Nepali (BS) date first. */
  bsDates = $state(DEFAULTS.bsDates)

  constructor() {
    const s = read()
    this.lang = s.lang
    this.theme = s.theme
    this.seed = s.seed
    this.bsDates = s.bsDates
    this.apply()
  }

  get ne(): boolean {
    return this.lang === 'ne'
  }

  set(patch: Partial<Saved>): void {
    if (patch.lang) this.lang = patch.lang
    if (patch.theme) this.theme = patch.theme
    if (patch.seed) this.seed = patch.seed
    if (patch.bsDates !== undefined) this.bsDates = patch.bsDates
    try {
      localStorage.setItem(KEY, JSON.stringify({ lang: this.lang, theme: this.theme, seed: this.seed, bsDates: this.bsDates }))
    } catch {
      // storage can be blocked (private mode). The look still changes for this visit.
    }
    this.apply()
  }

  private apply(): void {
    const root = document.documentElement
    root.dataset.theme = this.theme
    root.lang = this.lang
    root.style.setProperty('--seed', this.seed)
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', this.seed)
  }
}

export const settings = new Settings()
