import { settings } from './settings.svelte'

const NE_DIGITS = '०१२३४५६७८९'

/** Nepali digits when the language is Nepali. Pass any text that holds numbers. */
export function digits(text: string | number): string {
  const s = String(text)
  return settings.ne ? s.replace(/\d/g, (d) => NE_DIGITS[Number(d)]) : s
}

/**
 * Pick the English or the Nepali text. Reads the language state, so any component that calls it
 * in its markup updates by itself when the language changes.
 *   {tr('Add', 'थप्ने')}
 */
export function tr(en: string, ne?: string): string {
  return settings.ne && ne ? ne : en
}

/** A plain number with Indian grouping (1,24,000), Nepali digits in Nepali mode. */
export function num(n: number, maxFraction = 0): string {
  return digits(n.toLocaleString('en-IN', { maximumFractionDigits: maxFraction }))
}

/** Plural helper for English. Nepali has the same word for one and many. */
export function plural(n: number, one: string, many: string, ne?: string): string {
  if (settings.ne && ne) return ne
  return n === 1 ? one : many
}
