import { describe, expect, it } from 'vitest'
import { adToBs, bsToAd, bsMonthRange, daysInBsMonth, periodLabel, shiftMonth, todayAd, daysUntil } from './bs'
import { rs, toPaisa, fromPaisa, percentOf } from './money'
import { match } from './router.svelte'
import { csvCell, whatsappHref, initials } from './util'

describe('money', () => {
  it('shows rupees with Indian grouping and paisa only when needed', () => {
    expect(rs(12400000)).toBe('Rs 1,24,000')
    expect(rs(26633, { paisa: false })).toBe('Rs 266.33')
    expect(rs(100, { paisa: true })).toBe('Rs 1.00')
    expect(rs(-50000)).toBe('-Rs 500')
    expect(rs(null)).toBe('Rs 0')
  })
  it('turns typed text into whole paisa without float errors', () => {
    expect(toPaisa('1,250.50')).toBe(125050)
    expect(toPaisa('0.1')).toBe(10)
    expect(toPaisa('19.99')).toBe(1999)
    expect(toPaisa('Rs 5')).toBe(500)
    expect(toPaisa('')).toBeNull()
    expect(toPaisa('1.234')).toBeNull()
    expect(toPaisa('abc')).toBeNull()
  })
  it('round trips', () => {
    expect(fromPaisa(125050)).toBe('1250.5')
    expect(fromPaisa(500)).toBe('5')
    expect(percentOf(10000, 13)).toBe(1300)
  })
})

describe('Nepali calendar', () => {
  it('matches the known dates', () => {
    expect(bsToAd(2083, 7, 1)).toBe('2026-10-18') // Kartik 1, 2083
    expect(adToBs('2026-10-26')).toEqual({ year: 2083, month: 7, day: 9 })
    expect(bsToAd(2000, 1, 1)).toBe('1943-04-14')
  })
  it('gives the VAT month range', () => {
    expect(daysInBsMonth(2083, 7)).toBe(30)
    expect(bsMonthRange(2083, 7)).toEqual({ from: '2026-10-18', to: '2026-11-16' })
    expect(periodLabel(2083, 7)).toBe('2083-07')
  })
  it('round trips every day of two years', () => {
    for (let m = 1; m <= 12; m++) {
      for (let d = 1; d <= daysInBsMonth(2082, m); d++) {
        expect(adToBs(bsToAd(2082, m, d))).toEqual({ year: 2082, month: m, day: d })
      }
    }
  })
  it('moves between months', () => {
    expect(shiftMonth(2083, 1, -1)).toEqual({ year: 2082, month: 12 })
    expect(shiftMonth(2083, 12, 1)).toEqual({ year: 2084, month: 1 })
  })
  it('uses Nepal time for today', () => {
    // 2026-10-25 20:00 UTC is already 26 Oct in Nepal.
    expect(todayAd(new Date('2026-10-25T20:00:00Z'))).toBe('2026-10-26')
    expect(daysUntil('2026-10-27', new Date('2026-10-25T20:00:00Z'))).toBe(1)
  })
  it('refuses dates it cannot convert', () => {
    expect(() => bsToAd(1999, 1, 1)).toThrow()
    expect(() => bsToAd(2083, 7, 31)).toThrow()
  })
})

describe('helpers', () => {
  it('matches routes', () => {
    expect(match('/items/:id', '/items/12')).toEqual({ id: '12' })
    expect(match('/items/:id', '/items')).toBeNull()
    expect(match('/items/new', '/items/12')).toBeNull()
  })
  it('keeps CSV cells safe', () => {
    expect(csvCell('=SUM(A1)')).toBe("'=SUM(A1)")
    expect(csvCell('a,b')).toBe('"a,b"')
    expect(csvCell('say "hi"')).toBe('"say ""hi"""')
  })
  it('builds links and initials', () => {
    expect(whatsappHref('9800000001', 'Hi')).toBe('https://wa.me/9779800000001?text=Hi')
    expect(initials('Hari Thapa')).toBe('HT')
  })
})
