// Mirrors how the server spreads a customer payment over open bills: oldest bill first.
// Used only for the live preview on the take payment screen. The server still decides the real result.

export interface OpenBill {
  id: number
  bill_no: string | null
  /** Paisa still to pay on this bill. */
  balance: number
  sold_at: string
}

export interface BillShare<T extends OpenBill> {
  bill: T
  /** Paisa this payment puts on the bill. Always more than 0. */
  pays: number
  paidOff: boolean
}

export interface Allocation<T extends OpenBill> {
  allocations: BillShare<T>[]
  /** Paisa left over after every open bill is paid. More than 0 only when the amount is too big. */
  leftover: number
}

export function allocateOldestFirst<T extends OpenBill>(bills: T[], amount: number): Allocation<T> {
  const open = bills
    .filter((b) => b.balance > 0)
    .sort((a, b) => Date.parse(a.sold_at) - Date.parse(b.sold_at) || a.id - b.id)

  let left = Math.max(0, Math.round(amount))
  const allocations: BillShare<T>[] = []

  for (const bill of open) {
    if (left === 0) break
    const pays = Math.min(bill.balance, left)
    left -= pays
    allocations.push({ bill, pays, paidOff: pays === bill.balance })
  }

  return { allocations, leftover: left }
}
