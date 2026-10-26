import type { Customer, Item } from './types'

// The selling cart: lines, bill discount, customer and payment. Money is whole paisa.
// The cart and the held carts are kept in localStorage, so a refresh does not lose them.

export type Method = 'cash' | 'qr' | 'bank' | 'card' | 'esewa' | 'khalti'

export type CartItem = Pick<Item, 'id' | 'name' | 'unit' | 'sell_price' | 'quantity' | 'vat_applies' | 'photo_url'>

export interface CartLine {
  item: CartItem
  qty: number
}

export interface HeldCart {
  id: string
  label: string
  at: string
  lines: CartLine[]
  discount: number
  customer: Customer | null
  paid: number | null
  method: Method
  note: string
}

export interface VatSplit {
  taxable: number
  vat: number
  exempt: number
  total: number
}

export interface ReturnSplit {
  debtDown: number
  cashBack: number
  balanceAfter: number
}

export const MAX_LINES = 100

const CART_KEY = 'pasal-cart'
const HELD_KEY = 'pasal-held'

export function snapshotOf(item: CartItem): CartItem {
  return {
    id: item.id,
    name: item.name,
    unit: item.unit,
    sell_price: item.sell_price,
    quantity: item.quantity,
    vat_applies: item.vat_applies,
    photo_url: item.photo_url,
  }
}

export const lineAmount = (line: CartLine): number => line.qty * line.item.sell_price

export const countOf = (lines: CartLine[]): number => lines.reduce((sum, line) => sum + line.qty, 0)

export const subtotalOf = (lines: CartLine[]): number => lines.reduce((sum, line) => sum + lineAmount(line), 0)

export const totalOf = (subtotal: number, discount: number): number => Math.max(0, subtotal - discount)

/** Paid null means "paid in full". */
export const balanceOf = (total: number, paid: number | null): number => total - (paid ?? total)

/**
 * The browser's estimate of the VAT on a bill. The bill from the server is the final figure.
 * The discount is shared by price, the same way the server does it.
 */
export function vatBreakdown(lines: CartLine[], discount: number, rate: number): VatSplit {
  const subtotal = subtotalOf(lines)
  const vatable = lines.filter((line) => line.item.vat_applies).reduce((sum, line) => sum + lineAmount(line), 0)
  const exempt = subtotal - vatable
  const share = subtotal > 0 ? Math.round((discount * vatable) / subtotal) : 0
  const vatableAfter = vatable - share
  const exemptAfter = exempt - (discount - share)
  const taxable = Math.round((vatableAfter * 100) / (100 + rate))
  return { taxable, vat: vatableAfter - taxable, exempt: exemptAfter, total: vatableAfter + exemptAfter }
}

/** Value of `qty` units of a sold line that cost `lineTotal` for `quantity` units. Half up, whole paisa. */
export function returnValue(qty: number, lineTotal: number, quantity: number): number {
  if (qty <= 0 || quantity <= 0) return 0
  const q = BigInt(quantity)
  return Number((BigInt(qty) * BigInt(lineTotal) * 2n + q) / (2n * q))
}

/** Where the money of a return goes: the debt first, the rest back in cash. `balance` is the sale balance. */
export function returnPreview(value: number, balance: number): ReturnSplit {
  const debtDown = Math.min(value, Math.max(0, balance))
  return { debtDown, cashBack: value - debtDown, balanceAfter: Math.max(0, balance - value) }
}

/** True when this sale would push the customer past the credit limit. */
export function overLimit(owes: number, balance: number, limit: number | null): boolean {
  return limit !== null && balance > 0 && owes + balance > limit
}

function read<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    return raw ? (JSON.parse(raw) as T) : fallback
  } catch {
    return fallback
  }
}

function write(key: string, value: unknown): void {
  try {
    localStorage.setItem(key, JSON.stringify(value))
  } catch {
    // Storage can be blocked (private mode). The cart still works for this visit.
  }
}

function copy<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T
}

class Cart {
  lines = $state<CartLine[]>([])
  discount = $state(0)
  customer = $state<Customer | null>(null)
  paid = $state<number | null>(null)
  method = $state<Method>('cash')
  note = $state('')
  held = $state<HeldCart[]>([])

