import { addDaysAd, bsMonthRange, shiftMonth, todayAd, todayBs } from './bs'

export type RangePreset = 'today' | 'week' | 'month' | 'last_month' | 'quarter' | 'custom'

export type FixedPreset = Exclude<RangePreset, 'custom'>

export interface DateRange {
  /** AD "YYYY-MM-DD", included. */
  from: string
  /** AD "YYYY-MM-DD", included. */
  to: string
}

/**
 * Dates of a preset, counted in shop days (Nepal). Pass `now` to count from another moment.
 *   today: today only
 *   week: the last 7 days, today included
 *   month: this Nepali month, from its first day to today
 *   last_month: the whole Nepali month before this one
 *   quarter: from the first day of the Nepali month two months back, to today
 */
export function rangeFor(preset: FixedPreset, now: Date = new Date()): DateRange {
  const today = todayAd(now)
  const bs = todayBs(now)
  switch (preset) {
    case 'today':
      return { from: today, to: today }
    case 'week':
      return { from: addDaysAd(today, -6), to: today }
    case 'month':
      return { from: bsMonthRange(bs.year, bs.month).from, to: today }
    case 'last_month': {
      const prev = shiftMonth(bs.year, bs.month, -1)
      return bsMonthRange(prev.year, prev.month)
    }
    case 'quarter': {
      const start = shiftMonth(bs.year, bs.month, -2)
      return { from: bsMonthRange(start.year, start.month).from, to: today }
    }
  }
}
