// VAT helpers for the VAT screens only (I1 to I5).
import type { ApiError } from './api'
import { addDaysAd, daysUntil, monthTitle } from './bs'
import type { VatFiling } from './types'

/** Days after the last day of a VAT period when the return is due (VAT Act 2052, section 18, per docs/api-reference.md). */
export const DUE_DAYS = 25

const PERIOD = /^(\d{4})-(\d{2})$/

/** "2083-07" to { year: 2083, month: 7 }. Null for any other label, for example a typed name. */
export function parsePeriod(label: string): { year: number; month: number } | null {
  const m = PERIOD.exec(label)
  if (!m) return null
  const month = Number(m[2])
  if (month < 1 || month > 12) return null
  return { year: Number(m[1]), month }
}

/** "2083-07" to "Kartik 2083". Labels that are not year-month are shown as they are. */
export function periodTitle(label: string): string {
  const p = parsePeriod(label)
  return p ? monthTitle(p.year, p.month) : label
}

/** The day the return for a period is due: last day of the period plus DUE_DAYS. */
export function dueDate(periodTo: string): string {
  return addDaysAd(periodTo, DUE_DAYS)
}

/** Whole days from today to the due date of a period. Negative when it has passed. */
export function dueInDays(periodTo: string): number {
  return daysUntil(dueDate(periodTo))
}

export function remainingToPay(f: VatFiling): number {
  return Math.max(0, f.payable - f.paid_amount)
}

export type FilingStatus = 'not_filed' | 'filed' | 'paid'

export function filingStatus(f: VatFiling): FilingStatus {
  if (!f.filed_on) return 'not_filed'
  if (f.payable > 0 && f.paid_amount >= f.payable) return 'paid'
  return 'filed'
}

export const FILING_STATUS: Record<FilingStatus, { cls: string; icon: string; en: string; ne: string }> = {
  not_filed: { cls: 'warn', icon: 'pending_actions', en: 'Not filed', ne: 'फाइल भएको छैन' },
  filed: { cls: 'info', icon: 'task_alt', en: 'Filed', ne: 'फाइल भएको' },
  paid: { cls: 'good', icon: 'check_circle', en: 'Paid', ne: 'फाइल र भुक्तानी भयो' },
}

/**
 * The first message to show for a failed save. Field names in `shown` are skipped because the
 * screen shows them next to their field. Returns null when every message is shown elsewhere.
 */
export function errorText(e: ApiError | null, shown: string[] = []): string | null {
  if (!e) return null
  if (Object.keys(e.errors).length === 0) return e.message
  const rest = Object.entries(e.errors)
    .filter(([name]) => !shown.includes(name))
    .flatMap(([, messages]) => messages)
  return rest[0] ?? null
}

/** Whole paisa as "1,24,000.50" (no Rs sign). Pass grouped false for CSV files. */
export function plainAmount(paisa: number, grouped = true): string {
  const sign = paisa < 0 ? '-' : ''
  const abs = Math.abs(Math.round(paisa))
  const whole = Math.floor(abs / 100)
  const cents = String(abs % 100).padStart(2, '0')
  return `${sign}${grouped ? whole.toLocaleString('en-IN') : String(whole)}.${cents}`
}
