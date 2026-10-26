import { describe, expect, it } from 'vitest'
import { allocateOldestFirst, type OpenBill } from './allocation'

const bills: OpenBill[] = [
  { id: 3, bill_no: 'S-0412', balance: 124000, sold_at: '2026-10-26T07:26:03+00:00' },
  { id: 1, bill_no: 'S-0301', balance: 300000, sold_at: '2026-09-18T04:00:00+00:00' },
  { id: 2, bill_no: 'S-0377', balance: 210000, sold_at: '2026-10-14T04:00:00+00:00' },
  { id: 4, bill_no: 'S-0400', balance: 0, sold_at: '2026-09-01T04:00:00+00:00' },
]

describe('allocateOldestFirst', () => {
  it('pays the oldest bill first and skips bills with no balance', () => {
    const { allocations, leftover } = allocateOldestFirst(bills, 400000)
    expect(allocations.map((a) => a.bill.bill_no)).toEqual(['S-0301', 'S-0377'])
    expect(allocations.map((a) => a.pays)).toEqual([300000, 100000])
    expect(leftover).toBe(0)
  })

  it('marks only the fully paid bills as paid off', () => {
    const { allocations } = allocateOldestFirst(bills, 400000)
    expect(allocations.map((a) => a.paidOff)).toEqual([true, false])
  })

  it('pays every open bill when the amount equals the total owed', () => {
    const { allocations, leftover } = allocateOldestFirst(bills, 634000)
    expect(allocations.every((a) => a.paidOff)).toBe(true)
    expect(allocations.reduce((sum, a) => sum + a.pays, 0)).toBe(634000)
    expect(leftover).toBe(0)
  })

  it('returns the amount that is more than the total owed as leftover', () => {
    const { allocations, leftover } = allocateOldestFirst(bills, 700000)
    expect(allocations.length).toBe(3)
    expect(leftover).toBe(66000)
  })

  it('returns nothing for zero or negative amounts', () => {
    expect(allocateOldestFirst(bills, 0)).toEqual({ allocations: [], leftover: 0 })
    expect(allocateOldestFirst(bills, -500).allocations).toEqual([])
  })

  it('does not change the input order of the bills', () => {
    const copy = bills.map((b) => b.id)
    allocateOldestFirst(bills, 100)
    expect(bills.map((b) => b.id)).toEqual(copy)
  })
})
