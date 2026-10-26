import { digits } from './i18n'

/** Whole paisa to a number of rupees (for maths that needs it). Round only when showing. */
export const toRupees = (paisa: number): number => paisa / 100

/**
 * "Rs 1,24,000". Paisa show only when there are some, or when `paisa: true` (VAT screens).
 * Negative amounts keep the minus sign: "-Rs 500".
 */
export function rs(paisa: number | null | undefined, opts: { paisa?: boolean } = {}): string {
  const value = Math.round(paisa ?? 0)
  const sign = value < 0 ? '-' : ''
  const abs = Math.abs(value)
  const whole = Math.floor(abs / 100)
  const cents = abs % 100
  let text = whole.toLocaleString('en-IN')
  if (opts.paisa || cents !== 0) text += `.${String(cents).padStart(2, '0')}`
  return digits(`${sign}Rs ${text}`)
}

/**
 * Text typed by a person ("1,250.50") to whole paisa. Returns null for text that is not a money amount.
 * Never uses floating point maths on the paisa, so 0.1 + 0.2 style errors cannot happen.
 */
export function toPaisa(input: string | number | null | undefined): number | null {
  if (input === null || input === undefined) return null
  const text = String(input).replace(/[,\s]/g, '').replace(/^Rs\.?/i, '')
  if (!/^\d*\.?\d{0,2}$/.test(text) || text === '' || text === '.') return null
  const [whole, frac = ''] = text.split('.')
  return Number(whole || '0') * 100 + Number(frac.padEnd(2, '0'))
}

/** Paisa back to the text a person types into an amount box ("1250.5" style, no grouping). */
export function fromPaisa(paisa: number): string {
  const whole = Math.floor(Math.abs(paisa) / 100)
  const cents = Math.abs(paisa) % 100
  const sign = paisa < 0 ? '-' : ''
  return cents === 0 ? `${sign}${whole}` : `${sign}${whole}.${String(cents).padStart(2, '0').replace(/0$/, '')}`
}

/** Percent of an amount, rounded to whole paisa. */
export function percentOf(paisa: number, percent: number): number {
  return Math.round((paisa * percent) / 100)
}