  constructor() {
    const saved = read<Partial<Omit<HeldCart, 'id' | 'label' | 'at'>>>(CART_KEY, {})
    this.lines = saved.lines ?? []
    this.discount = saved.discount ?? 0
    this.customer = saved.customer ?? null
    this.paid = saved.paid ?? null
    this.method = saved.method ?? 'cash'
    this.note = saved.note ?? ''
    this.held = read<HeldCart[]>(HELD_KEY, [])
  }

  get count(): number {
    return countOf(this.lines)
  }

  get subtotal(): number {
    return subtotalOf(this.lines)
  }

  get total(): number {
    return totalOf(this.subtotal, this.discount)
  }

  get paidAmount(): number {
    return this.paid ?? this.total
  }

  get balance(): number {
    return balanceOf(this.total, this.paid)
  }

  get stockProblem(): boolean {
    return this.lines.some((line) => line.qty > line.item.quantity)
  }

  get canCheckout(): boolean {
    if (this.lines.length === 0 || this.stockProblem) return false
    if (this.balance < 0) return false
    return this.balance === 0 || this.customer !== null
  }

  /** Adds one unit. Returns false when the item is out of stock or the cart is full. */
  add(item: CartItem): boolean {
    const line = this.lines.find((l) => l.item.id === item.id)
    if (!line && this.lines.length >= MAX_LINES) return false
    if ((line?.qty ?? 0) >= item.quantity) return false
    if (line) {
      line.qty += 1
      line.item = snapshotOf(item)
    } else {
      this.lines.push({ item: snapshotOf(item), qty: 1 })
    }
    this.save()
    return true
  }

  /** Sets the quantity, never below 1 and never above the stock seen when the item was added. */
  setQty(itemId: number, qty: number): void {
    const line = this.lines.find((l) => l.item.id === itemId)
    if (!line) return
    line.qty = Math.min(Math.max(1, Math.round(qty)), Math.max(1, line.item.quantity))
    this.save()
  }

  remove(itemId: number): void {
    this.lines = this.lines.filter((l) => l.item.id !== itemId)
    this.save()
  }

  setDiscount(paisa: number): void {
    this.discount = Math.max(0, Math.round(paisa))
    this.save()
  }

  setPaid(paisa: number | null): void {
    this.paid = paisa
    this.save()
  }

  setCustomer(customer: Customer | null): void {
    this.customer = customer
    this.save()
  }

  setMethod(method: Method): void {
    this.method = method
    this.save()
  }

  setNote(text: string): void {
    this.note = text
    this.save()
  }

  clear(): void {
    this.lines = []
    this.discount = 0
    this.customer = null
    this.paid = null
    this.method = 'cash'
    this.note = ''
    this.save()
  }

  /** Parks the current cart in the held list and empties the cart. */
  hold(label = ''): HeldCart | null {
    if (this.lines.length === 0) return null
    const entry: HeldCart = {
      id: crypto.randomUUID(),
      label: label.trim() || this.customer?.name || '',
      at: new Date().toISOString(),
      lines: copy(this.lines),
      discount: this.discount,
      customer: copy(this.customer),
      paid: this.paid,
      method: this.method,
      note: this.note,
    }
    this.held = [entry, ...this.held]
    this.clear()
    this.saveHeld()
    return entry
  }

  /** Puts a held cart back in the cart. A cart that has lines is held first, so nothing is lost. */
  restore(id: string): boolean {
    const entry = this.held.find((h) => h.id === id)
    if (!entry) return false
    if (this.lines.length > 0) this.hold()
    this.held = this.held.filter((h) => h.id !== id)
    this.lines = copy(entry.lines)
    this.discount = entry.discount
    this.customer = copy(entry.customer)
    this.paid = entry.paid
    this.method = entry.method
    this.note = entry.note
    this.save()
    this.saveHeld()
    return true
  }

  /** Forget the cart and every held cart. Used when someone logs out, so the next person never sees them. */
  reset(): void {
    this.clear()
    this.held = []
    this.saveHeld()
  }

  discard(id: string): void {
    this.held = this.held.filter((h) => h.id !== id)
    this.saveHeld()
  }

  private save(): void {
    write(CART_KEY, {
      lines: this.lines,
      discount: this.discount,
      customer: this.customer,
      paid: this.paid,
      method: this.method,
      note: this.note,
    })
  }

  private saveHeld(): void {
    write(HELD_KEY, this.held)
  }
}

export const cart = new Cart()
