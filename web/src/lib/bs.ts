// Nepali (Bikram Sambat, BS) calendar. The API only knows AD dates (YYYY-MM-DD), so the apps convert here.
// Month lengths for BS 2000 to 2090 come from the MIT licensed `nepali-date-converter` package (subeshb1/Nepali-Date).
// Anchor: BS 2000-01-01 is AD 1943-04-14. Checked: BS 2083-07-01 (Kartik 1) is AD 2026-10-18.
// Dates outside 2000-2090 throw, so a wrong date is never shown silently.
import { digits } from './i18n'
import { settings } from './settings.svelte'

const DAYS: Record<number, number[]> = {
  2000: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2001: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2002: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2003: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2004: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2005: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2006: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2007: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2008: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
  2009: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2010: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2011: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2012: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2013: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2014: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2015: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2016: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2017: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2018: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2019: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2020: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2021: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2022: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2023: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2024: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2025: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2026: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2027: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2028: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2029: [31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
  2030: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2031: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2032: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2033: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2034: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2035: [30, 32, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
  2036: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2037: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2038: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2039: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2040: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2041: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2042: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2043: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2044: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2045: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2046: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2047: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2048: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2049: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2050: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2051: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2052: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2053: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2054: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2055: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2056: [31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
  2057: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2058: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2059: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2060: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2061: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2062: [30, 32, 31, 32, 31, 31, 29, 30, 29, 30, 29, 31],
  2063: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2064: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2065: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2066: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
  2067: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2068: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2069: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2070: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2071: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2072: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2073: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2074: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2075: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2076: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2077: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2078: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2079: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2080: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2081: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2082: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2083: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2084: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2085: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2086: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2087: [31, 31, 32, 31, 31, 31, 30, 30, 29, 30, 30, 30],
  2088: [30, 31, 32, 32, 30, 31, 30, 30, 29, 30, 30, 30],
  2089: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
  2090: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
}

export const MIN_YEAR = 2000
export const MAX_YEAR = 2090

export const MONTHS_EN = ['Baisakh', 'Jestha', 'Ashadh', 'Shrawan', 'Bhadra', 'Ashoj', 'Kartik', 'Mangsir', 'Poush', 'Magh', 'Falgun', 'Chaitra']
export const MONTHS_NE = ['बैशाख', 'जेठ', 'असार', 'श्रावण', 'भदौ', 'असोज', 'कात्तिक', 'मंसिर', 'पुष', 'माघ', 'फागुन', 'चैत']
const WEEKDAYS_EN = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
const WEEKDAYS_NE = ['आइतबार', 'सोमबार', 'मंगलबार', 'बुधबार', 'बिहीबार', 'शुक्रबार', 'शनिबार']
const AD_MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

export interface Bs {
  year: number
  /** 1 to 12 */
  month: number
  day: number
}

const DAY_MS = 86_400_000
const ANCHOR_AD = Date.UTC(1943, 3, 14) // BS 2000-01-01

/** "2026-10-18" to UTC midnight in ms. */
function adMs(ad: string): number {
  const [y, m, d] = ad.split('-').map(Number)
  return Date.UTC(y, m - 1, d)
}

function adString(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10)
}

export function daysInBsMonth(year: number, month: number): number {
  const row = DAYS[year]
  if (!row || month < 1 || month > 12) throw new RangeError(`BS date out of range: ${year}-${month}`)
  return row[month - 1]
}

/** Gregorian "YYYY-MM-DD" to BS. */
export function adToBs(ad: string): Bs {
  let left = Math.round((adMs(ad) - ANCHOR_AD) / DAY_MS)
  if (left < 0) throw new RangeError(`AD date before BS ${MIN_YEAR}: ${ad}`)
  for (let year = MIN_YEAR; year <= MAX_YEAR; year++) {
    for (let m = 0; m < 12; m++) {
      const len = DAYS[year][m]
      if (left < len) return { year, month: m + 1, day: left + 1 }
      left -= len
    }
  }
  throw new RangeError(`AD date after BS ${MAX_YEAR}: ${ad}`)
}

/** BS to Gregorian "YYYY-MM-DD". */
export function bsToAd(year: number, month: number, day: number): string {
  if (day < 1 || day > daysInBsMonth(year, month)) throw new RangeError(`BS date out of range: ${year}-${month}-${day}`)
  let days = 0
  for (let y = MIN_YEAR; y < year; y++) days += DAYS[y].reduce((a, b) => a + b, 0)
  for (let m = 1; m < month; m++) days += daysInBsMonth(year, m)
  return adString(ANCHOR_AD + (days + day - 1) * DAY_MS)
}

/** Today in Nepal time (the shop's day), as an AD "YYYY-MM-DD". */
export function todayAd(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kathmandu', year: 'numeric', month: '2-digit', day: '2-digit' }).format(now)
}

export function todayBs(now: Date = new Date()): Bs {
  return adToBs(todayAd(now))
}

export function addDaysAd(ad: string, days: number): string {
  return adString(adMs(ad) + days * DAY_MS)
}

export function monthName(month: number, ne = settings.ne): string {
  return (ne ? MONTHS_NE : MONTHS_EN)[month - 1]
}

/** The label the API stores for a VAT period: "2083-07". */
export function periodLabel(year: number, month: number): string {
  return `${year}-${String(month).padStart(2, '0')}`
}

/** First and last AD day of one BS month. */
export function bsMonthRange(year: number, month: number): { from: string; to: string } {
  return { from: bsToAd(year, month, 1), to: bsToAd(year, month, daysInBsMonth(year, month)) }
}

/** The BS month before (-1) or after (+1). */
export function shiftMonth(year: number, month: number, by: number): { year: number; month: number } {
  const index = year * 12 + (month - 1) + by
  return { year: Math.floor(index / 12), month: (index % 12) + 1 }
}

/** "Kartik 2083" / "कात्तिक २०८३" */
export function monthTitle(year: number, month: number): string {
  return digits(`${monthName(month)} ${year}`)
}

/** "Kartik 9, 2083" with BS first. Pass an AD date or a full ISO date-time. */
export function formatBs(ad: string): string {
  const b = adToBs(ad.slice(0, 10))
  return digits(`${monthName(b.month)} ${b.day}, ${b.year}`)
}

/** "26 Oct 2026" */
export function formatAd(ad: string): string {
  const [y, m, d] = ad.slice(0, 10).split('-').map(Number)
  return digits(`${d} ${AD_MONTHS[m - 1]} ${y}`)
}

export function weekday(ad: string, ne = settings.ne): string {
  const idx = new Date(adMs(ad.slice(0, 10))).getUTCDay()
  return (ne ? WEEKDAYS_NE : WEEKDAYS_EN)[idx]
}

/** The Nepal calendar date of a stored UTC time stamp ("2026-10-26T07:26:03+00:00"). */
export function adOfStamp(iso: string): string {
  return todayAd(new Date(iso))
}

/** Main date text: BS first (or AD first when the setting is off). */
export function formatDate(isoOrAd: string): string {
  const ad = isoOrAd.length > 10 ? adOfStamp(isoOrAd) : isoOrAd
  return settings.bsDates ? formatBs(ad) : formatAd(ad)
}

/** The small second line: the other calendar. */
export function formatDateSub(isoOrAd: string): string {
  const ad = isoOrAd.length > 10 ? adOfStamp(isoOrAd) : isoOrAd
  return settings.bsDates ? formatAd(ad) : formatBs(ad)
}

/** "10:42 AM" in Nepal time. */
export function formatTime(iso: string): string {
  return digits(new Intl.DateTimeFormat('en-US', { timeZone: 'Asia/Kathmandu', hour: 'numeric', minute: '2-digit' }).format(new Date(iso)))
}

/** Whole days from today (Nepal) to an AD date. Negative when it has passed. */
export function daysUntil(ad: string, now: Date = new Date()): number {
  return Math.round((adMs(ad) - adMs(todayAd(now))) / DAY_MS)
}
