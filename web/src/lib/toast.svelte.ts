import { tr } from './i18n'

class Toasts {
  message = $state('')
  visible = $state(false)
  private timer: ReturnType<typeof setTimeout> | undefined

  show(en: string, ne?: string): void {
    this.message = tr(en, ne)
    this.visible = true
    clearTimeout(this.timer)
    this.timer = setTimeout(() => (this.visible = false), 2200)
    navigator.vibrate?.(12)
  }
}

export const toasts = new Toasts()

/** toast('Saved', 'सेभ भयो') */
export const toast = (en: string, ne?: string): void => toasts.show(en, ne)
