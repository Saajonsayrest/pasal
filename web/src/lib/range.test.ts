import { describe, expect, it } from 'vitest'
import { rangeFor } from './range'

// 2026-10-26 at 11:45 in Nepal is Kartik 9, 2083 (BS).
const OCT_26 = new Date('2026-10-26T06:00:00Z')

describe('rangeFor', () => {
  it('today is the shop day only', () => {
    expect(rangeFor('today', OCT_26)).toEqual({ from: '2026-10-26', to: '2026-10-26' })
  })

  it('last 7 days includes today', () => {
    expect(rangeFor('week', OCT_26)).toEqual({ from: '2026-10-20', to: '2026-10-26' })
  })

  it('this month starts on the first Nepali day and ends today', () => {
    expect(rangeFor('month', OCT_26)).toEqual({ from: '2026-10-18', to: '2026-10-26' })
  })

  it('last month is the whole Nepali month before (Ashoj 2083)', () => {
    expect(rangeFor('last_month', OCT_26)).toEqual({ from: '2026-09-17', to: '2026-10-17' })
  })

  it('last 3 months starts two Nepali months back (Bhadra 2083)', () => {
    expect(rangeFor('quarter', OCT_26)).toEqual({ from: '2026-08-17', to: '2026-10-26' })
  })

  it('last month wraps to the previous BS year in Baisakh', () => {
    // 2026-04-20 is Baisakh 7, 2083. Chaitra 2082 runs 2026-03-15 to 2026-04-13.
    expect(rangeFor('last_month', new Date('2026-04-20T06:00:00Z'))).toEqual({ from: '2026-03-15', to: '2026-04-13' })
  })

  it('uses the shop day, not the UTC day', () => {
    // 2026-10-25 18:30 UTC is 2026-10-26 00:15 in Nepal.
    expect(rangeFor('today', new Date('2026-10-25T18:30:00Z'))).toEqual({ from: '2026-10-26', to: '2026-10-26' })
  })

  it('every preset starts on or before its end', () => {
    for (const preset of ['today', 'week', 'month', 'last_month', 'quarter'] as const) {
      const r = rangeFor(preset, OCT_26)
      expect(r.from <= r.to).toBe(true)
    }
  })
})
