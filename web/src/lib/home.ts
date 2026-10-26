import { addDaysAd, bsMonthRange, daysUntil, shiftMonth, todayBs } from './bs'
import { num, tr } from './i18n'
import { settings } from './settings.svelte'

export type CardKey = 'sales' | 'cash' | 'collect' | 'owe' | 'low' | 'vat' | 'week' | 'profit'

export const CARD_KEYS: CardKey[] = ['sales', 'cash', 'collect', 'owe', 'low', 'vat', 'week', 'profit']

const ORDER_KEY = 'pasal-home-order'

export function loadOrder(): CardKey[] {
  let saved: unknown = []
  try {
    saved = JSON.parse(localStorage.getItem(ORDER_KEY) ?? '[]')
  } catch {
    saved = []
  }
  const known = Array.isArray(saved) ? saved.filter((k): k is CardKey => CARD_KEYS.includes(k as CardKey)) : []
  return [...new Set([...known, ...CARD_KEYS])]
}

export function saveOrder(order: CardKey[]): void {
  try {
    localStorage.setItem(ORDER_KEY, JSON.stringify(order))
  } catch {
    // Storage can be blocked. The new order still applies for this visit.
  }
}

export interface VatPeriod {
  year: number
  month: number
  /** First and last AD day of the BS month. */
  from: string
  to: string
  /** Last day of the period + 25 days (VAT Act 2052, section 18). */
  due: string
  daysLeft: number
}

function vatPeriod(year: number, month: number, now: Date): VatPeriod {
  const { from, to } = bsMonthRange(year, month)
  const due = addDaysAd(to, 25)
  return { year, month, from, to, due, daysLeft: daysUntil(due, now) }
}

/**
 * The VAT period whose payment date is still ahead. That is the last Nepali month, until its
 * due date has passed. The current month is always 25 or more days from its due date.
 */
export function nextVat(now: Date = new Date()): VatPeriod {
  const today = todayBs(now)
  const last = shiftMonth(today.year, today.month, -1)
  const previous = vatPeriod(last.year, last.month, now)
  return previous.daysLeft >= 0 ? previous : vatPeriod(today.year, today.month, now)
}

/** "due today", "due in 16 days", "3 days late" (with Nepali text). */
export function dueText(days: number): string {
  if (days === 0) return tr('due today', 'आजै बुझाउने')
  if (days < 0) return tr(`${num(-days)} days late`, `${num(-days)} दिन ढिला`)
  return tr(`due in ${num(days)} ${days === 1 ? 'day' : 'days'}`, `${num(days)} दिनमा बुझाउने`)
}

const WEEKDAY_SHORT_EN = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const WEEKDAY_SHORT_NE = ['आइत', 'सोम', 'मंगल', 'बुध', 'बिही', 'शुक्र', 'शनि']

/** "Mon" or "सोम" for an AD date. */
export function shortWeekday(ad: string): string {
  const index = new Date(`${ad}T00:00:00Z`).getUTCDay()
  return (settings.ne ? WEEKDAY_SHORT_NE : WEEKDAY_SHORT_EN)[index]
}
