import { beforeEach, describe, expect, it } from 'vitest'
import { cart, balanceOf, overLimit, returnPreview, returnValue, subtotalOf, totalOf, vatBreakdown, type CartItem, type CartLine } from './cart.svelte'
import type { Customer } from './types'

const rice: CartItem = { id: 7, name: 'Rice 5kg', unit: 'pcs', sell_price: 11300, quantity: 3, vat_applies: true, photo_url: null }
const milk: CartItem = { id: 9, name: 'Milk 500ml', unit: 'pcs', sell_price: 5000, quantity: 2, vat_applies: false, photo_url: null }
const hari: Customer = { id: 4, name: 'Hari', phone: null, address: null, pan: null, credit_limit: 20000, owes: 0 }

describe('cart maths', () => {
  it('adds the lines, then takes the discount off the subtotal', () => {
    const lines: CartLine[] = [
      { item: rice, qty: 2 },
      { item: milk, qty: 1 },
    ]
    expect(subtotalOf(lines)).toBe(27600)
    expect(totalOf(27600, 1000)).toBe(26600)
    expect(totalOf(100, 500)).toBe(0)
  })

  it('reads the balance as total minus paid, and paid null as paid in full', () => {
    expect(balanceOf(11300, null)).toBe(0)
    expect(balanceOf(11300, 5000)).toBe(6300)
    expect(balanceOf(11300, 0)).toBe(11300)
  })

  it('splits VAT the way the bill does for a VAT item', () => {
    expect(vatBreakdown([{ item: rice, qty: 1 }], 0, 13)).toEqual({ taxable: 10000, vat: 1300, exempt: 0, total: 11300 })
  })

  it('takes the discount off the VAT part first', () => {
    expect(vatBreakdown([{ item: rice, qty: 1 }], 1130, 13)).toEqual({ taxable: 9000, vat: 1170, exempt: 0, total: 10170 })
  })

  it('keeps the split equal to the total when VAT and no-VAT items mix', () => {
    const lines: CartLine[] = [
      { item: { ...rice, sell_price: 10000 }, qty: 1 },
      { item: milk, qty: 1 },
    ]
    const split = vatBreakdown(lines, 0, 13)
    expect(split.taxable + split.vat + split.exempt).toBe(split.total)
    expect(split).toEqual({ taxable: 8850, vat: 1150, exempt: 5000, total: 15000 })
  })

  it('rounds the value of part of a line to whole paisa, half up', () => {
    expect(returnValue(1, 1050, 2)).toBe(525)
    expect(returnValue(1, 100, 3)).toBe(33)
    expect(returnValue(2, 100, 3)).toBe(67)
    expect(returnValue(1, 5, 2)).toBe(3)
    expect(returnValue(0, 5, 2)).toBe(0)
  })

  it('pays the debt down first and gives the rest back in cash', () => {
    expect(returnPreview(105000, 124000)).toEqual({ debtDown: 105000, cashBack: 0, balanceAfter: 19000 })
    expect(returnPreview(105000, 50000)).toEqual({ debtDown: 50000, cashBack: 55000, balanceAfter: 0 })
    expect(returnPreview(30000, 0)).toEqual({ debtDown: 0, cashBack: 30000, balanceAfter: 0 })
  })

  it('flags a credit sale only when it pushes the customer past the limit', () => {
    expect(overLimit(4000, 1500, 5000)).toBe(true)
    expect(overLimit(4000, 500, 5000)).toBe(false)
    expect(overLimit(4000, 0, 0)).toBe(false)
    expect(overLimit(4000, 1500, null)).toBe(false)
  })
})

describe('cart store', () => {
  beforeEach(() => {
    localStorage.clear()
    cart.clear()
    cart.held = []
  })

  it('never adds above the stock', () => {
    expect(cart.add(rice)).toBe(true)
    expect(cart.add(rice)).toBe(true)
    expect(cart.add(rice)).toBe(true)
    expect(cart.add(rice)).toBe(false)
    expect(cart.count).toBe(3)
    expect(cart.canCheckout).toBe(true)
  })

  it('refuses an item with no stock', () => {
    expect(cart.add({ ...rice, quantity: 0 })).toBe(false)
    expect(cart.lines).toHaveLength(0)
  })

  it('needs a customer when the paid amount is less than the total', () => {
    cart.add(rice)
    cart.setPaid(5000)
    expect(cart.balance).toBe(6300)
    expect(cart.canCheckout).toBe(false)
    cart.setCustomer(hari)
    expect(cart.canCheckout).toBe(true)
    cart.setPaid(null)
    cart.setCustomer(null)
    expect(cart.canCheckout).toBe(true)
  })

  it('holds the cart and restores it, keeping the customer name as the label', () => {
    cart.add(milk)
    cart.setCustomer(hari)
    const held = cart.hold()
    expect(held?.label).toBe('Hari')
    expect(cart.lines).toHaveLength(0)
    expect(cart.held).toHaveLength(1)
    expect(localStorage.getItem('pasal-held')).toContain('Hari')

    expect(cart.restore(held!.id)).toBe(true)
    expect(cart.count).toBe(1)
    expect(cart.customer?.name).toBe('Hari')
    expect(cart.held).toHaveLength(0)
  })

  it('keeps the current cart when a held cart is restored over it', () => {
    cart.add(milk)
    const first = cart.hold('First')
    cart.add(rice)
    expect(cart.restore(first!.id)).toBe(true)
    expect(cart.lines.map((l) => l.item.name)).toEqual(['Milk 500ml'])
    expect(cart.held.map((h) => h.lines[0].item.name)).toEqual(['Rice 5kg'])
  })

  it('discards a held cart', () => {
    cart.add(milk)
    const held = cart.hold()
    cart.discard(held!.id)
    expect(cart.held).toHaveLength(0)
  })
})
